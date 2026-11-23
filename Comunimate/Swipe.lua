-- Swipe typing: guess a word from the path a ring traced over a QWERTY layout.
--
-- Positions are in "key units": one key is 1 x 1, rows are offset like a real
-- keyboard. The keyboard (Keyboard.lua) feeds the ring's path in; Decode()
-- returns the best words, most likely first.
--
-- How a word is scored:
--   1. candidates start near where you began, end near where you stopped, and
--      only use letters your path came near;
--   2. the word's letters are lined up along the path in order (elastic match);
--   3. points where the path turned sharply must belong to some letter;
--   4. the path's length should fit the word's shape;
--   5. common words, and words you use, get a boost.

local _, ns = ...
local Swipe = {}
ns.Swipe = Swipe

Swipe.ROWS = { "qwertyuiop", "asdfghjkl", "zxcvbnm" }
Swipe.OFFSETS = { 0, 0.5, 1.5 }

local POS = {}
for r, row in ipairs(Swipe.ROWS) do
	for i = 1, #row do
		POS[row:sub(i, i)] = { x = Swipe.OFFSETS[r] + i - 0.5, y = r - 0.5 }
	end
end
Swipe.POS = POS

local sqrt, abs, log, floor = math.sqrt, math.abs, math.log, math.floor

local function dist(ax, ay, bx, by)
	local dx, dy = ax - bx, ay - by
	return sqrt(dx * dx + dy * dy)
end

local function lettersNear(x, y, radius, out)
	for ch, p in pairs(POS) do
		if dist(x, y, p.x, p.y) <= radius then out[ch] = true end
	end
	return out
end

-- The letter under a point (nil if the point is between keys / off the keyboard).
function Swipe:KeyAt(x, y)
	local best, bestD = nil, 0.72
	for ch, p in pairs(POS) do
		local d = dist(x, y, p.x, p.y)
		if d < bestD then best, bestD = ch, d end
	end
	return best
end

----------------------------------------------------------------------
-- Word index: every dictionary word as plain letters, by first letter.
----------------------------------------------------------------------

