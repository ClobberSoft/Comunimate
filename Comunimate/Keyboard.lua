-- The split on-screen keyboard.
--
-- Left stick picks a key on the left half, right stick picks a key on the right
-- half. The stick works like a pointer: at rest it sits on the middle key, push
-- it toward a key to select it. L2 types the left key, R2 types the right key.
--
-- The keyboard has its own text box and sends with the chat API (Chat.lua). It
-- never touches Blizzard's chat box: driving that from an add-on "taints" it, and
-- WoW then blocks chat with the "only available to the Blizzard UI" popup.

local _, ns = ...
local KB = {}
ns.Keyboard = KB

----------------------------------------------------------------------
-- Layout
----------------------------------------------------------------------

local COLS, ROWS = 5, 3
local KEY, GAP = 44, 4
local HALF_W = COLS * KEY + (COLS - 1) * GAP
local HALF_H = ROWS * KEY + (ROWS - 1) * GAP
local PAD = 22  -- room for the gold dialog border
local MID_W = 150
local W = PAD + HALF_W + 12 + MID_W + 12 + HALF_W + PAD
local INPUT_H, SUG_H, LEGEND_H = 28, 26, 46
local GRID_TOP = PAD + INPUT_H + 6 + SUG_H + 22
local H = GRID_TOP + HALF_H + 10 + LEGEND_H + PAD
local SUGGESTIONS = 4

local LAYERS = {
	letters = {
		left  = { { "q", "w", "e", "r", "t" }, { "a", "s", "d", "f", "g" }, { "z", "x", "c", "v", "b" } },
		right = { { "y", "u", "i", "o", "p" }, { "h", "j", "k", "l", "'" }, { "n", "m", ",", ".", "?" } },
	},
	symbols = {
		left  = { { "1", "2", "3", "4", "5" }, { "!", "@", "#", "$", "%" }, { "-", "+", "=", "(", ")" } },
		right = { { "6", "7", "8", "9", "0" }, { "/", ":", ";", "\"", "&" }, { "*", "_", "<", ">", "~" } },
	},
}

-- WoW look: dark stone keys with tooltip-style gold edges; the selected key on
-- each half lights up in that half's color.
local COLOR_KEY      = { 0.07, 0.06, 0.05, 0.95 }
local COLOR_KEY_EDGE = { 0.55, 0.45, 0.25, 1 }
local COLOR_LEFT     = { 0.20, 0.55, 1.00, 1 }
local COLOR_RIGHT    = { 1.00, 0.55, 0.15, 1 }
local COLOR_FLASH    = { 1, 1, 1, 1 }
local KEY_BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- mode: "rest" | "left" | "right" | "flash"
local function paintKey(k, mode)
	if mode == "rest" then
		k:SetBackdropColor(unpack(COLOR_KEY))
		k:SetBackdropBorderColor(unpack(COLOR_KEY_EDGE))
		k.text:SetTextColor(1, 0.82, 0)
	elseif mode == "flash" then
		k:SetBackdropColor(unpack(COLOR_FLASH))
		k:SetBackdropBorderColor(unpack(COLOR_FLASH))
		k.text:SetTextColor(0, 0, 0)
	else
		local c = mode == "left" and COLOR_LEFT or COLOR_RIGHT
		k:SetBackdropColor(c[1] * 0.45, c[2] * 0.45, c[3] * 0.45, 1)
		k:SetBackdropBorderColor(c[1], c[2], c[3], 1)
		k.text:SetTextColor(1, 1, 1)
	end
end

KB.state = {
	layer = "letters",
	shift = false,
	caps = false,
	sel = { left = { 2, 3 }, right = { 2, 3 } },
	suggestions = {},
	sugIndex = 1,
}
KB.sticks = { lx = 0, ly = 0, rx = 0, ry = 0 }

----------------------------------------------------------------------
-- Building the frame
----------------------------------------------------------------------

local function makeKey(parent, x, y)
	local k = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	k:SetSize(KEY, KEY)
	k:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	k:SetBackdrop(KEY_BACKDROP)
	k.text = k:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	k.text:SetPoint("CENTER", 0, 1)
	paintKey(k, "rest")
	return k
end

local function makeHalf(f, anchorPoint, x)
	local half = CreateFrame("Frame", nil, f)
	half:SetSize(HALF_W, HALF_H)
	half:SetPoint(anchorPoint, f, anchorPoint, x, -GRID_TOP)
	half.keys = {}
	for r = 1, ROWS do
		half.keys[r] = {}
		for c = 1, COLS do
			half.keys[r][c] = makeKey(half, (c - 1) * (KEY + GAP), (r - 1) * (KEY + GAP))
		end
	end
	local title = half:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("BOTTOM", half, "TOP", 0, 3)
	half.title = title

	-- The see-through ring you steer with the stick, drawn above the keys.
	local ring = CreateFrame("Frame", nil, half)
	ring:SetFrameLevel(half:GetFrameLevel() + 10)
	ring:SetSize(KEY * 1.05, KEY * 1.05)
	ring.tex = ring:CreateTexture(nil, "OVERLAY")
	ring.tex:SetAllPoints()
	ring.tex:SetTexture("Interface\\AddOns\\Comunimate\\Media\\ring")
	half.ring = ring
	return half
end

