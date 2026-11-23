-- Sending chat messages.
--
-- Uses the chat API directly from a button press. It deliberately never opens,
-- fills or "presses Enter" on Blizzard's own chat box: doing that from an add-on
-- taints the chat box and WoW then shows "has been blocked from an action only
-- available to the Blizzard UI".

local _, ns = ...
local Chat = {}
ns.Chat = Chat

-- Channel picker (D-pad down). "Auto" picks Instance / Raid / Party / Say.
local CHANNELS = {
	{ label = "Auto" },
	{ label = "Party",    chatType = "PARTY",         color = "aaaaff" },
	{ label = "Raid",     chatType = "RAID",          color = "ff7f00" },
	{ label = "Instance", chatType = "INSTANCE_CHAT", color = "ff7f00" },
	{ label = "Guild",    chatType = "GUILD",         color = "40ff40" },
	{ label = "Say",      chatType = "SAY",           color = "ffffff" },
	{ label = "Yell",     chatType = "YELL",          color = "ff4040" },
	{ label = "General",  chatType = "CHANNEL", channel = "General", default = 1, color = "ffc0c0" },
	{ label = "Trade",    chatType = "CHANNEL", channel = "Trade",   default = 2, color = "ffc0c0" },
	{ label = "Reply",    chatType = "WHISPER", reply = true,        color = "ff80ff" },
}

-- Who whispered you last (for Reply and /r). Our own record, so we never
-- need to read Blizzard's chat box state.
local whispers = CreateFrame("Frame")
whispers:RegisterEvent("CHAT_MSG_WHISPER")
whispers:SetScript("OnEvent", function(_, _, _, sender)
	-- During chat lockdown WoW can hide names from add-ons ("secret" values).
	if issecretvalue and issecretvalue(sender) then return end
	if type(sender) == "string" and sender ~= "" then
		local ok = pcall(function() Chat.lastTell = sender:gsub("%-" .. (GetNormalizedRealmName() or "") .. "$", "") end)
		if not ok then Chat.lastTell = sender end
	end
end)

function Chat:ReplyTarget()
	if self.lastTell then return self.lastTell end
	local t = ChatEdit_GetLastTellTarget and ChatEdit_GetLastTellTarget()
	if t and t ~= "" then return t end
end

-- The number of a joined chat channel ("General - Elwynn Forest" -> 1).
function Chat:ChannelNumber(name, default)
	if GetChannelList then
		local list = { GetChannelList() }
		for i = 1, #list, 3 do
			local id, cname = list[i], list[i + 1]
			if type(cname) == "string" and cname:find("^" .. name) then return id end
		end
	end
	return default
end

local TYPE_COLORS = {
	PARTY = "aaaaff", RAID = "ff7f00", INSTANCE_CHAT = "ff7f00", GUILD = "40ff40",
	SAY = "ffffff", YELL = "ff4040", WHISPER = "ff80ff",
}
local TYPE_NAMES = {
	PARTY = "Party", RAID = "Raid", INSTANCE_CHAT = "Instance", GUILD = "Guild",
	SAY = "Say", YELL = "Yell",
}

-- Slash prefixes you can type (or say) at the start of a message.
local SLASH = {
	s = "SAY", say = "SAY",
	p = "PARTY", party = "PARTY",
	ra = "RAID", raid = "RAID",
	rw = "RAID_WARNING",
	i = "INSTANCE_CHAT", instance = "INSTANCE_CHAT", bg = "INSTANCE_CHAT",
	g = "GUILD", guild = "GUILD",
	o = "OFFICER", officer = "OFFICER",
	y = "YELL", yell = "YELL", sh = "YELL", shout = "YELL",
	e = "EMOTE", em = "EMOTE", me = "EMOTE", emote = "EMOTE",
}
local WHISPER = { w = true, whisper = true, t = true, tell = true, send = true }
local REPLY = { r = true, reply = true }

function Chat:NumChannels() return #CHANNELS end

-- -> chatType, target (target: a channel number for General / Trade)
function Chat:ChannelAt(index)
	local ch = CHANNELS[index] or CHANNELS[1]
	if ch.chatType == "CHANNEL" then
		return "CHANNEL", self:ChannelNumber(ch.channel, ch.default)
	elseif ch.reply then
		return "WHISPER", self:ReplyTarget() or false
	end
	return ch.chatType
