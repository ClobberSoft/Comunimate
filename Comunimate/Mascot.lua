-- The mascot: any playable race, male or female, in Cute, Epic or Anime style.
-- Portraits live in Media/Mascots/<race>_<gender>_<style>_<quiet|loud>.tga
-- (imported from art/ by tools/mascot_art.py).

local _, ns = ...
local M = {}
ns.Mascot = M

local PATH = "Interface\\AddOns\\Comunimate\\Media\\Mascots\\"

-- In picker order. side: Horde / Alliance / Both.
M.RACES = {
	{ key = "orc",      name = "Orc",       side = "Horde" },
	{ key = "troll",    name = "Troll",     side = "Horde" },
	{ key = "tauren",   name = "Tauren",    side = "Horde" },
	{ key = "undead",   name = "Undead",    side = "Horde" },
	{ key = "human",    name = "Human",     side = "Alliance" },
	{ key = "dwarf",    name = "Dwarf",     side = "Alliance" },
	{ key = "nightelf", name = "Night Elf", side = "Alliance" },
	{ key = "gnome",    name = "Gnome",     side = "Alliance" },
	{ key = "skyborne", name = "Skyborne",  side = "Both" },
}

M.STYLES = {
	{ key = "cute",  name = "Cute" },
	{ key = "epic",  name = "Epic" },
	{ key = "anime", name = "Anime" },
}

local SIDE_COLOR = { Horde = "ff5040", Alliance = "4f8fff", Both = "8fd4ff" }

-- The game's race names -> ours.
local FROM_GAME = {
	orc = "orc", troll = "troll", tauren = "tauren", scourge = "undead", undead = "undead",
	human = "human", dwarf = "dwarf", nightelf = "nightelf", gnome = "gnome", skyborne = "skyborne",
}

local valid = {}
for _, r in ipairs(M.RACES) do valid[r.key] = r end

-- The player's own race, or orc if it isn't one we've drawn.
function M:PlayerRace()
	local _, raceFile = UnitRace("player")
	local key = raceFile and FROM_GAME[raceFile:lower():gsub("[^%a]", "")]
	return key or "orc"
end

function M:Race()
	local r = ns.db.mascotRace
	if r == "auto" or not valid[r] then return self:PlayerRace() end
	return r
end

function M:Style()
	local s = ns.db.mascotStyle
	if s ~= "cute" and s ~= "epic" and s ~= "anime" then return "cute" end
	return s
end

-- The player's character: UnitSex 3 = female, otherwise male.
function M:PlayerGender()
	return UnitSex("player") == 3 and "female" or "male"
end

function M:Gender()
	local g = ns.db.mascotGender
	if g == "male" or g == "female" then return g end
	return self:PlayerGender()
end

-- Texture path for the current mascot (loud = talking).
function M:Path(loud, race, style, gender)
	return PATH .. (race or self:Race()) .. "_" .. (gender or self:Gender()) .. "_"
		.. (style or self:Style()) .. "_" .. (loud and "loud" or "quiet")
end

function M:GenderChoices()
	local mine = self:PlayerGender() == "female" and "Female" or "Male"
	return { { "auto", "Mine (" .. mine .. ")" }, { "male", "Male" }, { "female", "Female" } }
end

-- Choices for the settings window's race picker.
function M:RaceChoices()
	local mine = valid[self:PlayerRace()]
	local list = { { "auto", "My character (" .. (mine and mine.name or "Orc") .. ")" } }
	for _, r in ipairs(self.RACES) do
		list[#list + 1] = { r.key, "|cff" .. SIDE_COLOR[r.side] .. r.side .. "|r  " .. r.name }
	end
	return list
end

function M:StyleChoices()
	local list = {}
	for _, s in ipairs(self.STYLES) do list[#list + 1] = { s.key, s.name } end
	return list
end