function Swipe:BuildIndex()
	local index = {}
	for key, e in pairs(ns.Suggest.entries) do
		if not key:find("[^a-z']") then
			local letters = key:gsub("'", "")
			if #letters >= 1 and #letters <= 20 then
				-- "hello" -> "helo": a doubled letter is one stop on the path.
				local collapsed = letters:gsub("(%a)%1+", "%1")
				local first = collapsed:sub(1, 1)
				local list = index[first]
				if not list then
					list = {}
					index[first] = list
				end
				list[#list + 1] = { e = e, letters = collapsed, last = collapsed:sub(-1) }
			end
		end
	end
	self.index = index
end

function Swipe:Invalidate() self.index = nil end

----------------------------------------------------------------------
-- Path helpers
----------------------------------------------------------------------

local STEP = 0.2

-- Even spacing along the path (key units), keeping "dwell" marks.
local function resample(points)
	local out = { { x = points[1].x, y = points[1].y, dwell = points[1].dwell } }
	local need = STEP  -- distance still to go before the next sample
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local seg = dist(a.x, a.y, b.x, b.y)
		local pos = 0
		while seg - pos >= need do
			pos = pos + need
			local f = pos / seg
			out[#out + 1] = { x = a.x + (b.x - a.x) * f, y = a.y + (b.y - a.y) * f }
			need = STEP
		end
		need = need - (seg - pos)
		if b.dwell then out[#out].dwell = true end
	end
	local last = points[#points]
	local tail = out[#out]
	if dist(tail.x, tail.y, last.x, last.y) > 0.05 then
		out[#out + 1] = { x = last.x, y = last.y, dwell = last.dwell }
	end
	return out
end

local function pathLength(pts)
	local len = 0
	for i = 2, #pts do len = len + dist(pts[i - 1].x, pts[i - 1].y, pts[i].x, pts[i].y) end
	return len
end

-- Corners (sharp turns) and pauses: places a letter almost certainly sits.
local TURN_COS = math.cos(math.rad(50))
local function findAnchors(pts)
	local anchors = {}
	local k = 2
	for i = 1 + k, #pts - k do
		local a, p, b = pts[i - k], pts[i], pts[i + k]
		local ux, uy = p.x - a.x, p.y - a.y
		local vx, vy = b.x - p.x, b.y - p.y
		local lu, lv = sqrt(ux * ux + uy * uy), sqrt(vx * vx + vy * vy)
		local turned = lu > 0.05 and lv > 0.05 and (ux * vx + uy * vy) / (lu * lv) < TURN_COS
		if turned or p.dwell then
			-- One anchor per corner: skip if the previous anchor is right before.
			if #anchors == 0 or i - anchors[#anchors] > 3 then anchors[#anchors + 1] = i end
		end
	end
	return anchors
end

----------------------------------------------------------------------
-- Scoring one candidate
----------------------------------------------------------------------

local MAX_LETTER_DIST = 1.1   -- a letter farther than this from the path rules the word out
local NEAR = 0.5             -- "the path reached this letter"

local W_DIST, W_WORST, W_ANCHOR, W_LEN, W_FREQ = 2.2, 1.3, 1.6, 1.3, 0.5

local function matchWord(c, pts, anchors, plen)
	local L = c.letters
	local n = #L
	local np = #pts
	local matched = {}
	local total, worst = 0, 0

	-- First letter: the first point. Last letter: the last point.
	local p = POS[L:sub(1, 1)]
	local d = dist(p.x, p.y, pts[1].x, pts[1].y)
	matched[1] = 1
	total, worst = d, d

	local idx = 1
	for i = 2, n - 1 do
		p = POS[L:sub(i, i)]
		local limit = np - (n - i)
		local bestJ, bestD = nil, math.huge
		local j = idx + 1
		-- Take the first close approach (the path reaching this letter), else the closest point.
		while j <= limit do
			local dj = dist(p.x, p.y, pts[j].x, pts[j].y)
			if dj < bestD then bestJ, bestD = j, dj end
			if dj < NEAR then
				-- Follow it to the local minimum.
				while j + 1 <= limit do
					local dn = dist(p.x, p.y, pts[j + 1].x, pts[j + 1].y)
					if dn > dj then break end
					j, dj = j + 1, dn
				end
				bestJ, bestD = j, dj
				break
			end
			j = j + 1
		end
		if not bestJ or bestD > MAX_LETTER_DIST then return nil end
		matched[i] = bestJ
		idx = bestJ
		total = total + bestD
		if bestD > worst then worst = bestD end
	end

	if n > 1 then
		p = POS[L:sub(n, n)]
		d = dist(p.x, p.y, pts[np].x, pts[np].y)
		if d > MAX_LETTER_DIST then return nil end
		matched[n] = np
		total = total + d
		if d > worst then worst = d end
	end

	-- Corners the word doesn't explain.
	local missed = 0
	for _, a in ipairs(anchors) do
		local covered = false
		for i = 1, n do
			if abs(matched[i] - a) <= 3 then covered = true break end
		end
		if not covered then
			local q = pts[a]
			for i = 1, n do
				local lp = POS[L:sub(i, i)]
				if dist(q.x, q.y, lp.x, lp.y) < 0.6 then covered = true break end
			end
		end
		if not covered then missed = missed + 1 end
	end

	-- Path length vs the word's own shape.
	local ideal = 0
	for i = 2, n do
		local a, b = POS[L:sub(i - 1, i - 1)], POS[L:sub(i, i)]
		ideal = ideal + dist(a.x, a.y, b.x, b.y)
	end
	local lenPenalty
	if ideal < 0.3 then
		lenPenalty = plen * 0.8  -- one-letter words: the path should barely move
	else
		local ratio = plen / ideal
		lenPenalty = ratio < 1 and (1 - ratio) * 3 or (ratio - 1) * 0.6
	end

	-- How common / how much you use it.
	local e = c.e
	local freq = e.score + ((ns.learned and ns.learned.words[e.key]) or 0) * 150

	return -W_DIST * (total / n) - W_WORST * worst - W_ANCHOR * missed - W_LEN * lenPenalty
		+ W_FREQ * log(freq + 10)
end

----------------------------------------------------------------------
-- Decode
----------------------------------------------------------------------

-- points: { {x=, y=, dwell=true?}, ... } in key units. Returns up to `max`
-- words (as they should be typed), best first.
function Swipe:Decode(points, max)
	max = max or 4
	if not points or #points < 2 then return {} end
	if not self.index then self:BuildIndex() end

	local pts = resample(points)
	local first, last = pts[1], pts[#pts]
	local near = {}
	for _, p in ipairs(pts) do lettersNear(p.x, p.y, 0.85, near) end
	local starts = lettersNear(first.x, first.y, 1.05, {})
	local ends = lettersNear(last.x, last.y, 1.05, {})
	local anchors = findAnchors(pts)
	local plen = pathLength(pts)

	local scored = {}
	for s in pairs(starts) do
		for _, c in ipairs(self.index[s] or {}) do
			if ends[c.last] then
				local ok = true
				local L = c.letters
				for i = 2, #L - 1 do
					if not near[L:sub(i, i)] then ok = false break end
				end
				if ok then
					local sc = matchWord(c, pts, anchors, plen)
					if sc then scored[#scored + 1] = { word = c.e.word, score = sc } end
				end
			end
		end
	end
	table.sort(scored, function(a, b) return a.score > b.score end)

	local out, seen = {}, {}
	for _, s in ipairs(scored) do
		local k = s.word:lower()
		if not seen[k] then
			seen[k] = true
			out[#out + 1] = s.word
			if #out >= max then break end
		end
	end
	return out
end
