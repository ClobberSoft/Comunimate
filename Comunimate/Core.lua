-- Comunimate: controller keyboard for World of Warcraft chat.
-- Core: saved settings, startup, slash commands, key binding.

local ADDON, ns = ...
ns.name = ADDON
Comunimate = ns

BINDING_HEADER_COMUNIMATE = "Comunimate"
BINDING_NAME_COMUNIMATE_TOGGLE = "Open / close controller keyboard"

-- Every setting lives here so a settings panel can be added later
-- without touching the rest of the code.
ns.defaults = {
	controller = "PLAYSTATION",  -- PLAYSTATION | XBOX | STEAM (button labels)
	voiceOpensKeyboard = true,   -- holding the mic button opens chat + keyboard
	talkButton = "PAD5",         -- controller button to hold to talk (PAD5 = PS5 mic button)
	talkKey = nil,               -- keyboard key / mouse button to hold to talk (e.g. "F9", "BUTTON4")
	voiceShowsKeyboard = false,  -- false: talking opens a small "listening" box instead of the keyboard
	takeOverChatCombo = true,    -- the controller's open-chat combo opens our keyboard instead
	voiceStartKey = "CTRL-SHIFT-F10", -- sent by ComunimateVoice on mic press (must match its config.json)
	voiceStopKey = "CTRL-SHIFT-F11",  -- sent on mic release
	scale = 1.0,
	kbAlpha = 0.95,              -- keyboard background opacity
	showBadge = true,            -- the mascot badge on screen
	mascotRace = "auto",         -- "auto" = your character's race, or orc / troll / human ...
	mascotStyle = "cute",        -- cute | epic | anime
	mascotGender = "auto",       -- "auto" = your character's, or male / female
	badgeFrame = true,           -- gold ring around the mascot
	badgeSize = 56,
	badgeMovable = false,        -- the orc is click-through unless this is on
	badgePosition = nil,
	cursorMode = "spring",       -- "spring": steer a ring, it returns to the middle on release;
	                             -- "free": the ring stays put; "snap": stick points at a key
	cursorSpeed = 520,           -- ring speed at full push, pixels per second
	invertY = false,           -- flip stick up/down if rows feel upside down
	colInner = 0.20,             -- stick X needed to move one column from center
	colOuter = 0.60,             -- stick X needed to reach the outer column
	rowThreshold = 0.45,         -- stick Y needed to reach the top/bottom row
	channel = 1,                 -- index into the channel list (1 = current chat box channel)
	closeAfterSend = true,
	learn = true,                -- learn words you send to improve suggestions
	debug = false,
	position = nil,
	bindings = {},               -- per-button overrides of ns.DefaultBindings
}

local function copyDefaults(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then
			if type(v) == "table" then
				dst[k] = {}
				copyDefaults(dst[k], v)
			else
				dst[k] = v
			end
		end
	end
end

function ns:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffComunimate|r: " .. tostring(msg))
end

-- Apply a changed setting everywhere it shows (settings window, slash commands).
function ns:ApplySettings(key)
	if key == "voiceOpensKeyboard" or key == "takeOverChatCombo" or key == "debug" or key == "bindings" then
		ns.Keyboard:SetupVoiceKeys()
	end
	if key == "learn" then ns.Suggest:Init() end
	ns.Keyboard:ApplyLayout()
	ns.Keyboard:RefreshAll()
	ns.Badge:ApplyLayout()
	if ns.Options.frame and ns.Options.frame:IsShown() then ns.Options:Refresh() end
end

-- True when the game has gamepad support on and a controller connected.
function ns.IsGamePadActive()
	if not C_GamePad then return false end
	local ok, enabled = pcall(function()
		if C_GamePad.IsEnabled and not C_GamePad.IsEnabled() then return false end
		if C_GamePad.GetActiveDeviceID then
			return C_GamePad.GetActiveDeviceID() ~= nil
		end
		return true
	end)
	return ok and enabled or false
end

BINDING_NAME_COMUNIMATE_VOICE_START = "Voice: start listening (used by Comunimate Voice)"
BINDING_NAME_COMUNIMATE_VOICE_STOP = "Voice: stop listening (used by Comunimate Voice)"

function Comunimate_Toggle()
	if ns.Keyboard then ns.Keyboard:Toggle() end
end

BINDING_NAME_COMUNIMATE_TALK = "Hold to talk (your talk button)"

-- Your talk button while nothing is open: claimed by Comunimate so the game
-- doesn't also do its own thing with it (in Forever the mic button opens bags).
function Comunimate_Talk(keystate)
	if not ns.Keyboard then return end
	if ns.db and ns.db.debug then ns:Print("talk button " .. tostring(keystate)) end
	if ns.db.voiceOpensKeyboard then
		ns.Keyboard:OnVoiceButton(keystate == "down", "pad")
	end
end

function Comunimate_VoiceStart()
	if ns.db and ns.db.debug then ns:Print("voice start key received") end
	if ns.Keyboard then ns.Keyboard:OnVoiceButton(true, "app") end
end

function Comunimate_VoiceStop()
	if ns.Keyboard then ns.Keyboard:OnVoiceButton(false, "app") end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON then
		ComunimateDB = ComunimateDB or {}
		copyDefaults(ComunimateDB, ns.defaults)
		ns.db = ComunimateDB
		-- 0.6: Spring became the default ring style (0.5 saved "free" for everyone).
		if not ns.db.migrated06 then
			ns.db.migrated06 = true
			ns.db.cursorMode = "spring"
		end
		-- 0.10: talking opens the small box by default (0.9 saved "keyboard" for everyone).
		if not ns.db.migrated10 then
			ns.db.migrated10 = true
			ns.db.voiceShowsKeyboard = false
		end

		ComunimateLearned = ComunimateLearned or {}
		ComunimateLearned.words = ComunimateLearned.words or {}
		ComunimateLearned.bigrams = ComunimateLearned.bigrams or {}
		ns.learned = ComunimateLearned
	elseif event == "PLAYER_LOGIN" then
		ns.Suggest:Init()
		ns.Keyboard:Build()
		ns.Badge:Build()
		ns.Options:RegisterBlizzard()
		ns:Print("loaded. Tap the mic button to open the keyboard, hold it to talk. /cm options for settings.")
	end
end)