function KB:Build()
	if self.frame then return end
	local f = CreateFrame("Frame", "ComunimateKeyboard", UIParent, "BackdropTemplate")
	self.frame = f
	f:SetSize(W, H)
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing()
		local point, _, relPoint, x, y = frame:GetPoint()
		ns.db.position = { point, relPoint, x, y }
	end)
	f:Hide()

	-- WoW dialog look: dark ground inside the game's gold dialog border (the
	-- same frame as the game's pop-ups). Falls back to the classic dialog edge.
	local ground = f:CreateTexture(nil, "BACKGROUND")
	ground:SetPoint("TOPLEFT", 8, -8)
	ground:SetPoint("BOTTOMRIGHT", -8, 8)
	self.ground = ground
	local ok = pcall(function()
		local border = CreateFrame("Frame", nil, f, "DialogBorderTemplate")
		border:SetAllPoints()
		if border.Bg then border.Bg:Hide() end
	end)
	if not ok then
		f:SetBackdrop({
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
	end

	-- Settings button and channel label (top right).
	local gear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	gear:SetSize(76, 24)
	gear:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -PAD - 2)
	gear:SetText("Settings")
	gear:SetScript("OnClick", function() ns.Options:Toggle() end)

	local channel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	channel:SetPoint("RIGHT", gear, "LEFT", -10, 0)
	self.channelText = channel

	-- Our own text box. Voice typing and a physical keyboard type here too.
	local input = CreateFrame("EditBox", "ComunimateInput", f, "BackdropTemplate")
	input:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -PAD)
	input:SetPoint("RIGHT", channel, "LEFT", -10, 0)
	input:SetHeight(INPUT_H)
	input:SetAutoFocus(false)
	input:SetMaxLetters(255)
	input:SetFontObject(ChatFontNormal)
	input:SetTextInsets(10, 10, 0, 0)
	input:SetBackdrop(KEY_BACKDROP)
	input:SetBackdropColor(0, 0, 0, 0.7)
	input:SetBackdropBorderColor(unpack(COLOR_KEY_EDGE))
	input:SetScript("OnEnterPressed", function() KB:SendMessage() end)
	input:SetScript("OnEscapePressed", function() KB:Close() end)
	input:SetScript("OnTextChanged", function() KB:OnTextChanged() end)
	input:SetScript("OnCursorChanged", function() KB:OnTextChanged() end)
	self.input = input

	-- Suggestion bar.
	self.sugSlots = {}
	local sugW = (W - 2 * PAD - (SUGGESTIONS - 1) * GAP) / SUGGESTIONS
	for i = 1, SUGGESTIONS do
		-- The game's red buttons; the picked word stays lit.
		local s = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		s:SetSize(sugW, SUG_H)
		s:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + (i - 1) * (sugW + GAP), -(PAD + INPUT_H + 6))
		s:SetScript("OnClick", function()
			KB.state.sugIndex = i
			KB:AcceptSuggestion()
			KB.input:SetFocus()
		end)
		self.sugSlots[i] = s
	end

	-- The two halves.
	self.halves = {
		left = makeHalf(f, "TOPLEFT", PAD),
		right = makeHalf(f, "TOPRIGHT", -PAD),
	}
	self.halves.left.ring.tex:SetVertexColor(COLOR_LEFT[1], COLOR_LEFT[2], COLOR_LEFT[3], 0.95)
	self.halves.right.ring.tex:SetVertexColor(COLOR_RIGHT[1], COLOR_RIGHT[2], COLOR_RIGHT[3], 0.95)
	self:BuildSwipePanel()

	-- Middle panel: big view of both selected keys, mode and voice status.
	local mid = CreateFrame("Frame", nil, f)
	mid:SetSize(MID_W, HALF_H)
	mid:SetPoint("TOP", f, "TOP", 0, -GRID_TOP)
	self.mid = mid

	local selL = mid:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	selL:SetPoint("TOPLEFT", mid, "TOPLEFT", 8, -6)
	selL:SetTextColor(COLOR_LEFT[1], COLOR_LEFT[2], COLOR_LEFT[3])
	self.selLeftText = selL

	local selR = mid:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	selR:SetPoint("TOPRIGHT", mid, "TOPRIGHT", -8, -6)
	selR:SetTextColor(COLOR_RIGHT[1], COLOR_RIGHT[2], COLOR_RIGHT[3])
	self.selRightText = selR

	local mode = mid:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	mode:SetPoint("TOP", mid, "TOP", 0, -46)
	self.modeText = mode

	local status = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	status:SetPoint("TOP", mode, "BOTTOM", 0, -8)
	status:SetWidth(MID_W)
	status:SetWordWrap(true)
	self.statusText = status

	local dbg = mid:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	dbg:SetPoint("BOTTOM", mid, "BOTTOM", 0, 2)
	self.debugText = dbg

	-- Button legend.
	local leg1 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	leg1:SetPoint("BOTTOM", f, "BOTTOM", 0, PAD + 24)
	local leg2 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	leg2:SetPoint("BOTTOM", f, "BOTTOM", 0, PAD)
	self.legend = { leg1, leg2 }

	-- Voice-only box ("compact"): mascot, title, the text, and a short hint.
	local mascot = f:CreateTexture(nil, "ARTWORK")
	mascot:SetSize(40, 40)
	mascot:SetPoint("TOPLEFT", f, "TOPLEFT", PAD - 2, -PAD + 4)
	self.compactMascot = mascot
	local ctitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	ctitle:SetPoint("LEFT", mascot, "RIGHT", 10, 0)
	ctitle:SetPoint("RIGHT", channel, "LEFT", -10, 0)
	ctitle:SetJustifyH("LEFT")
	ctitle:SetWordWrap(false)
	self.compactTitle = ctitle
	local chint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	chint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD + 4)
	chint:SetJustifyH("LEFT")
	self.compactHint = chint

	-- Commit or throw away what you said (the controller buttons do the same).
	local csend = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	csend:SetSize(150, 26)
	csend:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD - 2)
	csend:SetScript("OnClick", function() KB:SendMessage() end)
	local ccancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	ccancel:SetSize(120, 26)
	ccancel:SetPoint("RIGHT", csend, "LEFT", -8, 0)
	ccancel:SetScript("OnClick", function() KB:Close() end)
	self.compactSend, self.compactCancel = csend, ccancel
	self.compactParts = { mascot, ctitle, chint, csend, ccancel }

	-- Controller input. While the keyboard is open it takes the sticks and
	-- buttons, so L2/R2 type letters instead of switching action bars.
	pcall(f.EnableGamePadButton, f, true)
	pcall(f.EnableGamePadStick, f, true)
	if not InCombatLockdown() then
		pcall(f.SetPropagateKeyboardInput, f, false)
	end
	f:SetScript("OnGamePadButtonDown", function(_, button) KB:OnButton(button, true) end)
	f:SetScript("OnGamePadButtonUp", function(_, button) KB:OnButton(button, false) end)
	f:SetScript("OnGamePadStick", function(_, stick, x, y) KB:OnStickEvent(stick, x, y) end)
	f:SetScript("OnUpdate", function(_, elapsed) KB:OnUpdate(elapsed) end)
	f:SetScript("OnHide", function() KB:OnHidden() end)

	-- Secure send button. Pressing Send (out of combat) "clicks" this through a
	-- temporary binding, so WoW runs "/s message" as if you typed it yourself.
	-- That's the only way an add-on may send Say/Yell outdoors or during lockdown.
	local send = CreateFrame("Button", "ComunimateSendButton", UIParent, "SecureActionButtonTemplate")
	send:SetAttribute("type", "macro")
	-- Down and up: binding clicks arrive on one or the other depending on the
	-- player's "cast on key down" setting. The macro is cleared after the first.
	send:RegisterForClicks("AnyDown", "AnyUp")
	send:SetScript("PostClick", function() KB:OnSecureSent() end)
	self.sendButton = send
	self.sendOwner = CreateFrame("Frame")

	-- Everything the voice-only box hides.
	self.fullParts = { self.halves.left, self.halves.right, mid, leg1, leg2 }
	for _, s in ipairs(self.sugSlots) do self.fullParts[#self.fullParts + 1] = s end
	self:SetCompact(false)

	self:ApplyLayout()
	self:BuildComboWatcher()
	self:SetupVoiceKeys()
end

local COMPACT_H = PAD + 44 + INPUT_H + 14 + 30 + PAD

-- Switch between the full keyboard and the small voice-only box.
function KB:SetCompact(on)
	self.compact = on and true or false
	local f = self.frame
	for _, p in ipairs(self.fullParts) do p:SetShown(not self.compact) end
	for _, p in ipairs(self.compactParts) do p:SetShown(self.compact) end
	self.input:ClearAllPoints()
	if self.compact then
		f:SetSize(W, COMPACT_H)
		self.input:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(PAD + 44))
		self.input:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
	else
		f:SetSize(W, H)
		self.input:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -PAD)
		self.input:SetPoint("RIGHT", self.channelText, "LEFT", -10, 0)
	end
	self:UpdateLayoutMode()
	self:RefreshStatus()
	self:RefreshLegend()
end

function KB:ApplyLayout()
	local f = self.frame
	if not f then return end
	f:SetScale(ns.db.scale or 1)
	self.ground:SetColorTexture(0.03, 0.025, 0.02, ns.db.kbAlpha or 0.95)
	f:ClearAllPoints()
	local p = ns.db.position
	if p then
		f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	else
		f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 180)
	end
end

----------------------------------------------------------------------
-- Show / hide
----------------------------------------------------------------------

function KB:IsShown()
	return self.frame and self.frame:IsShown() or false
end

-- compact: show the small voice-only box instead of the full keyboard.
function KB:Show(compact)
	if not self.frame then self:Build() end
	self:SetCompact(compact)
	self.state.layer = "letters"
	self.state.shift = false
	-- While open, the keyboard gets the button releases, so forget what the
	-- combo watcher thought was held.
	if self.watcher then wipe(self.watcher.held) end
	self.held = {}
	self:CenterCursors()
	self.frame:Show()
	self.input:SetFocus()
	self:OnTextChanged()
	self:RefreshAll()
end

-- Hide but keep what was typed (e.g. after a blocked send).
function KB:Hide()
	if self.frame and self.frame:IsShown() then self.frame:Hide() end
end

-- Hide and throw away the text.
function KB:Close()
	if self.input then self.input:SetText("") end
	self:Hide()
end

function KB:Toggle()
	if self:IsShown() then self:Close() else self:Show() end
end

function KB:OnHidden()
	self:EndSecureSend()
	self.input:ClearFocus()
	self.repeatAction = nil
	self.repeatButton = nil
	self.voiceState, self.voiceTimer, self.awaitApp = nil, nil, nil
	self.status = nil
	self.trace, self.lastSwipe = nil, nil
	if self.swipePanel then self:ClearTrail() end
end

----------------------------------------------------------------------
-- Sticks
----------------------------------------------------------------------

local LEFT_STICKS = { Left = true, Move = true, Movement = true }
local RIGHT_STICKS = { Right = true, Look = true, Camera = true }