end

-- Where "Auto" sends right now.
function Chat:AutoType()
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
	if IsInRaid() then return "RAID" end
	if IsInGroup() then return "PARTY" end
	return "SAY"
end

function Chat:ChannelLabel(index)
	local ch = CHANNELS[index] or CHANNELS[1]
	if ch.reply then
		local who = self:ReplyTarget()
		return "|cff" .. ch.color .. "Reply" .. (who and (": " .. who) or " (nobody yet)") .. "|r"
	end
	if ch.chatType then
		return "|cff" .. ch.color .. ch.label .. "|r"
	end
	local auto = self:AutoType()
	return "Auto: |cff" .. TYPE_COLORS[auto] .. TYPE_NAMES[auto] .. "|r"
end

-- "/p hi" -> "hi", "PARTY". Returns msg, chatType, target  or nil, error.
function Chat:Parse(text, chatType, target)
	local cmd, rest = text:match("^/(%S+)%s*(.*)$")
	if not cmd then
		if chatType == "WHISPER" and not target then return nil, "Nobody has whispered you yet, so there's no one to reply to." end
		if chatType then return text, chatType, target end
		return text, self:AutoType()
	end
	cmd = cmd:lower()
	if cmd == "general" or cmd == "gen" then
		return rest, "CHANNEL", self:ChannelNumber("General", 1)
	elseif cmd == "trade" then
		return rest, "CHANNEL", self:ChannelNumber("Trade", 2)
	elseif SLASH[cmd] then
		return rest, SLASH[cmd]
	elseif WHISPER[cmd] then
		local name, msg = rest:match("^(%S+)%s+(.+)$")
		if not name then return nil, "Whisper like this: /w Name message" end
		return msg, "WHISPER", name
	elseif REPLY[cmd] then
		local target = self:ReplyTarget()
		if not target then return nil, "Nobody has whispered you yet, so there's no one to reply to." end
		return rest, "WHISPER", target
	elseif tonumber(cmd) then
		return rest, "CHANNEL", tonumber(cmd)
	end
	return nil, "Only chat commands like /p /ra /g /s /1 /w work from the controller keyboard."
end

local MACRO_PREFIX = {
	SAY = "/s ", YELL = "/y ", PARTY = "/p ", RAID = "/ra ", RAID_WARNING = "/rw ",
	INSTANCE_CHAT = "/i ", GUILD = "/g ", OFFICER = "/o ", EMOTE = "/e ",
}

-- The same message as a macro line ("/s hello"), for sending through a
-- player-pressed secure button. Returns macro or nil, error.
function Chat:MacroFor(text, chatType, channelTarget)
	local msg, kind, target = self:Parse(text, chatType, channelTarget)
	if not msg then return nil, kind end
	if not msg:find("%S") then return nil, "Nothing to send." end
	local prefix
	if kind == "WHISPER" then
		prefix = "/w " .. target .. " "
	elseif kind == "CHANNEL" then
		prefix = "/" .. target .. " "
	else
		prefix = MACRO_PREFIX[kind]
	end
	if not prefix then return nil, "Can't send to " .. tostring(kind) .. "." end
	return (prefix .. msg):sub(1, 255)
end

local function inLockdown()
	local f = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
	if not f then return false end
	local ok, locked = pcall(f)
	return ok and locked
end

-- Send a message. Returns true, or false + a message for the player.
function Chat:Send(text, chatType, channelTarget)
	local msg, kind, target = self:Parse(text, chatType, channelTarget)
	if not msg then return false, kind end
	if not msg:find("%S") then return false, "Nothing to send." end

	if inLockdown() then
		return false, "WoW blocks add-on chat during boss fights and Mythic+. Your message is kept; send it after the fight."
	end
	if (kind == "SAY" or kind == "YELL") and not IsInInstance() then
		return false, "Outdoors, WoW only lets add-ons use Party, Raid, Guild or whispers, not Say/Yell. Change channel with "
			.. ns.ActionButtonIcon("CHANNEL", 14) .. "."
	end

	local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
	local ok, err = pcall(send, msg, kind, nil, target)
	if not ok then return false, "Couldn't send: " .. tostring(err) end
	return true
end