----------------------------------------------------------------------
-- Slash commands (temporary home for settings until the panel exists)
----------------------------------------------------------------------

local CONTROLLER_ALIASES = {
	ps = "PLAYSTATION", ps5 = "PLAYSTATION", playstation = "PLAYSTATION", dualsense = "PLAYSTATION",
	xbox = "XBOX", xb = "XBOX",
	steam = "STEAM", deck = "STEAM", steamdeck = "STEAM",
}

local function onOff(rest, current)
	rest = (rest or ""):lower()
	if rest == "on" then return true end
	if rest == "off" then return false end
	return not current
end

local function help()
	ns:Print("commands:")
	print("  /cm  - open or close the keyboard")
	print("  /cm options  - settings window")
	print("  /cm controller ps | xbox | steam  - button labels")
	print("  /cm voice on|off  - holding the mic button opens chat and the keyboard")
	print("  /cm scale 0.5-2  - keyboard size")
	print("  /cm invert  - flip stick up/down")
	print("  /cm reset  - move keyboard back to the default spot")
	print("  /cm forget  - erase learned words")
	print("  /cm debug  - show button names and stick values")
end

SLASH_COMUNIMATE1 = "/cm"
SLASH_COMUNIMATE2 = "/comunimate"
SlashCmdList.COMUNIMATE = function(msg)
	local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()
	local db = ns.db

	if cmd == "" then
		ns.Keyboard:Toggle()
	elseif cmd == "options" or cmd == "settings" or cmd == "config" or cmd == "o" then
		ns.Options:Toggle()
	elseif cmd == "controller" or cmd == "pad" then
		local key = CONTROLLER_ALIASES[(rest or ""):lower()]
		if key then
			db.controller = key
			ns.Keyboard:RefreshAll()
			ns:Print("controller set to " .. ns.Controllers[key].name)
		else
			ns:Print("use: /cm controller ps | xbox | steam  (now: " .. ns.Controllers[db.controller].name .. ")")
		end
	elseif cmd == "voice" then
		db.voiceOpensKeyboard = onOff(rest, db.voiceOpensKeyboard)
		ns.Keyboard:SetupVoiceKeys()
		ns:Print("mic button opens chat: " .. (db.voiceOpensKeyboard and "on" or "off"))
	elseif cmd == "scale" then
		local n = tonumber(rest)
		if n and n >= 0.5 and n <= 2 then
			db.scale = n
			ns.Keyboard:ApplyLayout()
			ns:Print("scale " .. n)
		else
			ns:Print("use: /cm scale 0.5 - 2")
		end
	elseif cmd == "invert" then
		db.invertY = not db.invertY
		ns:Print("invert stick Y: " .. (db.invertY and "on" or "off"))
	elseif cmd == "reset" then
		db.position = nil
		ns.Keyboard:ApplyLayout()
		ns:Print("position reset")
	elseif cmd == "forget" then
		wipe(ns.learned.words)
		wipe(ns.learned.bigrams)
		ns.Suggest:Init()
		ns:Print("learned words erased")
	elseif cmd == "debug" then
		db.debug = not db.debug
		ns:Print("debug: " .. (db.debug and "on" or "off"))
		if db.debug then
			ns:Print("C_GamePad: " .. tostring(C_GamePad ~= nil)
				.. ", gamepad active: " .. tostring(ns.IsGamePadActive())
				.. ", mapped state API: " .. tostring(C_GamePad and C_GamePad.GetDeviceMappedState ~= nil))
		end
		ns.Keyboard:RefreshAll()
	else
		help()
	end
end
