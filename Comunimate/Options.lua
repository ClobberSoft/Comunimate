-- The settings window: a sidebar of pages, rows with a description on the
-- left and a control on the right (switches, sliders, choices, buttons).
-- Every change applies live. Works with the mouse and fully with a controller:
--   D-pad up/down  pick a setting      D-pad left/right  change it
--   Cross / A      press / flip         L1 / R1           previous / next page
--   Circle / B     close

local _, ns = ...
local O = {}
ns.Options = O

----------------------------------------------------------------------
-- Look
----------------------------------------------------------------------

local C = {
	ground  = { 0.075, 0.063, 0.052, 0.97 },
	header  = { 0.10, 0.083, 0.064, 1 },
	sidebar = { 0.052, 0.044, 0.037, 1 },
	control = { 0.14, 0.12, 0.10, 1 },
	hover   = { 1, 0.86, 0.55, 0.06 },
	focus   = { 1, 0.82, 0.0, 0.10 },
	line    = { 1, 0.86, 0.55, 0.16 },
	accent  = { 1, 0.82, 0.0, 1 },
	accentSoft = { 1, 0.82, 0.0, 0.22 },
	text    = { 0.97, 0.94, 0.87, 1 },
	dim     = { 0.76, 0.71, 0.62, 1 },
	muted   = { 0.55, 0.51, 0.45, 1 },
	off     = { 0.27, 0.24, 0.21, 1 },
	knob    = { 0.95, 0.92, 0.85, 1 },
}

local WIN_W, WIN_H = 780, 660
local SIDE_W, HEADER_H = 180, 170  -- header matches tools/make_header.py
local BANNER_V = 446 / 512         -- the filled part of Media/header.tga
local PAGE_PAD = 26
local ROW_H, INFO_H = 58, 76
local CONTROL_W = 250

local function tex(parent, layer, color)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND")
	t:SetColorTexture(unpack(color))
	return t
end

