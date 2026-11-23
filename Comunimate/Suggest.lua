-- Word suggestion engine: prefix completion + learned words + next-word guesses.

local _, ns = ...
local S = {}
ns.Suggest = S

local LEARN_WEIGHT = 150   -- score per time you've sent a word
local BIGRAM_WEIGHT = 400  -- score per time a word followed the previous word

local function hasUpper(w) return w:find("%u") ~= nil end

function S:Add(word, score)
	local key = word:lower()
	-- "i", "i'm", "i've" -> "I", "I'm", "I've"
	if key == "i" or key:find("^i'") then word = "I" .. key:sub(2) end
	local e = self.entries[key]
	if e then
		if score > e.score then e.score = score end
		-- Prefer the capitalised spelling (LFM, Ragnaros, I'm).
		if hasUpper(word) and not hasUpper(e.word) then e.word = word end
		return e
	end
	e = { word = word, key = key, score = score }
	self.entries[key] = e
	if ns.Swipe then ns.Swipe:Invalidate() end  -- new word: swipe index rebuilds on next use
	local first = key:sub(1, 1)
	local bucket = self.buckets[first]
	if not bucket then
		bucket = {}
		self.buckets[first] = bucket
	end
	bucket[#bucket + 1] = e
	return e
end

local function addList(self, text, top, step)
	local rank = 0
	for w in text:gmatch("%S+") do
		rank = rank + 1
		self:Add(w, math.max(1, top - rank * step))
	end
end

function S:Init()
	self.entries = {}
	self.buckets = {}
	local D = ns.Dictionary
	addList(self, D.common, 3000, 4)
	addList(self, D.wowChat, 2600, 3)
	addList(self, D.wowNames, 1400, 1)
	if D.english then addList(self, D.english, 2400, 0.22) end  -- Words.lua (10,000 words)
	if ns.learned then
		for key in pairs(ns.learned.words) do
			if not self.entries[key] then self:Add(key, 0) end
		end
	end
end

-- Match the user's capitalisation for plain lowercase dictionary words.
local function applyCase(word, partial)
	if hasUpper(word) or partial == "" then return word end
	if #partial > 1 and partial == partial:upper() and partial:find("%a") then
		return word:upper()
	end
	if partial:sub(1, 1):find("%u") then
		return word:sub(1, 1):upper() .. word:sub(2)
	end
	return word
end

local function score(entry, prevKey)
	local learned = ns.learned
	local s = entry.score + (learned.words[entry.key] or 0) * LEARN_WEIGHT
	if prevKey then
		local follow = learned.bigrams[prevKey]
		if follow and follow[entry.key] then
			s = s + follow[entry.key] * BIGRAM_WEIGHT
		end
	end
	return s
end

-- partial: letters typed of the current word ("" if none)
-- prev: the word before it (may be nil)
function S:Query(partial, prev, max)
	max = max or 4
	partial = partial or ""
	local prevKey = prev and prev:lower() or nil
	local results = {}

	if partial == "" then
		-- Next-word guesses from what you've sent before.
		local follow = prevKey and ns.learned.bigrams[prevKey]
		if follow then
			local list = {}
			for key, n in pairs(follow) do list[#list + 1] = { key = key, n = n } end
			table.sort(list, function(a, b) return a.n > b.n end)
			for i = 1, math.min(max, #list) do
				local e = self.entries[list[i].key]
				results[#results + 1] = e and e.word or list[i].key
			end
		end
		if #results == 0 and not prevKey then
			for i = 1, math.min(max, #ns.Dictionary.starters) do
				results[#results + 1] = ns.Dictionary.starters[i]
			end
		end
		return results
	end

	local p = partial:lower()
	local bucket = self.buckets[p:sub(1, 1)]
	if not bucket then return results end

	local matches = {}
	for i = 1, #bucket do
		local e = bucket[i]
		if #e.key >= #p and e.key:sub(1, #p) == p then
			-- Skip a word identical to what's typed unless it fixes capitals (lfm -> LFM).
			if e.key ~= p or (hasUpper(e.word) and e.word ~= partial) then
				matches[#matches + 1] = { e = e, s = score(e, prevKey) }
			end
		end
	end
	table.sort(matches, function(a, b)
		if a.s ~= b.s then return a.s > b.s end
		return a.e.key < b.e.key
	end)
	for i = 1, math.min(max, #matches) do
		results[#results + 1] = applyCase(matches[i].e.word, partial)
	end
	return results
end

-- Remember the words in a sent message.
function S:Learn(text)
	if not (ns.db and ns.db.learn) or not text then return end
	text = text:gsub("^/%S+%s*", "")  -- drop a leading /p, /ra, ...
	local prev
	for w in text:gmatch("[%w']+") do
		local key = w:lower()
		if #key >= 2 or key == "i" then
			ns.learned.words[key] = (ns.learned.words[key] or 0) + 1
			if not self.entries[key] then self:Add(w, 0) end
			if prev then
				local follow = ns.learned.bigrams[prev]
				if not follow then
					follow = {}
					ns.learned.bigrams[prev] = follow
				end
				follow[key] = (follow[key] or 0) + 1
			end
			prev = key
		end
	end
end