function KB:OnStickEvent(stick, x, y)
	if LEFT_STICKS[stick] then
		self.sticks.lx, self.sticks.ly = x or 0, y or 0
	elseif RIGHT_STICKS[stick] then
		self.sticks.rx, self.sticks.ry = x or 0, y or 0
	end
end

-- Prefer reading the controller directly; fall back to stick events.
function KB:ReadSticks()
	if C_GamePad and C_GamePad.GetDeviceMappedState then
		local ok, state = pcall(C_GamePad.GetDeviceMappedState)
		if ok and state and state.sticks and state.sticks[1] then
			local l, r = state.sticks[1], state.sticks[2]
			return l.x or 0, l.y or 0, r and r.x or 0, r and r.y or 0, "mapped"
		end
	end
	local s = self.sticks
	return s.lx, s.ly, s.rx, s.ry, "events"
end

local function stickToCell(x, y)
	local db = ns.db
	if db.invertY then y = -y end
	local col
	if x < -db.colOuter then col = 1
	elseif x < -db.colInner then col = 2
	elseif x <= db.colInner then col = 3
	elseif x <= db.colOuter then col = 4
	else col = 5 end
	local row
	if y > db.rowThreshold then row = 1
	elseif y < -db.rowThreshold then row = 3
	else row = 2 end
	return row, col
end

----------------------------------------------------------------------
-- Update loop
----------------------------------------------------------------------

local REPEAT_DELAY, REPEAT_RATE = 0.45, 0.06
local STICK_DEADZONE = 0.15
local CELL = KEY + GAP

-- Ring cursor position per half, in pixels from the half's top-left corner.
KB.cursor = { left = { x = 0, y = 0 }, right = { x = 0, y = 0 } }

local function cellAt(x, y)
	local col = math.min(COLS, math.max(1, math.floor(x / CELL) + 1))
	local row = math.min(ROWS, math.max(1, math.floor(y / CELL) + 1))
	return row, col
end

local function cellCenter(row, col)
	return (col - 1) * CELL + KEY / 2, (row - 1) * CELL + KEY / 2
end

function KB:PlaceRing(side)
	local half = self.halves and self.halves[side]
	if not half then return end
	local c = self.cursor[side]
	half.ring:ClearAllPoints()
	half.ring:SetPoint("CENTER", half, "TOPLEFT", c.x, -c.y)
end

-- Rings back on the middle keys.
function KB:CenterCursors()
	for _, side in ipairs({ "left", "right" }) do
		local c = self.cursor[side]
		c.x, c.y = cellCenter(2, 3)
		self.state.sel[side][1], self.state.sel[side][2] = 2, 3
		self:PlaceRing(side)
	end
end

local SPRING_DELAY = 0.15  -- rest this long before the ring heads home (time to press L2/R2)
local SPRING_RATE = 16    -- how quickly it glides back

-- Ring modes: the stick steers the ring; farther push = faster.
-- "spring": once you let go of the stick, the ring glides back to the middle key.
-- "free":   the ring stays where you left it.
function KB:SteerRing(side, x, y, elapsed)
	if ns.db.invertY then y = -y end
	local c = self.cursor[side]
	local mag = math.sqrt(x * x + y * y)
	if mag <= STICK_DEADZONE then
		if ns.db.cursorMode ~= "spring" then return end
		c.rest = (c.rest or 0) + elapsed
		if c.rest < SPRING_DELAY then return end
		local hx, hy = cellCenter(2, 3)
		local t = math.min(1, elapsed * SPRING_RATE)
		c.x, c.y = c.x + (hx - c.x) * t, c.y + (hy - c.y) * t
		if math.abs(hx - c.x) < 0.5 and math.abs(hy - c.y) < 0.5 then c.x, c.y = hx, hy end
		self:PlaceRing(side)
		return
	end
	c.rest = 0
	local push = math.min(1, (mag - STICK_DEADZONE) / (1 - STICK_DEADZONE))
	local speed = (ns.db.cursorSpeed or 520) * push ^ 1.6
	c.x = math.min(HALF_W - 1, math.max(1, c.x + x / mag * speed * elapsed))
	c.y = math.min(HALF_H - 1, math.max(1, c.y - y / mag * speed * elapsed))
	self:PlaceRing(side)
end

function KB:OnUpdate(elapsed)
	local lx, ly, rx, ry, source = self:ReadSticks()
	local sel = self.state.sel
	local lr, lc, rr, rc
	if ns.db.cursorMode == "swipe" and not self.compact then
		-- Swipe style: one ring over the whole keyboard (see the swipe section).
		self:UpdateSwipe(lx, ly, rx, ry, elapsed)
		lr, lc, rr, rc = sel.left[1], sel.left[2], sel.right[1], sel.right[2]
	elseif ns.db.cursorMode == "snap" then
		-- Snap mode: the stick points at a key directly; the ring jumps there.
		lr, lc = stickToCell(lx, ly)
		rr, rc = stickToCell(rx, ry)
		for side, cell in pairs({ left = { lr, lc }, right = { rr, rc } }) do
			local c = self.cursor[side]
			c.x, c.y = cellCenter(cell[1], cell[2])
			self:PlaceRing(side)
		end
	else
		self:SteerRing("left", lx, ly, elapsed)
		self:SteerRing("right", rx, ry, elapsed)
		lr, lc = cellAt(self.cursor.left.x, self.cursor.left.y)
		rr, rc = cellAt(self.cursor.right.x, self.cursor.right.y)
	end
	if lr ~= sel.left[1] or lc ~= sel.left[2] or rr ~= sel.right[1] or rc ~= sel.right[2] then
		sel.left[1], sel.left[2] = lr, lc
		sel.right[1], sel.right[2] = rr, rc
		self:RefreshSelection()
	end

	if ns.db.debug then
		self.debugText:SetFormattedText("%s  L %.2f %.2f  R %.2f %.2f", source, lx, ly, rx, ry)
	end

	-- Voice / status timeouts.
	if self.voiceTimer then
		self.voiceTimer = self.voiceTimer - elapsed
		if self.voiceTimer <= 0 then self:SetVoiceState(nil) end
	end
	if self.awaitApp then
		self.awaitApp = self.awaitApp - elapsed
		if self.awaitApp <= 0 then
			self.awaitApp = nil
			self:SetVoiceState("noapp")
		end
	end
	if self.statusTimer then
		self.statusTimer = self.statusTimer - elapsed
		if self.statusTimer <= 0 then
			self.statusTimer, self.status = nil, nil
			self:RefreshStatus()
		end
	end

	-- Secure send didn't happen (binding didn't fire): send the normal way.
	if self.pendingSend then
		self.pendingSend.timer = self.pendingSend.timer - elapsed
		if self.pendingSend.timer <= 0 then
			local text = self.pendingSend.text
			self:EndSecureSend()
			if ns.db.debug then ns:Print("secure send didn't fire, using chat API") end
			self:FinishSend(text, ns.Chat:Send(text, ns.Chat:ChannelAt(ns.db.channel)))
		end
	end

	-- Hold-to-repeat (backspace).
	if self.repeatAction then
		self.repeatTimer = self.repeatTimer - elapsed
		if self.repeatTimer <= 0 then
			self.repeatTimer = REPEAT_RATE
			self.actions[self.repeatAction](self)
		end
	end
end

----------------------------------------------------------------------
-- Text editing
----------------------------------------------------------------------

local function splitAtCursor(eb)
	local text = eb:GetText() or ""
	local pos = eb:GetCursorPosition() or #text
	return text:sub(1, pos), text:sub(pos + 1)
end

function KB:Insert(s)
	self.input:Insert(s)
end

