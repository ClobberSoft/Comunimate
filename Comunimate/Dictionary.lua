-- Built-in word lists for suggestions.
-- Words are listed most-common first; earlier words score higher.
-- Words with capitals (LFM, Ragnaros, I'm) keep their capitals when suggested.

local _, ns = ...
ns.Dictionary = {}

-- WoW chat shorthand and group talk. Highest priority after the very common words.
ns.Dictionary.wowChat = [[
inc ty thx np gg gz grats brb afk omw lol ok kk rdy ready pull pulling wait
LFM LFG LF1M LF2M LF3M LF4M WTS WTB WTT PST tank heals healer dps need
summon summ port portal invite inv pls plz sry wb oom mana drink drinking
rez res buff buffs wipe wiped adds trash boss loot roll greed pass ninja
aggro threat taunt kite cc sheep sap trap fear kick interrupt stun dispel
decurse cleanse hp pots potion flask elixir repair vendor bank ah mail
hearth hs flight fp gold silver copper gear item drop drops quest quests
xp exp level lvl ding grind farm farming mob mobs elite rare spawn respawn
corpse ghost run runs group party raid guild dungeon instance gogo go
mount bags bag bandage food water heal healing tanking dpsing focus target
skull cross moon star square triangle diamond circle marked mark
lag dc reloading reload ui addon gratz welcome hi hey hello bye cya gn
anyone LF help helping trade whisper wsp msg
]]

-- Names: classes, races, places, dungeons, raids, bosses, professions, stats.
ns.Dictionary.wowNames = [[
Warrior Paladin Hunter Rogue Priest Shaman Mage Warlock Druid
warrior paladin hunter rogue priest shaman mage warlock druid lock pally
Human Dwarf Gnome Orc Troll Tauren Undead Forsaken Night Elf
Alliance Horde
Stormwind Ironforge Darnassus Orgrimmar Undercity Thunder Bluff
Booty Bay Gadgetzan Ratchet Everlook Crossroads Southshore Tarren Mill
Goldshire Elwynn Westfall Duskwood Redridge Stranglethorn STV Barrens
Ashenvale Tanaris Feralas Felwood Winterspring Silithus EPL WPL Hinterlands
Searing Gorge Burning Steppes Badlands Arathi Hillsbrad Alterac Darkshore
Durotar Mulgore Teldrassil Tirisfal Silverpine Loch Modan Wetlands Desolace
Dustwallow Azshara Ungoro Moonglade Stonetalon Needles Swamp Blasted Lands
Ragefire RFC Wailing Caverns WC Deadmines VC Shadowfang SFK Stockade Stocks
Blackfathom BFD Gnomeregan Gnomer Razorfen RFK RFD Scarlet Monastery SM
Graveyard Library Armory Cathedral Uldaman Ulda Zul'Farrak ZF Maraudon Mara
Sunken Temple ST Blackrock Depths BRD LBRS UBRS Dire Maul DM Scholomance
Scholo Stratholme Strat Molten Core MC Onyxia Ony Blackwing Lair BWL
Zul'Gurub ZG AQ Naxxramas Naxx Ragnaros Nefarian VanCleef Hakkar Baron
Alchemy Blacksmithing Enchanting Engineering Herbalism Mining Skinning
Tailoring Leatherworking Cooking Fishing First Aid
Strength Agility Stamina Intellect Spirit crit hit armor resist
]]

-- Common English words, most frequent first.
ns.Dictionary.common = [[
the I you to a and is it that of in for on my me we have be do this are not
with what so can just was your if at all get no yes yeah up out but like
know go he they she one will there about how now right here good time when
think im I'm don't it's can't won't i'll I'll that's you're we're they're
let's what's there's didn't isn't doesn't wasn't I've ok okay sure thanks
thank please sorry need want come going got make take give see look back
then them his her our us from by or as an been has had were said did made
went really very much more many some any other new first last next well
way even still also only too again never always every something nothing
anything everyone someone anyone thing things who which would could should
may might must because before after over down off into than these those
day night today tomorrow tonight later soon long little big small old
great best better bad worse fine nice cool fun funny awesome easy hard
fast slow quick done close far near early late hot cold free full real
help where why find found keep put run try trying tried call ask feel
leave turn start started show hear play playing played move moving stay
hold bring happen write sit stand lose lost pay meet learn change lead
understand watch follow create speak read add spend grow open walk win
buy sell kill die dead alive remember love hate wanna gonna gotta
lets yep nope maybe probably almost already enough left last mine yours
two three four five ten hundred minute minutes hour hours sec second
people guy guys friend friends man dude bro team
]]

-- Shown when no letters have been typed yet and nothing is learned.
ns.Dictionary.starters = { "LFM", "inc", "ty", "ready", "brb", "omw", "yes", "no" }
