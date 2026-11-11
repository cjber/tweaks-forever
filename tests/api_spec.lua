local inits = {}
local active = {}
local handlers = {}
local ns = {
	Feature = function() end,
	Init = function(fn)
		inits[#inits + 1] = fn
	end,
	Active = function(key)
		return active[key] == true
	end,
	On = function(event, fn)
		handlers[event] = handlers[event] or {}
		table.insert(handlers[event], fn)
	end,
}
local NAMES = { [403] = "Lightning Bolt", [529] = "Lightning Bolt", [548] = "Lightning Bolt", [915] = "Lightning Bolt" }
local known, level, class, combat = { [403] = true, [529] = true }, 18, "SHAMAN", false
local tabName = "Elemental Combat"
-- A synthetic QuestieDB: made-up names and spawns for two of the Shaman trainers the data lists, on a made-up area 10
-- drawn on map 100.
local questieNpcs = {
	[3030] = { name = "First Teacher", spawns = { [10] = { { 25, 75 } } }, zoneID = 10 },
	[373] = { name = "Second Teacher" },
}
local questie = {
	RequireContract = function(required)
		return required == 2
	end,
	Npc = {
		GetAll = function(id, keys)
			local row, values = questieNpcs[id], {}
			for i, key in ipairs(row and keys or {}) do
				values[i] = row[key]
			end
			return row and values
		end,
	},
	Support = {
		Get = function()
			return {
				private = {
					areaIdToUiMapId = "return { [10] = 100 }",
					areaIdToUiMapIdOverride = "return {}",
					subZoneToParentZone = "return {}",
				},
			}
		end,
	},
}
local timers = {}
-- The client state the added reads see: a quest reward panel, a zone map with overlay art, the experience bar and a
-- rare's nameplate and marker.
local now, xp, maxXP = 1000, 0, 1000
local rewardItems, rewardOpen, hooks = {}, false, {}
local playerMap, mapTypes, mapArt, artLayers, mapLevels, exploredTextures = nil, {}, {}, {}, {}, {}
local rareUnits, vignettes, markerAt = {}, {}, {}
-- The click mode Bags/Junk.lua registers, its Toggle behind it.
local clickMode
local function Frame()
	local due = timers
	timers = {}
	for _, fn in ipairs(due) do
		fn()
	end
end
-- Fires every handler a loaded file registered for an event, as Core/Core.lua's frame does.
local function Fire(event, ...)
	for _, fn in ipairs(handlers[event] or {}) do
		fn(...)
	end
end
local env = setmetatable({
	C_AddOns = {
		GetAddOnMetadata = function()
			return "Forever"
		end,
	},
	C_Timer = {
		After = function(_, fn)
			timers[#timers + 1] = fn
		end,
	},
	debugprofilestop = function()
		return 0
	end,
	InCombatLockdown = function()
		return combat
	end,
	UnitClass = function()
		return "Shaman", class, 7
	end,
	UnitRace = function()
		return "Dwarf", "Dwarf", 3
	end,
	UnitLevel = function()
		return level
	end,
	C_Spell = {
		GetSpellInfo = function(id)
			return { name = NAMES[id] or tostring(id), iconID = id }
		end,
		GetSpellSubtext = function()
			return ""
		end,
	},
	C_SpellBook = {
		IsSpellKnown = function(id)
			return known[id] == true
		end,
		GetSkillLineIndexByID = function(lineID)
			return lineID == 375 and 2 or nil
		end,
		GetSpellBookSkillLineInfo = function(index)
			return index == 2 and { name = tabName } or nil
		end,
	},
	C_TradeSkillUI = {
		GetTradeSkillDisplayName = function(lineID)
			return "Line " .. lineID
		end,
	},
	-- The experience bar and the clock XPRate reads.
	GetTime = function()
		return now
	end,
	UnitXP = function()
		return xp
	end,
	UnitXPMax = function()
		return maxXP
	end,
	UnitAffectingCombat = function()
		return combat
	end,
	-- Hook targets: Quests/BestReward.lua's QuestInfo_Display, Bags/Junk.lua's MerchantFrame_Update and the like.
	hooksecurefunc = function(target, name, fn)
		if type(name) == "function" then
			hooks[target] = name
		elseif type(fn) == "function" then
			hooks[name] = fn
		end
	end,
	CreateFrame = function()
		return {
			SetScript = function() end,
		}
	end,
	PlaySoundFile = function()
		return true
	end,
	NORMAL_FONT_COLOR = {
		WrapTextInColorCode = function(_, text)
			return text
		end,
	},
	-- A bag slot Bags/Junk.lua's Toggle reads, and the merchant frame it updates.
	C_Container = {
		GetContainerItemInfo = function(bag, slot)
			assert(bag == 0, "the backpack")
			return slot == 1 and { itemID = 7001, quality = 2 } or nil
		end,
	},
	MerchantFrame = {
		IsShown = function()
			return false
		end,
	},
	MerchantSellAllJunkButton = {
		HookScript = function() end,
	},
	-- The quest reward panel BestReward reads: two choices whose prices, counts and panel visibility vary.
	QuestFrameRewardPanel = {
		IsVisible = function()
			return rewardOpen
		end,
	},
	QuestInfoRewardsFrame = { RewardButtons = {} },
	QUEST_TEMPLATE_REWARD = {},
	GetNumQuestChoices = function()
		return #rewardItems
	end,
	GetQuestItemLink = function(_, index)
		return rewardItems[index] and rewardItems[index].link
	end,
	GetQuestItemInfo = function(_, index)
		return "Choice", 0, rewardItems[index] and rewardItems[index].count or 1
	end,
	C_Item = {
		GetItemInfo = function(link)
			for _, item in ipairs(rewardItems) do
				if item.link == link then
					return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, item.price
				end
			end
		end,
	},
	-- Maps, their art layers and the client's explored textures.
	C_Map = {
		GetBestMapForUnit = function(unit)
			assert(unit == "player")
			return playerMap
		end,
		GetPlayerMapPosition = function()
			return { x = 0.5, y = 0.5 }
		end,
		GetMapInfo = function(mapID)
			return { mapType = mapTypes[mapID] }
		end,
		GetMapArtID = function(mapID)
			return mapArt[mapID]
		end,
		GetMapArtLayers = function(mapID)
			return artLayers[mapID]
		end,
		GetMapLevels = function(mapID)
			local range = mapLevels[mapID]
			return range and range[1] or 0, range and range[2] or 0
		end,
	},
	C_MapExplorationInfo = {
		GetExploredMapTextures = function(mapID)
			return exploredTextures[mapID]
		end,
	},
	C_NamePlate = {
		GetNamePlates = function()
			return {}
		end,
	},
	-- A rare's nameplate, and the map marker that carries the same GUID.
	UnitClassification = function(unit)
		return rareUnits[unit].class
	end,
	UnitGUID = function(unit)
		return rareUnits[unit].guid
	end,
	UnitName = function(unit)
		return rareUnits[unit].name
	end,
	C_VignetteInfo = {
		GetVignettes = function()
			return { "v1" }
		end,
		GetVignetteInfo = function(id)
			return vignettes[id]
		end,
		GetVignettePosition = function(id)
			return markerAt[id]
		end,
	},
	C_EventUtils = {
		IsEventValid = function()
			return true
		end,
	},
	Enum = {
		SpellBookSkillLineIndex = { General = 1 },
		UIMapType = { Zone = 3 },
		TooltipDataType = { Item = 0 },
	},
	GENERAL = "General",
	tContains = function(list, value)
		for _, item in ipairs(list) do
			if item == value then
				return true
			end
		end
		return false
	end,
}, { __index = _G })
-- The services the feature files register at load, stubbed as Core/Core.lua and ForeverCore provide them.
ns.ClickMode = function(mode)
	clickMode = mode
end
ns.HookBagButtons = function() end
ns.OnTooltip = function() end
ns.ForEachBagButton = function() end
ns.IsBagActionClick = function()
	return false
end
ns.OnSettingChanged = function() end
ns.Readable = function(value)
	return value
end
ns.Print = function() end
ns.Navigate = function() end
ns.core = {
	SafeCall = function(_, fn, ...)
		return fn(...)
	end,
}
-- ForeverCore's shared API kit, loaded from the checkout FOREVER_CORE names, with the one service it needs from
-- the core's namespace: SafeCallFor. It builds the hub that a later minor's Subscribe will publish.
local core = dofile("tests/forever_core.lua")
local coreNs = {
	SafeCallFor = function()
		return {
			SafeCall = function(_, _, fn, ...)
				return fn(...)
			end,
		}
	end,
}
setfenv(assert(loadfile(core.directory() .. "/Core/APIKit.lua")), env)("ForeverCore", coreNs)
env.ForeverCore = { API = 1, APIKit = coreNs.APIKit }
assert(loadfile("Locales/enUS.lua"))("TweaksForever", ns)
ns.Overlays = { [1] = "1,10,20,100,80,123;1,64,64,32,32,456;" }
-- Loads one feature file and returns a function that runs the initializers it added, so each test runs only the
-- startup it needs.
local function Load(file)
	local before = #inits
	setfenv(assert(loadfile(file)), env)("TweaksForever", ns)
	local after = #inits
	return function(...)
		for index = before + 1, after do
			inits[index](...)
		end
	end
end
Load("Data/ClassSpells.lua")
Load("Data/DungeonEntrances.lua")
Load("Data/ZoneLevels.lua")
local loadQuestie = Load("Integrations/QuestieSource.lua")
Load("UI/Spellbook.lua")
local loadJunk = Load("Bags/Junk.lua")
Load("Features/RareAlerts.lua")
Load("Map/Exploration.lua")
Load("Map/ZoneLevels.lua")
local loadBestReward = Load("Quests/BestReward.lua")
Load("UI/XPRate.lua")
-- A core whose kit is minor 1 has no Publish: the addon loads cleanly and publishes nothing.
local CoreKit = env.ForeverCore.APIKit
local publishCalls = {}
local publish = CoreKit.Publish
CoreKit.minor = 1
CoreKit.Publish = function(addonName)
	publishCalls[#publishCalls + 1] = addonName
end
Load("Core/API.lua")
assert(#publishCalls == 0, "an older kit's Publish is not called")
assert(#CoreKit.Addons() == 0, "and nothing is published on it")
CoreKit.minor = 2
CoreKit.Publish = publish
local loadAPI = Load("Core/API.lua")
local API = env.TweaksForever.API
loadJunk()
assert(API.version == 3, "v2 adds Trainers, v3 reads their names and places from QuestieDB")
assert(API.minor == 2, "minor 2 adds Subscribe and the reads below it")
assert(env.ForeverCore.APIKit ~= nil, "the shared API kit is available at load")
assert(type(API.Subscribe) == "function", "minor 2 publishes Subscribe")
-- The suite's own list carries this addon's API, at the version and minor it publishes.
local entry
for _, candidate in ipairs(env.ForeverCore.APIKit.Addons()) do
	if candidate.name == "TweaksForever" then
		entry = candidate
	end
end
assert(entry ~= nil, "Addons() lists TweaksForever")
assert(entry.version == API.version and entry.minor == API.minor, "with the API's version and minor")
assert(entry.api == API, "and the API's own table, not a copy")
local entrance = API.DungeonEntrance(230)
assert(entrance.map == 1427 and entrance.x == 0.271 and entrance.y == 0.725, "first curated zone, before login")
local another = API.DungeonEntrance(230)
assert(entrance ~= another and entrance ~= ns.InstanceEntrances[230], "fresh table on every call")
entrance.map, entrance.x, entrance.y = 1, 0, 0
assert(another.map == 1427 and another.x == 0.271 and another.y == 0.725, "copies are isolated")
entrance = API.DungeonEntrance(230)
assert(entrance.map == 1427 and entrance.x == 0.271 and entrance.y == 0.725, "callers cannot change the source")
-- Which NPCs train the class is baked, so they are listed before login and without QuestieDB, which earns the caller
-- a line to show the player instead of the places.
local trainers, install = API.Trainers()
assert(#trainers > 5, "a Shaman's class trainers, before login")
assert(install:find("QuestieDB", 1, true), "without QuestieDB, what to install")
local function Trainer(npc, list)
	for _, row in ipairs(list or trainers) do
		if row.npc == npc then
			return row
		end
	end
end
assert(Trainer(3030).name == nil and Trainer(3030).map == nil, "no name or place of its own without QuestieDB")
assert(#timers == 0, "and nothing booked")
-- With QuestieDB the names and places are its own, read over the frames after login, not in the caller's frame.
env.LibQuestieDB = questie
loadQuestie() -- login opens the read
loadAPI() -- API.lua's initializer: books the player's own trainers
assert(#timers == 1, "the read is booked at login")
trainers, install = API.Trainers()
assert(install == nil and Trainer(3030).name == nil, "installed and not read yet: ask again later")
while #timers > 0 do
	Frame()
end
trainers, install = API.Trainers()
local first = Trainer(3030)
assert(install == nil and first.name == "First Teacher", "QuestieDB's name for the trainer")
assert(first.map == 100 and first.x == 0.25 and first.y == 0.75, "and where it places one of them")
assert(Trainer(373).map == nil and Trainer(373).name == "Second Teacher", "unplaced keeps its id and name")
assert(Trainer(3032).npc == 3032 and Trainer(3032).name == nil, "a trainer QuestieDB lacks keeps its id")
for _, row in ipairs(trainers) do
	assert((row.map == nil) == (row.x == nil), "a place brings its map and both fractions")
end
local again = API.Trainers()
assert(again[1] ~= trainers[1] and again ~= trainers, "a fresh table and rows on every call")
Trainer(3030, again).name = "Changed by caller"
assert(Trainer(3030, API.Trainers()).name == "First Teacher", "callers cannot change the source")
local deathknight = class
class = "DEATHKNIGHT"
assert(#API.Trainers() == 0, "a class with no trainer list")
class = ""
assert(#API.Trainers() == 0, "and a class the client doesn't know")
class = deathknight

local cluster = ns.DungeonEntrances[1427][1]
assert(#cluster.instances == 3 and cluster.x ~= entrance.x and cluster.y ~= entrance.y, "not the merged pin centre")
cluster.x, cluster.y = 0.1, 0.2
entrance = API.DungeonEntrance(230)
assert(entrance.map == 1427 and entrance.x == 0.271 and entrance.y == 0.725, "pin changes cannot move the destination")
local unknown, unknownReason = API.DungeonEntrance(999999)
assert(unknown == nil and unknownReason == "none", "unknown instance has nothing to answer")
local naxx, naxxReason = API.DungeonEntrance(533)
assert(naxx == nil and naxxReason == "none", "Naxxramas has no placed entrance")
local monastery, monasteryReason = API.DungeonEntrance(44)
assert(monastery == nil and monasteryReason == "none", "unused Monastery has no real entrance")
local beforeLogin, beforeLoginReason = API.TrainableSpells()
assert(beforeLogin == nil and beforeLoginReason == "loading", "before login the spellbook isn't known yet")
-- Every new read that needs the saved settings says so before they exist.
local junkBefore, junkBeforeReason = API.IsJunk(1)
assert(junkBefore == nil and junkBeforeReason == "loading", "no junk marks before login")
local marksBefore, marksBeforeReason = API.JunkMarks()
assert(marksBefore == nil and marksBeforeReason == "loading", "no junk list before login")
local rateBefore, rateBeforeReason = API.XPRate()
assert(rateBefore == nil and rateBeforeReason == "loading", "no XP rate before login")
local rareBefore, rareBeforeReason = API.LastRare()
assert(rareBefore == nil and rareBeforeReason == "loading", "no rare before login")
ns.db = { junk = {} }
combat = true
local inCombat, inCombatReason = API.TrainableSpells()
assert(inCombat == nil and inCombatReason == "loading", "not in combat")
assert(API.DungeonEntrance(230).map == 1427, "entrance lookup also works in combat")
combat = false

local function Find(list, id)
	for _, spell in ipairs(list) do
		if spell.spellID == id then
			return spell
		end
	end
end
local spells = API.TrainableSpells()
assert(#spells > 10, "a level 18 Shaman who has never seen a trainer still has spells to learn")
for _, spell in ipairs(spells) do
	assert(spell.level <= 18 and not known[spell.spellID], "only what your level allows and you haven't learned")
	assert(type(spell.name) == "string" and type(spell.line) == "string", "every fact filled in")
	assert(spell.cost == nil or spell.cost >= 0, "the fee, when known")
	assert(spell.general or env.tContains({ 373, 374, 375 }, spell.lineID), "on a Shaman tab, by SkillLine ID")
end
local bolt = Find(spells, 548)
assert(bolt and bolt.name == "Lightning Bolt" and bolt.level == 14 and bolt.cost == 900, "the next rank")
assert(bolt.line == "Elemental Combat" and bolt.lineID == 375)
assert(Find(spells, 8017).line == "Line 373", "a line with no tab yet takes the client's name for it")
assert(not Find(spells, 915) and not Find(spells, 8056), "nothing above your level")
tabName = "Elementarkampf"
bolt = Find(API.TrainableSpells(), 548)
assert(bolt.line == "Elementarkampf" and bolt.lineID == 375, "a German client: the tab's own name, the same ID")
tabName = "Elemental Combat"

bolt.name = "Changed by caller"
assert(Find(API.TrainableSpells(), 548).name == "Lightning Bolt", "fresh copies")
env.TweaksForeverCharDB = {
	trainer = {
		[548] = { name = "Lightning Bolt", level = 14, cost = 700, icon = 1, lineID = 375, line = "Elemental Combat" },
		[202] = { name = "Two-Handed Swords", level = 1, cost = 1000, icon = 1, line = "Two-Handed Swords" },
	},
}
assert(Find(API.TrainableSpells(), 548).cost == 700, "a trainer visit's fee wins")
assert(not Find(API.TrainableSpells(), 202), "a weapon trainer's row is on no class tab")
known[548] = true
assert(not Find(API.TrainableSpells(), 548), "learned")
level = 20
assert(Find(API.TrainableSpells(), 915) and Find(API.TrainableSpells(), 8056), "a level up brings the next ones")
env.TweaksForeverCharDB = {
	trainer = { [9999] = { name = "Dual Wield", level = 20, icon = 1, lineID = 118, general = true } },
}
local wield = Find(API.TrainableSpells(), 9999)
assert(wield and wield.general and wield.line == "General" and wield.lineID == 118, "a General tab row, its own line")
assert(Find(API.TrainableSpells(), 915).general == false, "and a class tab's is not")
class = "DEATHKNIGHT"
env.TweaksForeverCharDB = nil
assert(#API.TrainableSpells() == 0, "no list, no answer")

-- The player's own junk marks: the feature's off answer, then the marks the bag coin is drawn from.
active.markJunk = false
local marksOff, marksOffReason = API.JunkMarks()
assert(marksOff == nil and marksOffReason == "disabled", "marks are off with the feature")
local junkOff, junkOffReason = API.IsJunk(7001)
assert(junkOff == nil and junkOffReason == "disabled", "and no item is marked")
active.markJunk = true
assert(#API.JunkMarks() == 0, "the player has marked nothing yet")
clickMode.Apply(nil, 0, 1)
assert(API.IsJunk(7001) == true, "the toggled slot's item is marked")
assert(API.IsJunk(7002) == false, "another item is not")
local listed = API.JunkMarks()
assert(#listed == 1 and listed[1] == 7001, "the marks as item IDs")
listed[1] = 1
assert(API.JunkMarks()[1] == 7001, "a fresh list on every call")
local badItem, badItemReason = API.IsJunk(1.5)
assert(badItem == nil and badItemReason == "invalid", "an item ID is a whole number")
clickMode.Apply(nil, 0, 1)
assert(API.IsJunk(7001) == false and #API.JunkMarks() == 0, "toggling again takes the mark away")

-- A zone's level range: the current zone, the client's own range where it has one, and nothing for a city.
playerMap = 1439
local range = API.ZoneLevels(nil)
assert(range.low == 10 and range.high == 20, "Darkshore, the current zone")
local ranged = API.ZoneLevels(1439)
assert(ranged ~= range and ranged.low == 10, "a fresh table on every call")
range.low = 1
assert(API.ZoneLevels(1439).low == 10, "callers cannot change the source")
mapLevels[1439] = { 12, 22 }
assert(API.ZoneLevels(1439).low == 12 and API.ZoneLevels(1439).high == 22, "the client's range wins")
local city, cityReason = API.ZoneLevels(1454)
assert(city == nil and cityReason == "none", "a city has no range")
local badMap, badMapReason = API.ZoneLevels(1.5)
assert(badMap == nil and badMapReason == "invalid", "a map ID is a whole number")
playerMap = nil
local noZone, noZoneReason = API.ZoneLevels(nil)
assert(noZone == nil and noZoneReason == "none", "nowhere to ask about")

-- XP per hour and the time to the next level, the figures the tooltip's lines show.
active.xpRate = false
local rateOff, rateOffReason = API.XPRate()
assert(rateOff == nil and rateOffReason == "disabled", "XP is not counted while the feature is off")
active.xpRate = true
local started = now
maxXP = 1000
ns.XPRate.Start(started, 0, maxXP)
now = started + 299
local early, earlyReason = API.XPRate()
assert(early == nil and earlyReason == "loading", "no rate in the first five minutes")
now = started + 300
local zero = API.XPRate()
assert(zero.perHour == 0 and zero.toLevel == nil, "a zero rate has no time to level")
ns.XPRate.Update(started + 100, 100, maxXP, true)
xp = 100
now = started + 300
local measured = API.XPRate()
assert(measured.perHour == 1200 and measured.toLevel == 2700, "the tooltip's own figures")
local measuredAgain = API.XPRate()
assert(measuredAgain ~= measured, "a fresh table on every call")
measured.perHour = 1
assert(API.XPRate().perHour == 1200, "callers cannot change the source")
active.xpRate = false
local rateAfter, rateAfterReason = API.XPRate()
assert(rateAfter == nil and rateAfterReason == "disabled", "off again")

-- The last rare alert: the feature's off answer, nothing yet, then the marker's live position.
active.rareAlerts = false
local rareOff, rareOffReason = API.LastRare()
assert(rareOff == nil and rareOffReason == "disabled", "no rare alerts while the feature is off")
active.rareAlerts = true
local noRare, noRareReason = API.LastRare()
assert(noRare == nil and noRareReason == "none", "none has alerted yet")
playerMap = 1439
rareUnits.rare1 = { class = "rare", guid = "Creature-0-1-0-1-61-AAA", name = "Old Griz" }
vignettes.v1 = { atlasName = "VignetteKill", objectGUID = "Creature-0-1-0-1-61-AAA", name = "Old Griz" }
markerAt.v1 = { x = 0.4, y = 0.6 }
now = now + 10
Fire("NAME_PLATE_UNIT_ADDED", "rare1")
local rare = API.LastRare()
assert(rare.name == "Old Griz" and rare.map == 1439 and rare.x == 0.4 and rare.y == 0.6, "the rare at its marker")
markerAt.v1 = { x = 0.45, y = 0.5 }
local moved = API.LastRare()
assert(moved.x == 0.45 and moved.y == 0.5, "the marker's current position")
vignettes.v1.isDead = true
local gone = API.LastRare()
assert(gone.x == 0.4 and gone.y == 0.6, "where it was last seen")
gone.name = "Changed by caller"
assert(API.LastRare().name == "Old Griz", "a fresh table on every call")

-- A zone's unexplored areas as 0 to 1 rectangles, over the same decoded art the tint draws.
mapTypes[5000] = 3
mapArt[5000] = 1
artLayers[5000] = { { layerWidth = 256, layerHeight = 256 } }
exploredTextures[5000] = { { offsetX = 64, offsetY = 64, textureWidth = 32, textureHeight = 32 } }
local areas = API.Unexplored(5000)
assert(#areas == 1, "the explored area is left out")
local area = areas[1]
assert(area.left == 10 / 256 and area.top == 20 / 256, "art pixels as fractions")
assert(area.right == 110 / 256 and area.bottom == 100 / 256, "its far corner too")
for _, rectangle in ipairs(areas) do
	assert(
		rectangle.left >= 0
			and rectangle.left <= 1
			and rectangle.top >= 0
			and rectangle.top <= 1
			and rectangle.right >= 0
			and rectangle.right <= 1
			and rectangle.bottom >= 0
			and rectangle.bottom <= 1,
		"every rectangle is inside 0 to 1"
	)
end
playerMap = 5000
local currentAreas = API.Unexplored(nil)
assert(#currentAreas == 1 and currentAreas[1] ~= area, "the current zone, in a fresh table")
exploredTextures[5000] = {
	{ offsetX = 10, offsetY = 20, textureWidth = 100, textureHeight = 80 },
	{ offsetX = 64, offsetY = 64, textureWidth = 32, textureHeight = 32 },
}
local allExplored = API.Unexplored(5000)
assert(type(allExplored) == "table" and #allExplored == 0, "every area explored answers an empty list")
mapTypes[5001] = 3
local noArt, noArtReason = API.Unexplored(5001)
assert(noArt == nil and noArtReason == "none", "a zone the client has no overlay art for")
mapTypes[5002] = 0
local notZone, notZoneReason = API.Unexplored(5002)
assert(notZone == nil and notZoneReason == "none", "not a zone")
local badUnexplored, badUnexploredReason = API.Unexplored(1.5)
assert(badUnexplored == nil and badUnexploredReason == "invalid", "a map ID is a whole number")

-- The best-selling reward choice: an index while the panel is up, a price still loading, and none for a tie, fewer
-- than two choices or no panel.
loadBestReward()
local noPanel, noPanelReason = API.BestReward()
assert(noPanel == nil and noPanelReason == "none", "no reward panel on screen")
rewardItems = {
	{ link = "item:1", count = 1, price = 100 },
	{ link = "item:2", count = 2, price = 60 },
}
rewardOpen = true
hooks.QuestInfo_Display(env.QUEST_TEMPLATE_REWARD)
assert(API.BestReward() == 2, "the choice that sells for the most")
assert(not active.bestReward, "answered with the marker feature off")
rewardItems[2].price = false
local pending, pendingReason = API.BestReward()
assert(pending == nil and pendingReason == "loading", "a price the client hasn't read yet")
rewardItems[2].price = 50
local tied, tiedReason = API.BestReward()
assert(tied == nil and tiedReason == "none", "a tie at the top")
rewardItems = { { link = "item:1", count = 1, price = 100 } }
local lone, loneReason = API.BestReward()
assert(lone == nil and loneReason == "none", "a lone reward is no choice")
rewardOpen = false
local closed, closedReason = API.BestReward()
assert(closed == nil and closedReason == "none", "the panel closed")

-- Subscribe: trainable only when the sorted spell IDs change, and junk once on the frame after a mark toggles.
class = "SHAMAN"
level = 18
known = { [403] = true, [529] = true }
env.TweaksForeverCharDB = nil
local heard = {}
local unsubscribe = API.Subscribe(function(changes)
	heard[#heard + 1] = changes
end)
assert(#heard == 0, "the first subscriber starts from what the channels answer now")
Fire("SPELLS_CHANGED")
Frame()
assert(#heard == 0, "a spell event that changes nothing stays quiet")
known[548] = true
Fire("SPELLS_CHANGED")
assert(#timers == 1 and #heard == 0, "the next frame, not the event")
Frame()
assert(#heard == 1 and heard[1].trainable == true and heard[1].junk == nil, "a learned spell names trainable")
level = 20
Fire("PLAYER_LEVEL_UP")
Frame()
assert(#heard == 2 and heard[2].trainable == true, "a level up brings the next spells")
Fire("PLAYER_LEVEL_UP")
Frame()
assert(#heard == 2, "nothing new at the same level")
combat = true
Fire("SPELLS_CHANGED")
Frame()
assert(#heard == 2, "entering combat is not a change")
known[915] = true
Fire("SPELLS_CHANGED")
Frame()
assert(#heard == 2, "a change during combat waits")
combat = false
Fire("PLAYER_REGEN_ENABLED")
Frame()
assert(#heard == 3 and heard[3].trainable == true, "and is heard once combat ends")
unsubscribe()
unsubscribe()
level = 22
Fire("PLAYER_LEVEL_UP")
Frame()
assert(#heard == 3, "unsubscribing, even twice, stops the callbacks")

active.markJunk = true
local junkHeard = {}
local unsubscribeJunk = API.Subscribe(function(changes)
	junkHeard[#junkHeard + 1] = changes
end)
assert(#junkHeard == 0, "the junk channel starts from the marks now")
clickMode.Apply(nil, 0, 1)
assert(#timers == 1 and #junkHeard == 0, "a mark toggled now is heard on the next frame")
Frame()
assert(#junkHeard == 1 and junkHeard[1].junk == true and junkHeard[1].trainable == nil, "one call, naming junk")
clickMode.Apply(nil, 0, 1)
clickMode.Apply(nil, 0, 1)
assert(#timers == 1, "two toggles in one frame arm one dispatch")
Frame()
assert(#junkHeard == 2 and junkHeard[2].junk == true, "a later burst names junk again")
assert(junkHeard[2] ~= junkHeard[1], "and sends a fresh table")
unsubscribeJunk()
unsubscribeJunk()

-- A rare alert raises its own channel, once per alert.
local rareHeard = {}
local unsubscribeRare = API.Subscribe(function(changes)
	rareHeard[#rareHeard + 1] = changes
end)
now = now + 601
vignettes.v1.isDead = nil
markerAt.v1 = { x = 0.5, y = 0.5 }
Fire("NAME_PLATE_UNIT_ADDED", "rare1")
Frame()
assert(#rareHeard == 1 and rareHeard[1].rare == true, "an alert names rare")
unsubscribeRare()

-- The shared kit itself: its next frame, one call per burst and fresh changes table are pinned here with the
-- harness's C_Timer, as docs/api.md describes the shared shape.
local notices, notifyHeard = 0, {}
local hub = env.ForeverCore.APIKit.Hub("TweaksForever", {
	notice = function()
		return notices
	end,
})
local unsubscribeKit = hub.Subscribe(function(changes)
	notifyHeard[#notifyHeard + 1] = changes
end)
assert(#notifyHeard == 0, "the first subscriber starts from what the channels answer now")
notices = notices + 1
hub.Queue()
hub.Queue()
assert(#timers == 1 and #notifyHeard == 0, "two queues in one frame arm one timer and call nothing yet")
Frame()
assert(#notifyHeard == 1 and notifyHeard[1].notice == true, "the next frame sends one call, naming the change")
notices = notices + 1
hub.Queue()
Frame()
assert(#notifyHeard == 2 and notifyHeard[2].notice == true, "a later burst names the change")
assert(notifyHeard[2] ~= notifyHeard[1], "and sends a fresh table")
unsubscribeKit()
unsubscribeKit()
notices = notices + 1
hub.Queue()
Frame()
assert(#notifyHeard == 2, "unsubscribing, even twice, stops the callbacks")
print("api: ok")
