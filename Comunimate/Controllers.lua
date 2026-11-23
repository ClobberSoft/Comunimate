-- Controller profiles and button -> action bindings.
--
-- WoW reports every controller with the same button names (PAD1, PADLTRIGGER, ...).
-- A profile only changes what we *call* each button on screen, so the same
-- bindings work for PlayStation, Xbox and Steam controllers.

local _, ns = ...

local function c(hex, text) return "|cff" .. hex .. text .. "|r" end

ns.ControllerOrder = { "PLAYSTATION", "XBOX", "STEAM" }

ns.Controllers = {
	PLAYSTATION = {
		name = "PlayStation",
		iconFolder = "ps",
		icons = {
			PAD1 = "cross", PAD2 = "circle", PAD3 = "square", PAD4 = "triangle",
			PADLSHOULDER = "l1", PADRSHOULDER = "r1", PADLTRIGGER = "l2", PADRTRIGGER = "r2",
			PADLSTICK = "l3", PADRSTICK = "r3", LSTICK = "lstick", RSTICK = "rstick",
			PADDUP = "dpad_up", PADDDOWN = "dpad_down", PADDLEFT = "dpad_left", PADDRIGHT = "dpad_right",
			PADFORWARD = "options", PADBACK = "create", PADSOCIAL = "mic", PAD5 = "mic",
		},
		labels = {
			PAD1 = c("7fa8ff", "Cross"),
			PAD2 = c("ff6b6b", "Circle"),
			PAD3 = c("ff8fd8", "Square"),
			PAD4 = c("5fe08f", "Triangle"),
			PADLSHOULDER = "L1", PADRSHOULDER = "R1",
			PADLTRIGGER = "L2", PADRTRIGGER = "R2",
			PADLSTICK = "L3", PADRSTICK = "R3",
			PADDUP = "D-Up", PADDDOWN = "D-Down", PADDLEFT = "D-Left", PADDRIGHT = "D-Right",
			PADFORWARD = "Options", PADBACK = "Create",
			PADSYSTEM = "PS", PADSOCIAL = "Mic", PAD5 = "Mic",
		},
	},
	XBOX = {
		name = "Xbox",
		iconFolder = "xbox",
		icons = {
			PAD1 = "a", PAD2 = "b", PAD3 = "x", PAD4 = "y",
			PADLSHOULDER = "lb", PADRSHOULDER = "rb", PADLTRIGGER = "lt", PADRTRIGGER = "rt",
			PADLSTICK = "ls", PADRSTICK = "rs", LSTICK = "lstick", RSTICK = "rstick",
			PADDUP = "dpad_up", PADDDOWN = "dpad_down", PADDLEFT = "dpad_left", PADDRIGHT = "dpad_right",
			PADFORWARD = "menu", PADBACK = "view", PADSOCIAL = "share", PAD5 = "share",
		},
		labels = {
			PAD1 = c("5fe08f", "A"),
			PAD2 = c("ff6b6b", "B"),
			PAD3 = c("7fa8ff", "X"),
			PAD4 = c("ffd75f", "Y"),
			PADLSHOULDER = "LB", PADRSHOULDER = "RB",
			PADLTRIGGER = "LT", PADRTRIGGER = "RT",
			PADLSTICK = "LS", PADRSTICK = "RS",
			PADDUP = "D-Up", PADDDOWN = "D-Down", PADDLEFT = "D-Left", PADDRIGHT = "D-Right",
			PADFORWARD = "Menu", PADBACK = "View",
			PADSYSTEM = "Xbox", PADSOCIAL = "Share",
		},
	},
	STEAM = {
		name = "Steam",
		iconFolder = "steam",
		icons = {
			PAD1 = "a", PAD2 = "b", PAD3 = "x", PAD4 = "y",
			PADLSHOULDER = "l1", PADRSHOULDER = "r1", PADLTRIGGER = "l2", PADRTRIGGER = "r2",
			PADLSTICK = "l3", PADRSTICK = "r3", LSTICK = "lstick", RSTICK = "rstick",
			PADDUP = "dpad_up", PADDDOWN = "dpad_down", PADDLEFT = "dpad_left", PADDRIGHT = "dpad_right",
			PADFORWARD = "menu", PADBACK = "view", PADSOCIAL = "dots",
			PADPADDLE1 = "l4", PADPADDLE2 = "r4", PADPADDLE3 = "l5", PADPADDLE4 = "r5",
		},
		labels = {
			PAD1 = c("5fe08f", "A"),
			PAD2 = c("ff6b6b", "B"),
			PAD3 = c("7fa8ff", "X"),
			PAD4 = c("ffd75f", "Y"),
			PADLSHOULDER = "L1", PADRSHOULDER = "R1",
			PADLTRIGGER = "L2", PADRTRIGGER = "R2",
			PADLSTICK = "L3", PADRSTICK = "R3",
			PADDUP = "D-Up", PADDDOWN = "D-Down", PADDLEFT = "D-Left", PADDRIGHT = "D-Right",
			PADFORWARD = "Menu", PADBACK = "View",
			PADSYSTEM = "Steam", PADSOCIAL = "...",
			PADPADDLE1 = "L4", PADPADDLE2 = "R4", PADPADDLE3 = "L5", PADPADDLE4 = "R5",
		},
	},
}