function KB:Backspace()
	local eb = self.input
	local before, after = splitAtCursor(eb)
	if before == "" then return end
	-- Step back over one whole UTF-8 character.
	local i = #before
	while i > 1 do
		local b = before:byte(i)
		if b < 0x80 or b >= 0xC0 then break end
		i = i - 1
	end
	before = before:sub(1, i - 1)
	eb:SetText(before .. after)
	eb:SetCursorPosition(#before)
end

function KB:OnTextChanged()
	if not self.input then return end
	local before = splitAtCursor(self.input)
	local text = self.input:GetText() or ""
	if text ~= self.lastText then
		self.lastText = text
		-- Voice text arrived.
		if self.voiceState == "thinking" then self:SetVoiceState(nil) end
	end

	-- Right after a swiped word, the bar keeps that swipe's other guesses.
	local ls = self.lastSwipe
	if ls then
		if before:sub(-#ls.inserted) == ls.inserted then
			self.state.suggestions, self.state.sugIndex = ls.words, ls.index
			if self:IsShown() then self:RefreshSuggestions() end
			return
		end
		self.lastSwipe = nil
	end

	local partial = before:match("[%w']+$") or ""
	local rest = before:sub(1, #before - #partial)
	local prev = rest:match("([%w']+)[^%w']*$")
	self.state.suggestions = ns.Suggest:Query(partial, prev, SUGGESTIONS)
	self.state.sugIndex = 1
	if self:IsShown() then self:RefreshSuggestions() end
	if self.compact then self:RefreshStatus() end
end

function KB:AcceptSuggestion()
	local word = self.state.suggestions[self.state.sugIndex]
	if not word then return end
	local eb = self.input
	local before, after = splitAtCursor(eb)
	local partial = before:match("[%w']+$") or ""
	before = before:sub(1, #before - #partial) .. word
	if after:sub(1, 1) ~= " " then before = before .. " " end
	eb:SetText(before .. after)
	eb:SetCursorPosition(#before)
end

----------------------------------------------------------------------
-- Status line (middle panel)
----------------------------------------------------------------------

function KB:SetStatus(text, seconds)
	self.status = text
	self.statusTimer = seconds
	self:RefreshStatus()
end

----------------------------------------------------------------------
-- Actions
----------------------------------------------------------------------

function KB:TypeSide(side)
	local st = self.state
	local r, c = st.sel[side][1], st.sel[side][2]
	local ch = LAYERS[st.layer][side][r][c]
	if st.layer == "letters" and (st.shift or st.caps) then ch = ch:upper() end
	self:Insert(ch)
	self:Flash(side, r, c)
	if st.shift then
		st.shift = false
		self:RefreshKeys()
	end
end

-- Send with the chat API (physical Enter key, or in combat).
function KB:SendMessage()
	local text = self.input:GetText() or ""
	if not text:find("%S") then
		self:Close()
		return
	end
	self:FinishSend(text, ns.Chat:Send(text, ns.Chat:ChannelAt(ns.db.channel)))
end

function KB:FinishSend(text, ok, err)
	if not ok then
		self:SetStatus("|cffff7f40" .. tostring(err) .. "|r", 8)
		return
	end
	ns.Suggest:Learn(text)
	self.input:AddHistoryLine(text)
	self.input:SetText("")
	if ns.db.closeAfterSend then self:Hide() end
end

-- Controller Send: arm the secure button and let this press reach it.
-- Returns true if the press should be passed on to the binding.
function KB:BeginSecureSend(button)
	if InCombatLockdown() or not self.frame.SetPropagateKeyboardInput then return false end
	local text = self.input:GetText() or ""
	if not text:find("%S") then
		self:Close()
		return false
	end
	local macro, err = ns.Chat:MacroFor(text, ns.Chat:ChannelAt(ns.db.channel))
	if not macro then
		self:SetStatus("|cffff7f40" .. err .. "|r", 8)
		return false
	end
	self.sendButton:SetAttribute("macrotext", macro)
	SetOverrideBindingClick(self.sendOwner, true, button, "ComunimateSendButton")
	self.pendingSend = { text = text, timer = 0.5 }
	self.input:ClearFocus()  -- a focused text box can swallow the binding
	self.frame:SetPropagateKeyboardInput(true)
	return true
end

function KB:OnSecureSent()
	local pending = self.pendingSend
	if not pending then return end
	if not InCombatLockdown() then self.sendButton:SetAttribute("macrotext", nil) end
	self:EndSecureSend()
	if ns.db.debug then ns:Print("sent with secure button") end
	self:FinishSend(pending.text, true)
end

function KB:EndSecureSend()
	self.pendingSend = nil
	if InCombatLockdown() then return end
	if self.sendOwner then ClearOverrideBindings(self.sendOwner) end
	if self.frame then self.frame:SetPropagateKeyboardInput(false) end
end

KB.actions = {
	TYPE_LEFT = function(self) self:TypeSide("left") end,
	TYPE_RIGHT = function(self) self:TypeSide("right") end,
	SPACE = function(self) self:Insert(" ") end,
	BACKSPACE = function(self) self:Backspace() end,
	ACCEPT = function(self)
		if self:SwipeAltActive() then
			-- Keep the swiped word; the bar goes back to next-word guesses.
			self.lastSwipe = nil
			self:OnTextChanged()
			return
		end
		self:AcceptSuggestion()
	end,
	NEXT_SUGGESTION = function(self)
		if self:SwipeAltActive() then self:CycleSwipeAlt(1) return end
		local n = #self.state.suggestions
		if n > 0 then self.state.sugIndex = self.state.sugIndex % n + 1 end
		self:RefreshSuggestions()
	end,
	PREV_SUGGESTION = function(self)
		if self:SwipeAltActive() then self:CycleSwipeAlt(-1) return end
		local n = #self.state.suggestions
		if n > 0 then self.state.sugIndex = (self.state.sugIndex - 2) % n + 1 end
		self:RefreshSuggestions()
	end,
	SHIFT = function(self)
		local st = self.state
		if st.caps then st.caps = false st.shift = false
		else st.shift = not st.shift end
		self:RefreshKeys()
	end,
	CAPSLOCK = function(self)
		self.state.caps = not self.state.caps
		self.state.shift = false
		self:RefreshKeys()
	end,
	SYMBOLS = function(self)
		self.state.layer = (self.state.layer == "letters") and "symbols" or "letters"
		self:RefreshKeys()
	end,
	CHANNEL = function(self)
		ns.db.channel = ns.db.channel % ns.Chat:NumChannels() + 1
		self:RefreshChannel()
	end,
	CLEAR = function(self) self.input:SetText("") end,
	SEND = function(self) self:SendMessage() end,
	CLOSE = function(self) self:Close() end,
}

local REPEATING = { BACKSPACE = true }
local COMPACT_IGNORED = {
	TYPE_LEFT = true, TYPE_RIGHT = true, SHIFT = true, CAPSLOCK = true, SYMBOLS = true,
	PREV_SUGGESTION = true, NEXT_SUGGESTION = true,
}

----------------------------------------------------------------------
-- Voice (PS5 mic button). The Comunimate helper app listens and types into
-- our text box; the add-on opens the keyboard and shows what's happening.
--   hold the mic  = talk
--   tap the mic   = open / close the keyboard
----------------------------------------------------------------------

local THINKING_TIMEOUT = 8
local NOAPP_TIMEOUT = 6
local APP_WAIT = 0.75  -- how long to wait for the helper's signal after the mic press
local TAP_TIME = 0.35  -- shorter than this counts as a tap

function KB:SetVoiceState(state)
	self.voiceState = state
	if state == "thinking" then
		self.voiceTimer = THINKING_TIMEOUT
	elseif state == "noapp" then
		self.voiceTimer = NOAPP_TIMEOUT
	else
		self.voiceTimer = nil
	end
	self:RefreshStatus()
	if ns.Badge then ns.Badge:SetState(state) end
end

-- source: "pad" = WoW saw the mic button (only while the keyboard is open),
--         "app" = signal key from the helper.
function KB:OnVoiceButton(down, source)
	if source == "app" then self.awaitApp = nil end
	if down then
		if self.voiceState == "listening" then return end  -- both sources report the same press
		self.wasOpen = self:IsShown()
		self.pressedAt = GetTime()
		if not self.wasOpen then self:Show(not ns.db.voiceShowsKeyboard) end
		-- If only the game saw the press, check the helper answers too.
		if source == "pad" then self.awaitApp = APP_WAIT end
		self:SetVoiceState("listening")
	elseif self.voiceState == "listening" then
		if GetTime() - (self.pressedAt or 0) < TAP_TIME then
			self.awaitApp = nil
			self:SetVoiceState(nil)
			if self.wasOpen then self:Close() end
		else
			self:SetVoiceState("thinking")
		end
	end
end

-- WoW doesn't pass the PS5 mic button to add-ons while the keyboard is closed,
-- so the helper presses a hidden key combo when you press and release it
-- (CTRL-SHIFT-F10 / F11). These are temporary bindings, never saved. While the
-- keyboard is open its text box gets the keys instead (see OnKeyDown below).
function KB:SetupVoiceKeys()
	local owner = self.voiceKeyOwner
	if not owner then
		owner = CreateFrame("Frame")
		owner:SetScript("OnEvent", function(frame, event)
			if event == "PLAYER_REGEN_ENABLED" then
				frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
				KB:SetupVoiceKeys()
			elseif event == "UPDATE_BINDINGS" and not KB.settingUpKeys then
				-- Player's bindings loaded or changed: follow the open-chat combo.
				C_Timer.After(0, function() KB:SetupVoiceKeys() end)
			end
		end)
		owner:RegisterEvent("UPDATE_BINDINGS")
		self.voiceKeyOwner = owner
		-- Signal keys arriving while our text box has focus.
		self.input:HookScript("OnKeyDown", function(_, key) KB:OnInputKey(key) end)
	end
	if InCombatLockdown() then
		owner:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	-- Our own override changes fire UPDATE_BINDINGS too; ignore those.
	self.settingUpKeys = true
	C_Timer.After(0.5, function() KB.settingUpKeys = false end)
	ClearOverrideBindings(owner)
	if ns.db.voiceOpensKeyboard then
		SetOverrideBinding(owner, true, ns.db.voiceStartKey, "COMUNIMATE_VOICE_START")
		SetOverrideBinding(owner, true, ns.db.voiceStopKey, "COMUNIMATE_VOICE_STOP")
	end
	-- Claim the talk button so the game's own use of it (bags, in Forever's
	-- default controls) never fires when you press it to talk.
	if ns.db.talkButton then
		SetOverrideBinding(owner, true, ns.db.talkButton, "COMUNIMATE_TALK")
	end
	-- The controller's "open chat" combo (Forever: L1+R1+D-Down) opens our
	-- keyboard instead of Blizzard's chat box. Keyboard Enter is left alone.
	self.chatComboKeys = {}
	if ns.db.takeOverChatCombo then
		for _, key in ipairs({ GetBindingKey("OPENCHAT") }) do
			if key:find("PAD") then
				SetOverrideBinding(owner, true, key, "COMUNIMATE_TOGGLE")
				self.chatComboKeys[#self.chatComboKeys + 1] = key
			end
		end
	end
	if ns.db.debug then
		ns:Print("controller chat combo binding: " .. (#self.chatComboKeys > 0 and table.concat(self.chatComboKeys, ", ") or "none (the watcher handles it)"))
	end
	self:UpdateComboWatcher()
end

-- Catches the controller's chat combo (L1 + R1 + D-Down) while the keyboard is
-- closed: opens our keyboard and stops the press from also opening the game's
-- chat box. Every other button passes straight through to the game. It only
-- listens once WoW confirms presses pass through, and it's switched back to
-- "pass everything" as combat starts, so it can never swallow your buttons.
function KB:BuildComboWatcher()
	if self.watcher then return end
	local w = CreateFrame("Frame", "ComunimateComboWatcher", UIParent)
	self.watcher = w
	w:SetSize(1, 1)
	w:SetPoint("TOPLEFT")
	w.held = {}
	w:SetScript("OnGamePadButtonDown", function(frame, button)
		frame.held[button] = true
		if button == "PADDDOWN" and frame.held.PADLSHOULDER and frame.held.PADRSHOULDER
			and ns.db.takeOverChatCombo and not KB:IsShown() and not InCombatLockdown() then
			frame:SetPropagateKeyboardInput(false)  -- keep the game's chat box closed
			if ns.db.debug then ns:Print("chat combo caught: opening keyboard") end
			KB:Show()
			C_Timer.After(0, function()
				if not InCombatLockdown() then frame:SetPropagateKeyboardInput(true) end
			end)
		end
	end)
	w:SetScript("OnGamePadButtonUp", function(frame, button) frame.held[button] = nil end)
	w:SetScript("OnEvent", function(frame, event)
		if event == "PLAYER_REGEN_DISABLED" then
			frame:SetPropagateKeyboardInput(true)  -- last chance before combat lockdown
		else
			KB:UpdateComboWatcher()
		end
	end)
	w:RegisterEvent("PLAYER_REGEN_DISABLED")
	w:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:UpdateComboWatcher()
end

function KB:UpdateComboWatcher()
	local w = self.watcher
	if not w or InCombatLockdown() or not w.EnableGamePadButton then return end
	w:SetPropagateKeyboardInput(true)
	local passes = w.GetPropagateKeyboardInput and w:GetPropagateKeyboardInput()
	w:EnableGamePadButton((passes and ns.db.takeOverChatCombo) and true or false)
end

local function isDown(fn) return fn() and true or false end
local function matchesKey(spec, key)
	local mods, k = (spec or ""):match("^(.-)%-?([^%-]+)$")
	if not k or k ~= key then return false end
	return (mods:find("CTRL") ~= nil) == isDown(IsControlKeyDown)
		and (mods:find("SHIFT") ~= nil) == isDown(IsShiftKeyDown)
		and (mods:find("ALT") ~= nil) == isDown(IsAltKeyDown)
end

function KB:OnInputKey(key)
	if matchesKey(ns.db.voiceStartKey, key) then
		if ns.db.debug then ns:Print("voice start key received") end
		self:OnVoiceButton(true, "app")
	elseif matchesKey(ns.db.voiceStopKey, key) then
		if ns.db.debug then ns:Print("voice stop key received") end
		self:OnVoiceButton(false, "app")
	end
end

function KB:OnButton(button, down)
	-- Remember held shoulders so L1 + R1 + D-Down can switch the small box to the keyboard.
	self.held = self.held or {}
	self.held[button] = down or nil
	if down and button == "PADDDOWN" and self.compact and self.held.PADLSHOULDER and self.held.PADRSHOULDER then
		self:SetCompact(false)
		self:RefreshAll()
		return
	end
	if ns.GetAction(button) == "VOICE" then
		if ns.db.debug and down then ns:Print("button " .. button .. " -> VOICE") end
		self:OnVoiceButton(down, "pad")
		return
	end
	if not down then
		if self.trace and self.trace.button == button then self:FinishTrace() end
		if self.repeatButton == button then
			self.repeatAction, self.repeatButton = nil, nil
		end
		return
	end
	if ns.db.debug then ns:Print("button " .. button .. " -> " .. tostring(ns.GetAction(button))) end
	local action = ns.GetAction(button)
	if self.pendingSend then return end  -- a send is in flight; ignore other presses for a moment
	if self.compact then
		-- Voice-only box: "use word" opens the full keyboard; typing keys do nothing.
		if action == "ACCEPT" then
			self:SetCompact(false)
			self:RefreshAll()
			return
		end
		if COMPACT_IGNORED[action] then return end
	end
	-- Swipe style: hold L2 or R2 to trace a word (a quick press types one key).
	if ns.db.cursorMode == "swipe" and not self.compact and (action == "TYPE_LEFT" or action == "TYPE_RIGHT") then
		if not self.trace then self:StartTrace(button) end
		return
	end
	if action == "SEND" then
		if self:BeginSecureSend(button) then return end
		if not self:IsShown() then return end  -- empty text closed the keyboard
	end
	local fn = action and self.actions[action]
	if not fn then return end
	fn(self)
	if REPEATING[action] then
		self.repeatAction, self.repeatButton, self.repeatTimer = action, button, REPEAT_DELAY
	end
end

----------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------

function KB:RefreshKeys()
	if not self.frame then return end
	local st = self.state
	local upper = st.layer == "letters" and (st.shift or st.caps)
	for side, half in pairs(self.halves) do
		local grid = LAYERS[st.layer][side]
		for r = 1, ROWS do
			for c = 1, COLS do
				local ch = grid[r][c]
				half.keys[r][c].text:SetText(upper and ch:upper() or ch)
			end
		end
	end
	self.halves.left.title:SetText(ns.ButtonIcon("LSTICK", 20) .. "  pick     type  " .. ns.ButtonIcon("PADLTRIGGER", 20))
	self.halves.right.title:SetText(ns.ButtonIcon("PADRTRIGGER", 20) .. "  type     pick  " .. ns.ButtonIcon("RSTICK", 20))

	local mode = st.layer == "symbols" and "123" or (st.caps and "|cffffd100CAPS|r" or (st.shift and "|cffffd100Shift|r" or "abc"))
	self.modeText:SetText(mode)
	self.modeString = mode
	self:RefreshSelection()
	if self.swipePanel then
		self:RefreshSwipeKeys()
		self:RefreshStatus()
	end
end

function KB:RefreshSelection()
	if not self.frame then return end
	local st = self.state
	local upper = st.layer == "letters" and (st.shift or st.caps)
	for side, half in pairs(self.halves) do
		local sr, sc = st.sel[side][1], st.sel[side][2]
		local on = side == "left" and COLOR_LEFT or COLOR_RIGHT
		for r = 1, ROWS do
			for c = 1, COLS do
				paintKey(half.keys[r][c], (r == sr and c == sc) and side or "rest")
			end
		end
	end
	local function label(side)
		local ch = LAYERS[st.layer][side][st.sel[side][1]][st.sel[side][2]]
		return upper and ch:upper() or ch
	end
	self.selLeftText:SetText(ns.ButtonIcon("PADLTRIGGER", 26) .. " " .. label("left"))
	self.selRightText:SetText(label("right") .. " " .. ns.ButtonIcon("PADRTRIGGER", 26))
end

function KB:Flash(side, r, c)
	paintKey(self.halves[side].keys[r][c], "flash")
	C_Timer.After(0.08, function() KB:RefreshSelection() end)
end

local function escape(s) return (s:gsub("|", "||")) end

function KB:RefreshStatus()
	if not self.frame then return end
	local text = ""
	local mic = "|T" .. ns.IconPath("mic") .. ":16:16|t "
	if self.voiceState == "listening" then
		text = "|T" .. ns.IconPath("mic_live") .. ":16:16|t |cffff5555Listening...|r"
	elseif self.voiceState == "thinking" then
		text = mic .. "|cffaaaaaaWriting it down...|r"
	elseif self.voiceState == "noapp" then
		text = mic .. "|cffff9900Voice helper isn't running. Start Comunimate from the Start menu.|r"
	elseif self.status then
		text = self.status
	end
	self.statusText:SetText(text)
	-- Swipe layout: the same status (or the shift / caps / 123 mode) above the keys.
	if self.swipeStatus then
		self.swipeStatus:SetText(text ~= "" and text or (self.modeString or ""))
	end

	-- Voice-only box title.
	if self.compact then
		local title
		if self.status and not self.voiceState then
			title = self.status
		elseif self.voiceState == "listening" then
			title = "|cffff6050Listening to your wisdom...|r"
		elseif self.voiceState == "thinking" then
			title = "Writing down your wisdom..."
		elseif self.voiceState == "noapp" then
			title = "|cffff9900The voice helper isn't running.|r"
		elseif (self.input:GetText() or ""):find("%S") then
			title = "Your wisdom is ready. Send it to chat?"
		else
			title = "Hold the mic button and share your wisdom."
		end
		self.compactTitle:SetText(title)
		self.compactMascot:SetTexture(ns.Mascot:Path(self.voiceState == "listening"))
	end
end

function KB:RefreshChannel()
	if not self.frame then return end
	self.channelText:SetText(ns.Chat:ChannelLabel(ns.db.channel) .. "  " .. ns.ActionButtonIcon("CHANNEL", 18))
end

function KB:RefreshSuggestions()
	if not self.frame then return end
	local st = self.state
	for i, slot in ipairs(self.sugSlots) do
		local word = st.suggestions[i]
		slot:SetText(word and escape(word) or "")
		slot:SetEnabled(word ~= nil)
		if word and i == st.sugIndex then slot:LockHighlight() else slot:UnlockHighlight() end
	end
end

local LEGEND = {
	{ { "SPACE" }, { "BACKSPACE" }, { "ACCEPT" }, { "PREV_SUGGESTION", "NEXT_SUGGESTION", "Pick word" }, { "SHIFT" }, { "CAPSLOCK" } },
	{ { "SYMBOLS" }, { "CHANNEL" }, { "CLEAR" }, { "VOICE" }, { "SEND" }, { "CLOSE" } },
}

local LEGEND_SWIPE = {
	{ { "TYPE_LEFT", "TYPE_RIGHT", "Hold: swipe  /  tap: one key" }, { "PREV_SUGGESTION", "NEXT_SUGGESTION", "Other word" },
		{ "BACKSPACE" }, { "SHIFT" }, { "CAPSLOCK" } },
	{ { "SYMBOLS" }, { "SPACE" }, { "CHANNEL" }, { "VOICE" }, { "SEND" }, { "CLOSE" } },
}

local LEGEND_ICON = 18

function KB:RefreshLegend()
	if not self.frame then return end
	local legend = ns.db.cursorMode == "swipe" and LEGEND_SWIPE or LEGEND
	for line, items in ipairs(legend) do
		local parts = {}
		for _, item in ipairs(items) do
			if item[3] then
				parts[#parts + 1] = ns.ActionButtonIcon(item[1], LEGEND_ICON) .. ns.ActionButtonIcon(item[2], LEGEND_ICON) .. " " .. item[3]
			else
				parts[#parts + 1] = ns.ActionButtonIcon(item[1], LEGEND_ICON) .. " " .. ns.ActionLabels[item[1]]
			end
		end
		self.legend[line]:SetText(table.concat(parts, "    "))
	end
	local icon = function(action) return ns.ActionButtonIcon(action, LEGEND_ICON) end
	self.compactHint:SetText(icon("VOICE") .. " Hold to add more    " .. icon("BACKSPACE") .. " Delete    "
		.. icon("ACCEPT") .. " Keyboard")
	self.compactSend:SetText(icon("SEND") .. " Send to chat")
	self.compactCancel:SetText(icon("CLOSE") .. " Cancel")
end

function KB:RefreshAll()
	if not self.frame then return end
	self.debugText:SetShown(ns.db.debug)
	self:UpdateLayoutMode()
	self:ApplyTrailColor()
	if ns.db.swipeTrail == "off" and self.swipePanel then self:ClearTrail() end
	self:RefreshKeys()
	self:RefreshLegend()
	self:RefreshChannel()
	self:RefreshStatus()
	self:RefreshSuggestions()
end

----------------------------------------------------------------------
-- Swipe typing (Settings > Sticks > Stick style: Swipe)
--
-- One QWERTY block and one ring; either stick moves it. Hold L2 or R2 and
-- trace through a word's letters, let go, and the best guess is typed with a
-- space. The other guesses sit in the bar: D-Left / D-Right swaps them in.
-- A quick press without moving types the key under the ring. Word guessing
-- lives in Swipe.lua.
----------------------------------------------------------------------

local U = KEY + GAP              -- one key, in pixels
local SWIPE_W, SWIPE_H = 11.5 * U, 3 * U
-- Punctuation at the end of the bottom row (tap them).
local SWIPE_EXTRA = { { ch = ",", x = 9.0, y = 2.5 }, { ch = ".", x = 10.0, y = 2.5 }, { ch = "?", x = 11.0, y = 2.5 } }
-- R1: numbers and symbols on the same keys (rows of 10, 9 and 7).
local SWIPE_SYMBOLS = { "1234567890", "!@#$%&*()", "-/:;\"'_" }
local TAP_DISTANCE = 0.35        -- traces shorter than this (in keys) are a tap
local TRACE_STEP = 0.08          -- record a point every this many keys
local DWELL_TIME = 0.14          -- resting this long on a key marks it
local PREVIEW_EVERY = 0.06       -- seconds between live guesses
local TRAIL_DOTS = 48
local TRAIL_SEGS = 90            -- light trail pieces (about 1.5 s of path)
local SEG_MIN = 0.2              -- light trail: a new piece every this many keys
local RING_TEX = "Interface\\AddOns\\Comunimate\\Media\\ring"
local GLOW_TEX = "Interface\\AddOns\\Comunimate\\Media\\trail_glow"
local GOLD = { 1, 0.82, 0.25 }
local sqrt = math.sqrt

-- Trail colors (Settings > Sticks > Trail color). "class" = your class color.
KB.TRAIL_COLORS = {
	{ key = "gold",   name = "Gold",          rgb = { 1, 0.82, 0.25 } },
	{ key = "fel",    name = "Fel green",     rgb = { 0.35, 1, 0.3 } },
	{ key = "frost",  name = "Frost blue",    rgb = { 0.4, 0.8, 1 } },
	{ key = "arcane", name = "Arcane purple", rgb = { 0.75, 0.45, 1 } },
	{ key = "fire",   name = "Fire",          rgb = { 1, 0.45, 0.12 } },
	{ key = "holy",   name = "Holy white",    rgb = { 1, 0.97, 0.85 } },
	{ key = "blood",  name = "Blood red",     rgb = { 0.9, 0.1, 0.15 } },
	{ key = "class",  name = "My class color" },
}

function KB:TrailRGB(key)
	key = key or ns.db.swipeTrailColor
	if key == "class" then
		local _, class = UnitClass("player")
		local c = class and ((C_ClassColor and C_ClassColor.GetClassColor(class)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
		if c then return c.r, c.g, c.b end
		key = "gold"
	end
	for _, c in ipairs(self.TRAIL_COLORS) do
		if c.key == key then return c.rgb[1], c.rgb[2], c.rgb[3] end
	end
	return GOLD[1], GOLD[2], GOLD[3]
end

-- Color choices for the settings window, each name in its own color.
function KB:TrailColorChoices()
	local list = {}
	for _, c in ipairs(self.TRAIL_COLORS) do
		local r, g, b = self:TrailRGB(c.key)
		local function byte(v) return math.floor(v * 255 + 0.5) end
		list[#list + 1] = { c.key, ("|cff%02x%02x%02x%s|r"):format(byte(r), byte(g), byte(b), c.name) }
	end
	return list
end

-- Paint the ring and trail in the chosen color. The light trail's core is
-- the same color lifted toward white, so it shines.
function KB:ApplyTrailColor()
	local p = self.swipePanel
	if not p then return end
	local r, g, b = self:TrailRGB()
	p.ring:SetVertexColor(r, g, b, 0.95)
	for _, d in ipairs(p.dots) do d:SetVertexColor(r, g, b) end
	local cr, cg, cb = r + (1 - r) * 0.55, g + (1 - g) * 0.55, b + (1 - b) * 0.55
	for _, s in ipairs(p.segs) do
		s.glow:SetVertexColor(r, g, b, 0.6)
		s.core:SetVertexColor(cr, cg, cb, 1)
	end
end

function KB:BuildSwipePanel()
	local f = self.frame
	local p = CreateFrame("Frame", nil, f)
	p:SetSize(SWIPE_W, SWIPE_H)
	p:SetPoint("TOP", f, "TOP", 0, -GRID_TOP)
	p:Hide()
	self.swipePanel = p
	p.keys = {}
	local function addKey(id, x, y)
		local k = makeKey(p, x * U - KEY / 2, y * U - KEY / 2)
		k.id, k.cx, k.cy = id, x, y
		p.keys[#p.keys + 1] = k
		return k
	end
	for r, row in ipairs(ns.Swipe.ROWS) do
		for i = 1, #row do
			local ch = row:sub(i, i)
			local pos = ns.Swipe.POS[ch]
			local k = addKey(ch, pos.x, pos.y)
			k.row, k.col = r, i
		end
	end
	for _, e in ipairs(SWIPE_EXTRA) do addKey(e.ch, e.x, e.y) end

	-- Ring, trail and the floating guess sit above the keys.
	local top = CreateFrame("Frame", nil, p)
	top:SetAllPoints()
	top:SetFrameLevel(p:GetFrameLevel() + 20)
	p.dots = {}
	for i = 1, TRAIL_DOTS do
		local d = top:CreateTexture(nil, "ARTWORK")
		d:SetTexture(RING_TEX)
		d:SetSize(12, 12)
		d:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
		d:Hide()
		p.dots[i] = d
	end
	p.dotNext = 1
	-- Light trail: each piece is a wide soft glow plus a bright core, added
	-- together so the streak shines.
	p.segs = {}
	for i = 1, TRAIL_SEGS do
		local glow = top:CreateLine(nil, "ARTWORK", nil, 1)
		glow:SetTexture(GLOW_TEX)
		glow:SetBlendMode("ADD")
		glow:SetVertexColor(GOLD[1], GOLD[2] * 0.8, GOLD[3] * 0.6, 0.55)
		glow:Hide()
		local core = top:CreateLine(nil, "ARTWORK", nil, 2)
		core:SetTexture(GLOW_TEX)
		core:SetBlendMode("ADD")
		core:SetVertexColor(1, 0.95, 0.75, 1)
		core:Hide()
		p.segs[i] = { glow = glow, core = core, age = 0 }
	end
	p.segNext = 1
	local ring = top:CreateTexture(nil, "OVERLAY")
	ring:SetTexture(RING_TEX)
	ring:SetSize(KEY * 1.1, KEY * 1.1)
	ring:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.95)
	p.ring = ring

	local guessBg = top:CreateTexture(nil, "OVERLAY", nil, 1)
	guessBg:SetColorTexture(0, 0, 0, 0.75)
	local guess = top:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	guess:SetDrawLayer("OVERLAY", 2)
	guessBg:SetPoint("TOPLEFT", guess, "TOPLEFT", -6, 3)
	guessBg:SetPoint("BOTTOMRIGHT", guess, "BOTTOMRIGHT", 6, -3)
	guess:Hide()
	guessBg:Hide()
	p.guess, p.guessBg = guess, guessBg

	local status = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	status:SetPoint("BOTTOM", p, "TOP", 0, 3)
	self.swipeStatus = status

	self.swipeCursor = { x = 5.0, y = 1.5 }
	self:PlaceSwipeRing()
	self:ApplyTrailColor()
end

-- Show the swipe block or the split halves, to match the stick style.
function KB:UpdateLayoutMode()
	if not self.swipePanel then return end
	local swipe = ns.db.cursorMode == "swipe"
	local full = not self.compact
	self.halves.left:SetShown(full and not swipe)
	self.halves.right:SetShown(full and not swipe)
	self.mid:SetShown(full and not swipe)
	self.swipePanel:SetShown(full and swipe)
	if not swipe then self.trace = nil end
end

function KB:PlaceSwipeRing()
	local p, c = self.swipePanel, self.swipeCursor
	p.ring:ClearAllPoints()
	p.ring:SetPoint("CENTER", p, "TOPLEFT", c.x * U, -c.y * U)
	if p.guess:IsShown() then
		p.guess:ClearAllPoints()
		p.guess:SetPoint("BOTTOM", p, "TOPLEFT", c.x * U, -c.y * U + KEY * 0.7)
	end
end

-- The key frame under a point (key units), or nil.
function KB:SwipeKeyAt(x, y)
	local best, bestD = nil, 0.72
	for _, k in ipairs(self.swipePanel.keys) do
		local dx, dy = x - k.cx, y - k.cy
		local d = sqrt(dx * dx + dy * dy)
		if d < bestD then best, bestD = k, d end
	end
	return best
end

-- What a key types right now (layer, shift, caps).
function KB:SwipeChar(k)
	local st = self.state
	if st.layer == "symbols" and k.row then
		return SWIPE_SYMBOLS[k.row]:sub(k.col, k.col)
	end
	if k.row and (st.shift or st.caps) then return k.id:upper() end
	return k.id
end

function KB:RefreshSwipeKeys()
	local p = self.swipePanel
	if not p then return end
	for _, k in ipairs(p.keys) do
		k.text:SetText(self:SwipeChar(k))
		paintKey(k, k == self.swipeHover and "left" or "rest")
	end
end

function KB:ShowSwipePreview(word)
	local p = self.swipePanel
	if word then
		p.guess:SetText(word)
		p.guess:Show()
		p.guessBg:Show()
		self:PlaceSwipeRing()
	else
		p.guess:Hide()
		p.guessBg:Hide()
	end
end

-- Trail (Settings > Sticks > Swipe trail: light / dots / off)
function KB:AddTrailPoint(x, y)
	local style = ns.db.swipeTrail or "light"
	if style == "dots" then
		self:AddTrailDot(x, y)
	elseif style == "light" then
		local prev = self.trailPrev
		if prev then
			local dx, dy = x - prev.x, y - prev.y
			if dx * dx + dy * dy < SEG_MIN * SEG_MIN then return end  -- wait for a longer piece
			local p = self.swipePanel
			local s = p.segs[p.segNext]
			p.segNext = p.segNext % TRAIL_SEGS + 1
			for _, line in ipairs({ s.glow, s.core }) do
				line:SetStartPoint("TOPLEFT", p, prev.x * U, -prev.y * U)
				line:SetEndPoint("TOPLEFT", p, x * U, -y * U)
				line:SetAlpha(1)
				line:Show()
			end
			s.glow:SetThickness(18)
			s.core:SetThickness(6)
			s.age = 0
		end
	end
	self.trailPrev = { x = x, y = y }
end

function KB:AddTrailDot(x, y)
	local p = self.swipePanel
	local d = p.dots[p.dotNext]
	p.dotNext = p.dotNext % TRAIL_DOTS + 1
	d:ClearAllPoints()
	d:SetPoint("CENTER", p, "TOPLEFT", x * U, -y * U)
	d.age = 0
	d:SetAlpha(1)
	d:Show()
end

function KB:ClearTrail()
	local p = self.swipePanel
	for _, d in ipairs(p.dots) do d:Hide() end
	for _, s in ipairs(p.segs) do
		s.glow:Hide()
		s.core:Hide()
	end
	self.trailPrev = nil
end

function KB:FadeTrail(elapsed)
	local p = self.swipePanel
	local life = self.trace and 1.6 or 0.35  -- fades fast once you let go
	for _, d in ipairs(p.dots) do
		if d:IsShown() then
			d.age = (d.age or 0) + elapsed
			local a = 1 - d.age / life
			if a <= 0 then d:Hide() else d:SetAlpha(a) end
		end
	end
	-- Light trail: a short bright streak that thins and fades behind the ring.
	local lightLife = self.trace and 0.9 or 0.3
	for _, s in ipairs(p.segs) do
		if s.core:IsShown() then
			s.age = s.age + elapsed
			local a = 1 - s.age / lightLife
			if a <= 0 then
				s.glow:Hide()
				s.core:Hide()
			else
				a = a * a
				s.glow:SetAlpha(a)
				s.core:SetAlpha(a)
				s.glow:SetThickness(6 + 12 * a)
				s.core:SetThickness(2 + 4 * a)
			end
		end
	end
end

-- Every frame while the keyboard is open in swipe style.
function KB:UpdateSwipe(lx, ly, rx, ry, elapsed)
	-- Either stick: whichever is pushed further.
	local x, y = lx, ly
	if rx * rx + ry * ry > lx * lx + ly * ly then x, y = rx, ry end
	if ns.db.invertY then y = -y end
	local c = self.swipeCursor
	local mag = sqrt(x * x + y * y)
	local moving = mag > STICK_DEADZONE
	if moving then
		local push = math.min(1, (mag - STICK_DEADZONE) / (1 - STICK_DEADZONE))
		local speed = (ns.db.cursorSpeed or 520) / U * push ^ 1.6  -- keys per second
		c.x = math.min(SWIPE_W / U - 0.05, math.max(0.05, c.x + x / mag * speed * elapsed))
		c.y = math.min(2.95, math.max(0.05, c.y - y / mag * speed * elapsed))
		self:PlaceSwipeRing()
	end

	local hover = self:SwipeKeyAt(c.x, c.y)
	if hover ~= self.swipeHover then
		self.swipeHover = hover
		self:RefreshSwipeKeys()
	end

	local t = self.trace
	if t then
		local last = t.points[#t.points]
		local dx, dy = c.x - last.x, c.y - last.y
		local d = sqrt(dx * dx + dy * dy)
		if d >= TRACE_STEP then
			t.points[#t.points + 1] = { x = c.x, y = c.y }
			t.len = t.len + d
			t.still = 0
			self:AddTrailPoint(c.x, c.y)
		elseif not moving then
			t.still = t.still + elapsed
			if t.still >= DWELL_TIME then last.dwell = true end
		end
		-- Live guess, when the ring reaches a new key.
		t.sinceGuess = t.sinceGuess + elapsed
		if self.state.layer == "letters" and t.len >= TAP_DISTANCE and t.sinceGuess >= PREVIEW_EVERY
			and hover ~= t.guessKey then
			t.sinceGuess, t.guessKey = 0, hover
			local words = ns.Swipe:Decode(t.points, SUGGESTIONS)
			self:ShowSwipePreview(words[1])
			self.state.suggestions, self.state.sugIndex = words, 1
			self:RefreshSuggestions()
		end
	end
	self:FadeTrail(elapsed)
end

function KB:StartTrace(button)
	local c = self.swipeCursor
	self.trace = { button = button, points = { { x = c.x, y = c.y } }, len = 0, still = 0, sinceGuess = 0 }
	self:ClearTrail()
	self:AddTrailPoint(c.x, c.y)
end

function KB:FinishTrace()
	local t = self.trace
	self.trace = nil
	self:ShowSwipePreview(nil)
	if t.len < TAP_DISTANCE or self.state.layer ~= "letters" then
		local k = self:SwipeKeyAt(self.swipeCursor.x, self.swipeCursor.y)
		if k then self:TypeSwipeKey(k) end
		return
	end
	local words = ns.Swipe:Decode(t.points, SUGGESTIONS)
	if #words == 0 then
		self:SetStatus("|cffff7f40No word matched that swipe. Try again, or tap the letters.|r", 3)
		self:OnTextChanged()
		return
	end
	self.lastSwipe = nil
	self:InsertSwipeWord(words, 1)
end

-- Tap: one key. Punctuation tucks in against the word before it.
function KB:TypeSwipeKey(k)
	local ch = self:SwipeChar(k)
	local eb = self.input
	self.lastSwipe = nil
	if ch == "." or ch == "," or ch == "?" or ch == "!" then
		local before, after = splitAtCursor(eb)
		if before:find(" $") then before = before:sub(1, -2) end
		before = before .. ch .. " "
		eb:SetText(before .. after)
		eb:SetCursorPosition(#before)
	else
		self:Insert(ch)
	end
	paintKey(k, "flash")
	C_Timer.After(0.08, function() KB:RefreshSwipeKeys() end)
	if self.state.shift and k.row then
		self.state.shift = false
		self:RefreshKeys()
	end
end

-- Type a swiped word (words[index]) with automatic spacing and capitals. If the
-- last thing typed was a swiped word, it's replaced (swapping guesses).
function KB:InsertSwipeWord(words, index)
	local eb = self.input
	local before, after = splitAtCursor(eb)
	local ls = self.lastSwipe
	local capFirst
	if ls and before:sub(-#ls.inserted) == ls.inserted then
		before = before:sub(1, #before - #ls.inserted)
		capFirst = ls.capFirst
	else
		if before ~= "" and not before:find("%s$") then before = before .. " " end
		local st = self.state
		capFirst = st.shift or before:find("^%s*$") ~= nil or before:find("[%.%?!]%s*$") ~= nil
		if st.shift then
			st.shift = false
			self:RefreshKeys()
		end
	end
	local w = words[index]
	if self.state.caps then
		w = w:upper()
	elseif capFirst then
		w = w:sub(1, 1):upper() .. w:sub(2)
	end
	local inserted = w .. " "
	-- Set before changing the text: OnTextChanged keeps these guesses in the bar.
	self.lastSwipe = { words = words, index = index, inserted = inserted, capFirst = capFirst }
	eb:SetText(before .. inserted .. after)
	eb:SetCursorPosition(#before + #inserted)
	self.state.suggestions, self.state.sugIndex = words, index
	self:RefreshSuggestions()
end

-- Is the last swiped word still right before the cursor (so D-Left/Right swaps it)?
function KB:SwipeAltActive()
	local ls = self.lastSwipe
	if not ls or #ls.words < 2 then return false end
	local before = splitAtCursor(self.input)
	return before:sub(-#ls.inserted) == ls.inserted
end

function KB:CycleSwipeAlt(dir)
	local ls = self.lastSwipe
	local i = (ls.index - 1 + dir) % #ls.words + 1
	self:InsertSwipeWord(ls.words, i)
end