-- A 1-pixel frame around f.
local function hairline(f, color)
	local edges = {}
	for i, spec in ipairs({
		{ "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
		{ "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false },
	}) do
		local t = tex(f, "BORDER", color)
		t:SetPoint(spec[1])
		t:SetPoint(spec[2])
		if spec[3] then t:SetHeight(1) else t:SetWidth(1) end
		edges[i] = t
	end
	f.edges = edges
	return edges
end

local function setEdgeColor(f, color)
	for _, t in ipairs(f.edges or {}) do t:SetColorTexture(unpack(color)) end
end

local function text(parent, template, color)
	local fs = parent:CreateFontString(nil, "OVERLAY", template)
	if color then fs:SetTextColor(unpack(color)) end
	fs:SetJustifyH("LEFT")
	return fs
end

----------------------------------------------------------------------
-- Settings
----------------------------------------------------------------------

local function get(key) return ns.db[key] end

local function set(key, value)
	ns.db[key] = value
	ns:ApplySettings(key)
end

----------------------------------------------------------------------
-- Controls. Each has :Refresh(), :Nudge(dir) and :Activate() so the
-- controller can drive it the same way as the mouse.
----------------------------------------------------------------------

local function makeToggle(row, def)
	local b = CreateFrame("Button", nil, row)
	b:SetSize(46, 22)
	b.track = tex(b, "BACKGROUND", C.off)
	b.track:SetAllPoints()
	b.knob = tex(b, "ARTWORK", C.knob)
	b.knob:SetSize(18, 18)
	b.state = text(b, "GameFontHighlightSmall", C.dim)
	b.state:SetPoint("RIGHT", b, "LEFT", -10, 0)
	function b:Refresh()
		local on = get(def.key) and true or false
		self.track:SetColorTexture(unpack(on and C.accent or C.off))
		self.knob:ClearAllPoints()
		self.knob:SetPoint(on and "RIGHT" or "LEFT", self, on and "RIGHT" or "LEFT", on and -2 or 2, 0)
		self.state:SetText(on and "On" or "Off")
		self.state:SetTextColor(unpack(on and C.text or C.muted))
	end
	function b:Activate() set(def.key, not get(def.key)); self:Refresh() end
	function b:Nudge(dir) set(def.key, dir > 0); self:Refresh() end
	b:SetScript("OnClick", function(self) self:Activate() end)
	return b
end

local function makeSlider(row, def)
	local holder = CreateFrame("Frame", nil, row)
	holder:SetSize(CONTROL_W, 24)

	local value = text(holder, "GameFontHighlight", C.text)
	value:SetPoint("RIGHT")
	value:SetWidth(48)
	value:SetJustifyH("RIGHT")

	local s = CreateFrame("Slider", nil, holder)
	s:SetOrientation("HORIZONTAL")
	s:SetPoint("LEFT")
	s:SetPoint("RIGHT", value, "LEFT", -12, 0)
	s:SetHeight(18)
	s:SetMinMaxValues(def.min, def.max)
	s:SetValueStep(def.step)
	s:SetObeyStepOnDrag(true)
	s:EnableMouseWheel(true)
	local track = tex(s, "BACKGROUND", C.off)
	track:SetHeight(4)
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")
	local fill = tex(s, "BORDER", C.accent)
	fill:SetHeight(4)
	fill:SetPoint("LEFT", track, "LEFT")
	local thumb = s:CreateTexture(nil, "OVERLAY")
	thumb:SetColorTexture(unpack(C.knob))
	thumb:SetSize(10, 18)
	s:SetThumbTexture(thumb)

	local function show(v)
		local mult = def.mult or 1
		value:SetText(def.fmt and def.fmt:format(v * mult) or tostring(v))
		local w = track:GetWidth()
		if w and w > 0 then
			fill:SetWidth(math.max(1, (v - def.min) / (def.max - def.min) * w))
		end
	end
	s:SetScript("OnValueChanged", function(_, v)
		v = math.floor(v / def.step + 0.5) * def.step
		show(v)
		if not holder.refreshing and math.abs((get(def.key) or 0) - v) > 1e-6 then set(def.key, v) end
	end)
	s:SetScript("OnMouseWheel", function(_, delta) holder:Nudge(delta) end)
	s:SetScript("OnSizeChanged", function() show(s:GetValue()) end)

	function holder:Refresh()
		self.refreshing = true
		s:SetValue(get(def.key) or def.min)
		self.refreshing = false
		show(s:GetValue())
	end
	function holder:Nudge(dir)
		local v = math.min(def.max, math.max(def.min, (get(def.key) or def.min) + dir * def.step))
		s:SetValue(v)
	end
	function holder:Activate() end
	return holder
end

local function choicesOf(def)
	return type(def.choices) == "function" and def.choices() or def.choices
end

local function indexOf(def)
	local cur = get(def.key)
	for i, c in ipairs(choicesOf(def)) do
		if c[1] == cur then return i end
	end
	return 1
end

-- A row of buttons, one per choice (few choices).
local function makeSegmented(row, def)
	local holder = CreateFrame("Frame", nil, row)
	local choices = choicesOf(def)
	local bw = math.floor((CONTROL_W - (#choices - 1) * 4) / #choices)
	holder:SetSize(CONTROL_W, 26)
	holder.buttons = {}
	for i, c in ipairs(choices) do
		local b = CreateFrame("Button", nil, holder)
		b:SetSize(bw, 26)
		b:SetPoint("LEFT", holder, "LEFT", (i - 1) * (bw + 4), 0)
		b.bg = tex(b, "BACKGROUND", C.control)
		b.bg:SetAllPoints()
		hairline(b, C.line)
		b.label = text(b, "GameFontHighlightSmall", C.dim)
		b.label:SetPoint("CENTER")
		b.label:SetJustifyH("CENTER")
		b.label:SetText(c[2])
		b:SetScript("OnClick", function() set(def.key, c[1]); holder:Refresh() end)
		holder.buttons[i] = b
	end
	function holder:Refresh()
		local cur = indexOf(def)
		for i, b in ipairs(self.buttons) do
			local on = i == cur
			b.bg:SetColorTexture(unpack(on and C.accentSoft or C.control))
			setEdgeColor(b, on and C.accent or C.line)
			b.label:SetTextColor(unpack(on and C.accent or C.dim))
		end
	end
	function holder:Nudge(dir)
		local list = choicesOf(def)
		local i = math.min(#list, math.max(1, indexOf(def) + dir))
		set(def.key, list[i][1])
		self:Refresh()
	end
	function holder:Activate()
		local list = choicesOf(def)
		set(def.key, list[indexOf(def) % #list + 1][1])
		self:Refresh()
	end
	return holder
end

-- "<  value  >" for longer lists.
local function makeCycle(row, def)
	local holder = CreateFrame("Frame", nil, row)
	holder:SetSize(CONTROL_W, 26)
	local bg = tex(holder, "BACKGROUND", C.control)
	bg:SetAllPoints()
	hairline(holder, C.line)
	local function arrow(label, point, dir)
		local b = CreateFrame("Button", nil, holder)
		b:SetSize(30, 26)
		b:SetPoint(point)
		b.label = text(b, "GameFontNormal", C.accent)
		b.label:SetPoint("CENTER")
		b.label:SetText(label)
		b:SetScript("OnClick", function() holder:Nudge(dir) end)
		return b
	end
	arrow("<", "LEFT", -1)
	arrow(">", "RIGHT", 1)
	local value = text(holder, "GameFontHighlight", C.text)
	value:SetPoint("CENTER")
	value:SetJustifyH("CENTER")
	function holder:Refresh()
		local list = choicesOf(def)
		value:SetText(list[indexOf(def)][2])
	end
	function holder:Nudge(dir)
		local list = choicesOf(def)
		set(def.key, list[(indexOf(def) - 1 + dir) % #list + 1][1])
		self:Refresh()
	end
	function holder:Activate() self:Nudge(1) end
	return holder
end

local function makeButton(row, def)
	local b = CreateFrame("Button", nil, row)
	b:SetSize(150, 26)
	b.bg = tex(b, "BACKGROUND", C.control)
	b.bg:SetAllPoints()
	hairline(b, C.accent)
	b.label = text(b, "GameFontNormal", C.accent)
	b.label:SetPoint("CENTER")
	b.label:SetJustifyH("CENTER")
	function b:Refresh()
		self.armed = nil
		self.label:SetText(def.text)
	end
	function b:Activate()
		if def.confirm and not self.armed then
			self.armed = true
			self.label:SetText("Press again to confirm")
			C_Timer.After(3, function() if b.armed then b:Refresh() end end)
			return
		end
		self:Refresh()
		def.run()
	end
	function b:Nudge() end
	b:SetScript("OnClick", function(self) self:Activate() end)
	b:SetScript("OnEnter", function(self) self.bg:SetColorTexture(unpack(C.accentSoft)) end)
	b:SetScript("OnLeave", function(self) self.bg:SetColorTexture(unpack(C.control)) end)
	return b
end

-- Both moods of the chosen mascot, side by side.
local function makePreview(row)
	local holder = CreateFrame("Frame", nil, row)
	holder:SetSize(CONTROL_W, 120)
	local function pic(x, caption)
		local t = holder:CreateTexture(nil, "ARTWORK")
		t:SetSize(104, 104)
		t:SetPoint("TOPLEFT", holder, "TOPLEFT", x, 0)
		local fs = text(holder, "GameFontHighlightSmall", C.dim)
		fs:SetPoint("TOP", t, "BOTTOM", 0, -2)
		fs:SetJustifyH("CENTER")
		fs:SetText(caption)
		return t
	end
	holder.quiet = pic(10, "Quiet")
	holder.loud = pic(136, "Talking")
	function holder:Refresh()
		self.quiet:SetTexture(ns.Mascot:Path(false))
		self.loud:SetTexture(ns.Mascot:Path(true))
	end
	return holder
end

-- A keyboard action and the controller button doing it. Press (or click) to
-- remap: the next controller button you press takes the action.
local function makeBind(row, def)
	local b = CreateFrame("Button", nil, row)
	b:SetSize(170, 32)
	b.bg = tex(b, "BACKGROUND", C.control)
	b.bg:SetAllPoints()
	hairline(b, C.line)
	b.label = text(b, "GameFontHighlight", C.text)
	b.label:SetPoint("CENTER")
	b.label:SetJustifyH("CENTER")
	function b:Refresh()
		if O.capture == self then
			self.label:SetText("|cffffd100Press a button...|r")
			setEdgeColor(self, C.accent)
			return
		end
		setEdgeColor(self, C.line)
		local button = ns.ActionButton(def.action)
		if button then
			self.label:SetText(ns.ButtonIcon(button, 22) .. "  " .. ns.ButtonLabel(button))
		else
			self.label:SetText("|cff888888Not set|r")
		end
	end
	function b:Activate() O:StartCapture(self, def) end
	function b:Nudge() end
	b:SetScript("OnClick", function(self) self:Activate() end)
	b:SetScript("OnEnter", function(self) self.bg:SetColorTexture(unpack(C.accentSoft)) end)
	b:SetScript("OnLeave", function(self) self.bg:SetColorTexture(unpack(C.control)) end)
	return b
end

-- The button or key you hold to talk. device: "pad" (controller) or "key"
-- (keyboard key or mouse button). The Comunimate app reads it from WoW's
-- saved settings, which WoW writes on /reload or logout.
local function makeTalkBind(row, def)
	local b = makeBind(row, def)
	b:SetSize(190, 32)
	function b:Refresh()
		if O.capture == self then
			self.label:SetText(def.device == "pad" and "|cffffd100Press a controller button...|r"
				or "|cffffd100Press a key (Backspace: none)|r")
			setEdgeColor(self, C.accent)
			return
		end
		setEdgeColor(self, C.line)
		if def.device == "pad" then
			local button = ns.db.talkButton
			self.label:SetText(ns.ButtonIcon(button, 22) .. "  " .. ns.ButtonLabel(button))
		else
			local key = ns.db.talkKey
			self.label:SetText(key and ("|cffffffff" .. (GetBindingText and GetBindingText(key) or key) .. "|r")
				or "|cff888888None|r")
		end
	end
	return b
end

local MAKERS = {
	toggle = makeToggle, slider = makeSlider, choice = makeSegmented,
	cycle = makeCycle, button = makeButton, bind = makeBind, talk = makeTalkBind,
}

local function bindRow(action, label)
	return { kind = "bind", action = action, label = label }
end

local resetButtons = {
	kind = "button", label = "Back to the defaults", desc = "Put every button back where it started.",
	text = "Reset buttons", confirm = true,
	run = function() ns.ResetButtons(); ns:ApplySettings("bindings") end,
}

----------------------------------------------------------------------
-- Pages
----------------------------------------------------------------------

local function channelChoices()
	local list = {}
	for i = 1, ns.Chat:NumChannels() do
		list[i] = { i, ns.Chat:ChannelLabel(i) }
	end
	return list
end

local PAGES = {
	{
		label = "General",
		intro = "How the keyboard behaves.",
		rows = {
			{ kind = "choice", key = "controller", label = "Controller",
				desc = "Which button icons the keyboard shows.",
				choices = { { "PLAYSTATION", "PlayStation" }, { "XBOX", "Xbox" }, { "STEAM", "Steam" } } },
			{ kind = "cycle", key = "channel", label = "Send to",
				desc = "Where messages go. Start a message with /p, /g or /w Name to pick one just once.",
				choices = channelChoices },
			{ kind = "toggle", key = "closeAfterSend", label = "Close after sending",
				desc = "Hide the keyboard once your message is sent." },
			{ kind = "toggle", key = "takeOverChatCombo", label = "Controller chat button opens the keyboard",
				desc = "L1 + R1 + D-Down opens Comunimate instead of the normal chat box." },
		},
	},
	{
		label = "Buttons",
		intro = "Pick an action, then press the controller button you want for it. Buttons swap if one is taken.",
		rows = {
			bindRow("TYPE_LEFT", "Type the left key"),
			bindRow("TYPE_RIGHT", "Type the right key"),
			bindRow("SPACE", "Space"),
			bindRow("BACKSPACE", "Delete"),
			bindRow("SHIFT", "Shift (one letter)"),
			bindRow("CAPSLOCK", "Caps lock"),
			bindRow("SYMBOLS", "Numbers and symbols"),
			resetButtons,
		},
	},
	{
		label = "More buttons",
		intro = "Words, channel, sending and closing.",
		rows = {
			bindRow("ACCEPT", "Use the picked word"),
			bindRow("PREV_SUGGESTION", "Previous word"),
			bindRow("NEXT_SUGGESTION", "Next word"),
			bindRow("CHANNEL", "Change channel"),
			bindRow("CLEAR", "Clear the line"),
			bindRow("SEND", "Send"),
			bindRow("CLOSE", "Close"),
			resetButtons,
		},
	},
	{
		label = "Look",
		intro = "Size and placement. Changes show right away.",
		rows = {
			{ kind = "slider", key = "scale", label = "Keyboard size", desc = "Make the whole keyboard bigger or smaller.",
				min = 0.6, max = 1.6, step = 0.05, fmt = "%d%%", mult = 100 },
			{ kind = "slider", key = "kbAlpha", label = "Background opacity", desc = "How see-through the keyboard's background is.",
				min = 0.3, max = 1, step = 0.05, fmt = "%d%%", mult = 100 },
			{ kind = "button", label = "Preview", desc = "Show the keyboard while you adjust it.",
				text = "Show keyboard", run = function() ns.Keyboard:Show() end },
			{ kind = "button", label = "Position", desc = "Drag the keyboard with the mouse to move it, or put it back here.",
				text = "Reset position", run = function() ns.db.position = nil; ns:ApplySettings("position") end },
		},
	},
	{
		label = "Mascot",
		intro = "Pick your hero: any race from the Horde, the Alliance or the Skyborne, in the style you like.",
		rows = {
			{ kind = "cycle", key = "mascotRace", label = "Race",
				desc = "\"My character\" follows whoever you're playing.",
				choices = function() return ns.Mascot:RaceChoices() end },
			{ kind = "choice", key = "mascotGender", label = "Male or female",
				desc = "\"Mine\" follows your character.",
				choices = function() return ns.Mascot:GenderChoices() end },
			{ kind = "choice", key = "mascotStyle", label = "Style",
				desc = "Cute cartoon, Epic war-painted hero, or Anime.",
				choices = function() return ns.Mascot:StyleChoices() end },
			{ kind = "preview", label = "Preview",
				desc = "Left: quiet.  Right: talking (mic held)." },
		},
	},
	{
		label = "Badge",
		intro = "The mascot on screen: relaxed while you're quiet, shouting while you talk.",
		rows = {
			{ kind = "toggle", key = "showBadge", label = "Show the mascot",
				desc = "Click it any time to open these settings." },
			{ kind = "slider", key = "badgeSize", label = "Size", desc = "How big the mascot is.",
				min = 32, max = 128, step = 4, fmt = "%d px" },
			{ kind = "toggle", key = "badgeFrame", label = "Gold frame",
				desc = "A gold ring around the portrait." },
			{ kind = "toggle", key = "badgeMovable", label = "Move the mascot",
				desc = "Turn on, drag it with the mouse, then turn off again." },
			{ kind = "button", label = "Position", desc = "Put the badge back in its starting spot.",
				text = "Reset position", run = function() ns.db.badgePosition = nil; ns:ApplySettings("badgePosition") end },
		},
	},
	{
		label = "Sticks",
		intro = "How the sticks pick keys.",
		rows = {
			{ kind = "choice", key = "cursorMode", label = "Stick style",
				desc = "Spring, Free, Snap: two rings, one per half. Swipe: one keyboard, hold L2/R2 and trace words.",
				choices = { { "spring", "Spring" }, { "free", "Free" }, { "snap", "Snap" }, { "swipe", "Swipe" } } },
			{ kind = "choice", key = "swipeTrail", label = "Swipe trail",
				desc = "Follows the ring while you swipe: a fading light streak, little circles, or nothing.",
				choices = { { "light", "Light" }, { "dots", "Dots" }, { "off", "Off" } } },
			{ kind = "cycle", key = "swipeTrailColor", label = "Trail color",
				desc = "Color of the swipe ring and trail.",
				choices = function() return ns.Keyboard:TrailColorChoices() end },
			{ kind = "slider", key = "cursorSpeed", label = "Ring speed",
				desc = "How fast the ring moves when you push the stick all the way.",
				min = 200, max = 1200, step = 20, fmt = "%d" },
			{ kind = "slider", key = "colOuter", label = "Snap: reach for the edge keys",
				desc = "In Snap style, how far to push to reach the outer keys.",
				min = 0.3, max = 0.95, step = 0.05, fmt = "%d%%", mult = 100 },
			{ kind = "toggle", key = "invertY", label = "Flip up and down",
				desc = "Turn on if pushing up picks the bottom row." },
		},
	},
	{
		label = "Voice",
		intro = "Talk instead of typing. Needs the Comunimate app (the orc in your system tray).",
		rows = {
			{ kind = "choice", key = "voiceShowsKeyboard", label = "When you talk, show",
				desc = "Small box: just \"Listening to your wisdom\" and your words, ready to send. "
					.. "Keyboard: the full keyboard.",
				choices = { { false, "Small box" }, { true, "Keyboard" } } },
			{ kind = "talk", device = "pad", label = "Talk button (controller)",
				desc = "Hold it to talk. Pick any button. /reload after changing." },
			{ kind = "talk", device = "key", label = "Talk key (keyboard or mouse)",
				desc = "For keyboard players: hold it to talk. /reload after changing." },
			{ kind = "toggle", key = "voiceOpensKeyboard", label = "Talking opens Comunimate",
				desc = "Off: your words go straight into whatever text box is open." },
			{ kind = "info", label = "How it works",
				desc = "Hold, talk, let go. Start with \"Say in party chat\" (or raid, guild, say, yell, general) "
					.. "to pick the channel. Microphone choice: right-click the orc in the system tray." },
		},
	},
	{
		label = "Words",
		intro = "Word suggestions above the keyboard.",
		rows = {
			{ kind = "toggle", key = "learn", label = "Learn my words",
				desc = "Suggestions get better from the messages you send. Stays on this PC." },
			{ kind = "button", label = "Forget learned words", desc = "Start suggestions fresh.",
				text = "Forget", confirm = true, run = function()
					wipe(ns.learned.words)
					wipe(ns.learned.bigrams)
					ns.Suggest:Init()
					ns:Print("learned words erased")
				end },
		},
	},
	{
		label = "About",
		rows = {
			{ kind = "info", label = "Comunimate",
				desc = "Chat with a controller: a split keyboard, WoW word suggestions and voice. "
					.. "Type /cm to open the keyboard, /cm options for this window." },
			{ kind = "toggle", key = "debug", label = "Debug messages",
				desc = "Print button names and stick values to chat. For troubleshooting." },
		},
	},
}

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------

local function makeRow(page, def, y)
	local row = CreateFrame("Frame", nil, page)
	local h = (def.kind == "info" and INFO_H) or (def.kind == "preview" and 140) or (def.kind == "bind" and 44) or ROW_H
	if def.kind == "talk" then h = 52 end
	row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
	row:SetPoint("RIGHT", page, "RIGHT")
	row:SetHeight(h)
	row:EnableMouse(true)
	row.def = def

	row.bg = tex(row, "BACKGROUND", { 0, 0, 0, 0 })
	row.bg:SetAllPoints()
	row.bar = tex(row, "ARTWORK", C.accent)
	row.bar:SetPoint("TOPLEFT")
	row.bar:SetPoint("BOTTOMLEFT")
	row.bar:SetWidth(2)
	row.bar:Hide()
	local rule = tex(row, "BORDER", C.line)
	rule:SetPoint("BOTTOMLEFT", 12, 0)
	rule:SetPoint("BOTTOMRIGHT", -12, 0)
	rule:SetHeight(1)

	local label = text(row, "GameFontHighlight", C.text)
	label:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -11)
	label:SetText(def.label)
	local desc = text(row, "GameFontHighlightSmall", C.dim)
	desc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
	desc:SetText(def.desc or "")
	desc:SetWordWrap(true)

	if def.kind == "preview" then
		-- Not a control: the controller skips it.
		row.preview = makePreview(row)
		row.preview:SetPoint("TOPRIGHT", row, "TOPRIGHT", -14, -10)
		label:SetPoint("RIGHT", row.preview, "LEFT", -24, 0)
		desc:SetPoint("RIGHT", row.preview, "LEFT", -24, 0)
	elseif def.kind ~= "info" then
		row.control = MAKERS[def.kind](row, def)
		row.control:SetPoint("RIGHT", row, "RIGHT", -14, 0)
		label:SetPoint("RIGHT", row.control, "LEFT", -24, 0)
		desc:SetPoint("RIGHT", row.control, "LEFT", -24, 0)
		if def.kind == "toggle" then
			label:SetPoint("RIGHT", row.control.state, "LEFT", -16, 0)
			desc:SetPoint("RIGHT", row.control.state, "LEFT", -16, 0)
		end
	else
		label:SetTextColor(unpack(C.accent))
		desc:SetPoint("RIGHT", row, "RIGHT", -14, 0)
	end

	row:SetScript("OnEnter", function(self) if O.focus ~= self then self.bg:SetColorTexture(unpack(C.hover)) end end)
	row:SetScript("OnLeave", function(self) if O.focus ~= self then self.bg:SetColorTexture(0, 0, 0, 0) end end)
	return row, h
end

function O:Build()
	if self.frame then return end
	local f = CreateFrame("Frame", "ComunimateOptions", UIParent)
	self.frame = f
	f:SetSize(WIN_W, WIN_H)
	f:SetPoint("CENTER")
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()

	-- Drop shadow, ground, frame.
	local shadow = tex(f, "BACKGROUND", { 0, 0, 0, 0.45 })
	shadow:SetPoint("TOPLEFT", -6, 6)
	shadow:SetPoint("BOTTOMRIGHT", 6, -6)
	local ground = tex(f, "BACKGROUND", C.ground)
	ground:SetAllPoints()
	hairline(f, C.line)

	-- Header band.
	local header = CreateFrame("Frame", nil, f)
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(HEADER_H)
	-- The banner art (Media/header.tga, made by tools/make_header.py).
	local banner = header:CreateTexture(nil, "BACKGROUND")
	banner:SetAllPoints()
	banner:SetTexture("Interface\\AddOns\\Comunimate\\Media\\header")
	banner:SetTexCoord(0, 1, 0, BANNER_V)
	-- Fade the bottom edge into the window, then a gold rule.
	local fade = header:CreateTexture(nil, "BORDER")
	fade:SetPoint("BOTTOMLEFT")
	fade:SetPoint("BOTTOMRIGHT")
	fade:SetHeight(28)
	fade:SetColorTexture(1, 1, 1, 1)
	fade:SetGradient("VERTICAL", CreateColor(C.ground[1], C.ground[2], C.ground[3], 0.9),
		CreateColor(C.ground[1], C.ground[2], C.ground[3], 0))
	local rule = tex(header, "ARTWORK", C.accent)
	rule:SetPoint("BOTTOMLEFT")
	rule:SetPoint("BOTTOMRIGHT")
	rule:SetHeight(1)

	local title = text(header, "GameFontNormal", C.accent)
	title:SetPoint("TOPLEFT", 14, -10)
	title:SetText("COMUNIMATE")
	title:SetShadowOffset(1, -1)
	title:SetShadowColor(0, 0, 0, 1)

	local close = CreateFrame("Button", nil, header)
	close:SetSize(30, 30)
	close:SetPoint("TOPRIGHT", -8, -8)
	close.bg = tex(close, "BACKGROUND", { 0, 0, 0, 0.55 })
	close.bg:SetAllPoints()
	close.label = text(close, "GameFontNormalLarge", C.text)
	close.label:SetPoint("CENTER", 0, 1)
	close.label:SetJustifyH("CENTER")
	close.label:SetText("x")
	close:SetScript("OnEnter", function(self) self.label:SetTextColor(unpack(C.accent)) end)
	close:SetScript("OnLeave", function(self) self.label:SetTextColor(unpack(C.text)) end)
	close:SetScript("OnClick", function() O:Hide() end)

	-- Controller hints along the bottom of the window.
	local hint = text(f, "GameFontHighlightSmall", C.muted)
	hint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAGE_PAD, 12)
	hint:SetJustifyH("RIGHT")
	self.hint = hint

	-- Sidebar.
	local side = CreateFrame("Frame", nil, f)
	side:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
	side:SetPoint("BOTTOMLEFT", 1, 1)
	side:SetWidth(SIDE_W)
	tex(side, "BACKGROUND", C.sidebar):SetAllPoints()
	local sideRule = tex(side, "BORDER", C.line)
	sideRule:SetPoint("TOPRIGHT")
	sideRule:SetPoint("BOTTOMRIGHT")
	sideRule:SetWidth(1)

	local version = text(side, "GameFontDisableSmall", C.muted)
	version:SetPoint("BOTTOMLEFT", 18, 14)
	version:SetText("v" .. (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("Comunimate", "Version") or ""))

	-- Pages.
	self.tabs, self.pages = {}, {}
	for i, def in ipairs(PAGES) do
		local tab = CreateFrame("Button", nil, side)
		tab:SetSize(SIDE_W - 1, 36)
		tab:SetPoint("TOPLEFT", side, "TOPLEFT", 0, -14 - (i - 1) * 38)
		tab.bg = tex(tab, "BACKGROUND", { 0, 0, 0, 0 })
		tab.bg:SetAllPoints()
		tab.bar = tex(tab, "ARTWORK", C.accent)
		tab.bar:SetPoint("TOPLEFT")
		tab.bar:SetPoint("BOTTOMLEFT")
		tab.bar:SetWidth(3)
		tab.label = text(tab, "GameFontHighlight", C.dim)
		tab.label:SetPoint("LEFT", 22, 0)
		tab.label:SetText(def.label)
		tab:SetScript("OnClick", function() O:SelectPage(i) end)
		tab:SetScript("OnEnter", function(self) if O.pageIndex ~= i then self.label:SetTextColor(unpack(C.text)) end end)
		tab:SetScript("OnLeave", function(self) if O.pageIndex ~= i then self.label:SetTextColor(unpack(C.dim)) end end)
		self.tabs[i] = tab

		local page = CreateFrame("Frame", nil, f)
		page:SetPoint("TOPLEFT", side, "TOPRIGHT", PAGE_PAD, -18)
		page:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAGE_PAD, 36)
		page:Hide()
		local y = 0
		local heading = text(page, "GameFontNormalLarge", C.text)
		heading:SetPoint("TOPLEFT", 14, 0)
		heading:SetText(def.label)
		y = y + 24
		if def.intro then
			local intro = text(page, "GameFontHighlightSmall", C.muted)
			intro:SetPoint("TOPLEFT", 14, -y)
			intro:SetPoint("RIGHT", page, "RIGHT", -14, 0)
			intro:SetText(def.intro)
			y = y + 26
		end
		y = y + 6
		page.rows = {}
		for _, rowDef in ipairs(def.rows) do
			local row, h = makeRow(page, rowDef, y)
			page.rows[#page.rows + 1] = row
			y = y + h
		end
		self.pages[i] = page
	end

	-- Controller.
	f:EnableGamePadButton(true)
	f:SetScript("OnGamePadButtonDown", function(_, button) O:OnPadButton(button) end)
	-- Escape closes; every other key goes on to the game.
	f:EnableKeyboard(true)
	-- Mouse buttons 3-5 can be the talk key too.
	f:SetScript("OnMouseDown", function(_, mouse) if O.capture then O:CaptureKey(mouse) end end)
	-- Give up on a remap nobody answered.
	f:SetScript("OnUpdate", function()
		if O.capture and GetTime() > O.captureUntil then O:StopCapture() end
	end)
	f:SetScript("OnKeyDown", function(self, key)
		if O.capture and O:CaptureKey(key) then
			if not InCombatLockdown() then self:SetPropagateKeyboardInput(false) end
		elseif key == "ESCAPE" then
			if not InCombatLockdown() then self:SetPropagateKeyboardInput(false) end
			if O.capture then O:StopCapture() else O:Hide() end
		elseif not InCombatLockdown() then
			self:SetPropagateKeyboardInput(true)
		end
	end)

	self:SelectPage(1)
end

function O:SelectPage(i)
	self:StopCapture()
	self.pageIndex = i
	for j, page in ipairs(self.pages) do
		local on = j == i
		page:SetShown(on)
		local tab = self.tabs[j]
		tab.bar:SetShown(on)
		tab.bg:SetColorTexture(unpack(on and C.focus or { 0, 0, 0, 0 }))
		tab.label:SetTextColor(unpack(on and C.accent or C.dim))
	end
	self:SetFocus(nil)
	self:Refresh()
end

-- Highlight one row for the controller (nil: none).
function O:SetFocus(row)
	if self.focus then
		self.focus.bg:SetColorTexture(0, 0, 0, 0)
		self.focus.bar:Hide()
	end
	self.focus = row
	if row then
		row.bg:SetColorTexture(unpack(C.focus))
		row.bar:Show()
	end
end

function O:MoveFocus(dir)
	local rows = {}
	for _, row in ipairs(self.pages[self.pageIndex].rows) do
		if row.control then rows[#rows + 1] = row end
	end
	if #rows == 0 then return end
	local at = 0
	for i, row in ipairs(rows) do
		if row == self.focus then at = i end
	end
	if at == 0 then
		at = dir > 0 and 1 or #rows
	else
		at = math.min(#rows, math.max(1, at + dir))
	end
	self:SetFocus(rows[at])
end

-- Remapping: the next controller button pressed takes the action.
local CAPTURE_SECONDS = 6

function O:StartCapture(control, def)
	self.capture, self.captureDef = control, def
	self.captureUntil = GetTime() + CAPTURE_SECONDS
	control:Refresh()
end

function O:StopCapture()
	local control = self.capture
	self.capture, self.captureDef = nil, nil
	if control then control:Refresh() end
end

local function talkNote()
	ns:Print("talk " .. "setting saved. Type /reload so the Comunimate app picks it up.")
end

-- A controller button was pressed while remapping.
function O:FinishCapture(button)
	local def = self.captureDef
	if def.kind == "talk" and def.device ~= "pad" then return end  -- waiting for a key
	self:StopCapture()
	if def.kind == "talk" then
		ns.db.talkButton = button
		ns.AssignButton("VOICE", button)  -- the keyboard shows "listening" on that button too
		ns:ApplySettings("bindings")
		talkNote()
	elseif ns.AssignButton(def.action, button) then
		ns:ApplySettings("bindings")
	else
		ns:Print(ns.ButtonLabel(button) .. " can't be used for that.")
	end
	self:Refresh()
end

-- A keyboard key or mouse button was pressed while picking the talk key.
-- Returns true if it was taken.
function O:CaptureKey(key)
	local def = self.captureDef
	if not (def and def.kind == "talk" and def.device == "key") then return false end
	if key == "ESCAPE" then self:StopCapture() return true end
	if key == "BACKSPACE" or key == "DELETE" then
		ns.db.talkKey = nil
	elseif key == "LeftButton" or key == "RightButton" then
		return true  -- the mouse click that started picking
	else
		ns.db.talkKey = ({ MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" })[key] or key
	end
	self:StopCapture()
	self:Refresh()
	talkNote()
	return true
end

function O:OnPadButton(button)
	if self.capture then
		self:FinishCapture(button)
		return
	end
	local action = ({
		PADDUP = "up", PADDDOWN = "down", PADDLEFT = "left", PADDRIGHT = "right",
		PAD1 = "press", PAD2 = "close", PADLSHOULDER = "prev", PADRSHOULDER = "next",
	})[button]
	if action == "up" then self:MoveFocus(-1)
	elseif action == "down" then self:MoveFocus(1)
	elseif action == "prev" then self:SelectPage((self.pageIndex - 2) % #self.pages + 1)
	elseif action == "next" then self:SelectPage(self.pageIndex % #self.pages + 1)
	elseif action == "close" then self:Hide()
	elseif self.focus and self.focus.control then
		local c = self.focus.control
		if action == "left" then c:Nudge(-1)
		elseif action == "right" then c:Nudge(1)
		elseif action == "press" then c:Activate() end
	end
end

function O:Refresh()
	if not self.frame then return end
	for _, page in ipairs(self.pages) do
		for _, row in ipairs(page.rows) do
			if row.control then row.control:Refresh() end
			if row.preview then row.preview:Refresh() end
		end
	end
	local L = ns.ButtonIcon
	self.hint:SetText(L("PADDUP", 16) .. L("PADDDOWN", 16) .. " pick   " .. L("PADDLEFT", 16) .. L("PADDRIGHT", 16)
		.. " change   " .. L("PADLSHOULDER", 16) .. L("PADRSHOULDER", 16) .. " page   " .. L("PAD2", 16) .. " close")
end

function O:Show()
	self:Build()
	self.frame:Show()
	self:Refresh()
end

function O:Hide()
	self:StopCapture()
	if self.frame then self.frame:Hide() end
end

function O:Toggle()
	if self.frame and self.frame:IsShown() then self:Hide() else self:Show() end
end

-- Entry in the game's own Options > AddOns list.
function O:RegisterBlizzard()
	if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
	local panel = CreateFrame("Frame")
	local title = text(panel, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Comunimate")
	local note = text(panel, "GameFontHighlight")
	note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	note:SetText("Comunimate has its own settings window.")
	local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	open:SetSize(200, 26)
	open:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -14)
	open:SetText("Open Comunimate settings")
	open:SetScript("OnClick", function() O:Show() end)
	pcall(function()
		local category = Settings.RegisterCanvasLayoutCategory(panel, "Comunimate")
		Settings.RegisterAddOnCategory(category)
	end)
end