-- Default button -> action map (WoW button names).
ns.DefaultBindings = {
	PADLTRIGGER  = "TYPE_LEFT",
	PADRTRIGGER  = "TYPE_RIGHT",
	PADLSHOULDER = "SHIFT",
	PADRSHOULDER = "SYMBOLS",
	PAD1         = "SPACE",
	PAD3         = "BACKSPACE",
	PAD4         = "ACCEPT",
	PAD2         = "CLOSE",
	PADDLEFT     = "PREV_SUGGESTION",
	PADDRIGHT    = "NEXT_SUGGESTION",
	PADDUP       = "CAPSLOCK",
	PADDDOWN     = "CHANNEL",
	PADFORWARD   = "SEND",
	PADBACK      = "CLEAR",
	PAD5         = "VOICE",  -- PS5 mic button as WoW reports it: hold to talk (needs ComunimateVoice running)
	PADSOCIAL    = "VOICE",  -- same idea on controllers that report a Share button
}

-- Short descriptions used to build the on-screen button legend.
ns.ActionLabels = {
	TYPE_LEFT = "Type left", TYPE_RIGHT = "Type right",
	SHIFT = "Shift", SYMBOLS = "123", SPACE = "Space", BACKSPACE = "Delete",
	ACCEPT = "Use word", CLOSE = "Close", PREV_SUGGESTION = "Prev word",
	NEXT_SUGGESTION = "Next word", CAPSLOCK = "Caps", CHANNEL = "Channel",
	SEND = "Send", CLEAR = "Clear", VOICE = "Hold: talk",
}

local ICON_PATH = "Interface\\AddOns\\Comunimate\\Media\\Icons\\"

-- Inline texture markup for a button (or LSTICK / RSTICK), falling back to its name.
function ns.ButtonIcon(button, size)
	size = size or 18
	local ctrl = ns.GetController()
	local file = ctrl.icons and ctrl.icons[button]
	if not file then return ns.ButtonLabel(button) end
	return ("|T%s%s\\%s:%d:%d|t"):format(ICON_PATH, ctrl.iconFolder, file, size, size)
end

function ns.IconPath(name)
	return ICON_PATH .. ns.GetController().iconFolder .. "\\" .. name
end

function ns.GetAction(button)
	local overrides = ns.db and ns.db.bindings
	if overrides and overrides[button] ~= nil then
		return overrides[button] or nil  -- false = unbound
	end
	return ns.DefaultBindings[button]
end

function ns.GetController()
	return ns.Controllers[ns.db and ns.db.controller] or ns.Controllers.PLAYSTATION
end

function ns.ButtonLabel(button)
	return ns.GetController().labels[button] or button
end

-- First button bound to an action, as an icon (or its name if there's no icon).
function ns.ActionButtonIcon(action, size)
	local button = ns.ActionButton(action)
	return button and ns.ButtonIcon(button, size) or "?"
end

function ns.ActionButtonLabel(action)
	local button = ns.ActionButton(action)
	return button and ns.ButtonLabel(button) or "?"
end

-- The button currently doing an action (your own mapping first), or nil.
function ns.ActionButton(action)
	if ns.db then
		for button, act in pairs(ns.db.bindings) do
			if act == action then return button end
		end
	end
	for button in pairs(ns.DefaultBindings) do
		if ns.GetAction(button) == action then return button end
	end
end

-- Buttons that can't be remapped: the sticks steer, and the menu/system
-- buttons belong to the game.
ns.UNBINDABLE = { PADSYSTEM = true }

-- Put an action on a button. Whatever that button did before moves to the
-- action's old button (a swap), so nothing is ever left without a button.
function ns.AssignButton(action, button)
	if ns.UNBINDABLE[button] then return false end
	local b = ns.db.bindings
	local oldButton = ns.ActionButton(action)
	local displaced = ns.GetAction(button)
	if oldButton == button then return true end
	b[button] = action
	if oldButton then
		b[oldButton] = displaced or false
	end
	return true
end

function ns.ResetButtons()
	wipe(ns.db.bindings)
end
