local features, initializers = {}, {}
local ns = {
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
}

-- A synthetic QuestieDB. Quest 1: kill wolves (creature 10), then collect fangs (item 500) that wolves and bears
-- (11) drop. Quest 2: kill credit from ghouls (20, 21) on a bunny (29), with the item listed first by a hint.
-- Quest 3: an object to use and then boars (30) to kill. Quest 4 isn't in QuestieDB.
local quests = {
	[1] = { objectives = { { { 10 } }, nil, { { 500 } } } },
	[2] = { objectives = { nil, nil, { { 501 } }, nil, { { { 20, 21 }, 29, "Ghoul slain" } } } },
	[3] = { objectives = { { { 30 } }, { { 700 } } }, triggerEnd = { "Explore", {} } },
}
local items = { [500] = { npcDrops = { 10, 11 } }, [501] = { npcDrops = { 40 } } }
local reads = 0
local function Entity(rows)
	return {
		GetAll = function(id, keys)
			reads = reads + 1
			local row = rows[id]
			if not row then
				return nil
			end
			local values = { n = #keys }
			for i, key in ipairs(keys) do
				values[i] = row[key]
			end
			return values
		end,
	}
end
local library = {
	Quest = Entity(quests),
	Item = Entity(items),
	ObjectiveFirst = { itemObjectiveFirst = { [2] = true } },
}

-- The quest log, as C_QuestLog lists it: a header, then the quests with their objectives in the log's order.
local log = {
	{ title = "Elwynn Forest", isHeader = true },
	{ questID = 1, title = "Wolves and Fangs" },
	{ questID = 2, title = "Ghoulish" },
	{ questID = 3, title = "Boars" },
	{ questID = 4, title = "Unknown" },
}
local objectives = {
	[1] = {
		{ text = "Mangy Wolf slain: 3/10", type = "monster", finished = false },
		{ text = "Wolf Fang: 5/5", type = "item", finished = true },
	},
	[2] = {
		{ text = "Cursed Bone: 0/4", type = "item", finished = false },
		{ text = "Ghoul slain: 1/8", type = "monster", finished = false },
	},
	-- QuestieDB lists the boars first; this log lists the object first, so neither position agrees on its kind.
	[3] = {
		{ text = "Shrine used: 0/1", type = "object", finished = false },
		{ text = "Boar slain: 0/6", type = "monster", finished = false },
		{ text = "Explore", type = "event", finished = false },
	},
}
local complete = {}
local postCalls, events, changed, timers = {}, {}, {}, {}

local icons = {}
local function Texture()
	local texture = { shown = false }
	icons[#icons + 1] = texture
	function texture.SetAtlas(self, atlas)
		self.atlas = atlas
	end
	function texture.SetAllPoints() end
	function texture.Show(self)
		self.shown = true
	end
	function texture.Hide(self)
		self.shown = false
	end
	return texture
end

local plates, guids = {}, {}
local env = setmetatable({
	C_QuestLog = {
		GetNumQuestLogEntries = function()
			return #log, #log - 1
		end,
		GetInfo = function(index)
			return log[index]
		end,
		GetQuestObjectives = function(id)
			return objectives[id]
		end,
		IsComplete = function(id)
			return complete[id] or false
		end,
	},
	C_NamePlate = {
		GetNamePlateForUnit = function(unit)
			return plates[unit]
		end,
		GetNamePlates = function()
			return { { UnitFrame = { unit = "nameplate9", HealthBarsContainer = {} } } }
		end,
	},
	C_Timer = {
		After = function(_, fn)
			timers[#timers + 1] = fn
		end,
	},
	CreateFrame = function()
		return {
			SetSize = function() end,
			SetPoint = function() end,
			CreateTexture = Texture,
		}
	end,
	UnitGUID = function(unit)
		return guids[unit]
	end,
	Settings = {
		SetOnValueChangedCallback = function(name, fn)
			changed[name] = fn
		end,
	},
	TooltipDataProcessor = {
		AddTooltipPostCall = function(kind, fn)
			postCalls[kind] = fn
		end,
	},
	Enum = { TooltipDataType = { Unit = 2 }, TooltipDataLineType = { QuestObjective = 8, QuestTitle = 17 } },
	NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 },
	HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 },
	GRAY_FONT_COLOR = { r = 0.5, g = 0.5, b = 0.5 },
	canaccessvalue = function(value)
		return value ~= "secret"
	end,
}, { __index = _G })
ns.QuestieDB = function()
	return env.LibQuestieDB
end
setfenv(assert(loadfile("QuestProgress.lua")), env)("TweaksForever", ns)
local Model = ns.QuestProgress
assert(features.questTooltips.default == true and features.questPlates.default == true)
assert(#initializers == 1)

-- Questie's own options stand in for these while they are on.
assert(not features.questTooltips.conflicts[1].when())
env.Questie = { db = { profile = { enableTooltips = true, nameplateEnabled = false } } }
assert(features.questTooltips.conflicts[1].when() and not features.questPlates.conflicts[1].when())
env.Questie = nil

-- Without QuestieDB there is nothing to read.
assert(not Model.Attach())
env.LibQuestieDB = library
assert(Model.Attach())

-- Creature IDs come from creature and vehicle GUIDs only, and never from a secret one.
assert(Model.NpcId("Creature-0-3113-0-47-1234-0000ABCDEF") == 1234)
assert(Model.NpcId("Vehicle-0-3113-0-47-55-0000ABCDEF") == 55)
assert(Model.NpcId("Player-4395-0ABCDEF1") == nil)
assert(Model.NpcId("GameObject-0-3113-0-47-1234-0000ABCDEF") == nil)
assert(Model.NpcId("secret") == nil and Model.NpcId(nil) == nil)

-- Objectives in the log's order: by kind, with a hinted kind moved to the front and the event last.
local targets = Model.Targets(2)
assert(#targets == 2 and targets[1].kind == "item" and targets[1].npcs[40])
assert(targets[2].kind == "monster" and targets[2].npcs[20] and targets[2].npcs[21] and targets[2].npcs[29])
targets = Model.Targets(3)
assert(#targets == 3 and targets[1].kind == "monster" and targets[2].kind == "object" and targets[3].kind == "event")
local before = reads
Model.Targets(1)
Model.Targets(1)
assert(reads - before == 2, "a quest and its item are read once")
assert(#Model.Targets(4) == 0)

-- Lines: the title in the game's yellow, each objective the creature counts for in white, grey once done.
Model.Rebuild()
local lines = Model.Lines(10)
assert(#lines == 3 and lines[1][1] == "Wolves and Fangs" and lines[1][3] == 0.82)
assert(lines[2][1] == " - Mangy Wolf slain: 3/10" and lines[2][2] == 1)
assert(lines[3][1] == " - Wolf Fang: 5/5" and lines[3][2] == 0.5)
lines = Model.Lines(11)
assert(#lines == 2 and lines[2][1] == " - Wolf Fang: 5/5", "bears only drop the fangs")
lines = Model.Lines(21)
assert(#lines == 2 and lines[1][1] == "Ghoulish" and lines[2][1] == " - Ghoul slain: 1/8")
assert(#Model.Lines(40) == 2, "a hinted item objective is the first")
assert(#Model.Lines(30) == 0, "a position whose kind disagrees is left out")
assert(#Model.Lines(99) == 0)

-- Needed: an unfinished objective in a quest that isn't complete.
assert(Model.Needed(10) and not Model.Needed(11) and Model.Needed(21) and not Model.Needed(99))
complete[1] = true
assert(not Model.Needed(10))
complete[1] = nil

-- The game's own quest lines win.
assert(Model.HasQuestLines({ lines = { { type = 0 }, { type = 17 } } }))
assert(not Model.HasQuestLines({ lines = { { type = 0 } } }))

-- Wired up: a creature's tooltip gains its lines, a needed creature's nameplate its icon, and both toggles apply.
ns.db = { questTooltips = true, questPlates = true }
ns.Active = function(key)
	return ns.db[key]
end
ns.On = function(event, fn)
	events[event] = fn
end
local wolf = "Creature-0-3113-0-47-10-0000ABCDEF"
guids.nameplate9 = wolf
initializers[1]()
assert(#icons == 1 and icons[1].shown, "a plate up before login")
table.remove(icons)
local added, shown = {}, false
local tooltip = {
	AddLine = function(_, text)
		added[#added + 1] = text
	end,
	Show = function()
		shown = true
	end,
}
env.GameTooltip = tooltip
postCalls[2](tooltip, { guid = wolf, lines = {} })
assert(#added == 3 and shown)
postCalls[2](tooltip, { guid = wolf, lines = { { type = 8 } } })
assert(#added == 3, "the game already listed them")
ns.db.questTooltips = false
postCalls[2](tooltip, { guid = wolf, lines = {} })
assert(#added == 3, "switched off")

local plate = { UnitFrame = { HealthBarsContainer = {} } }
plates.nameplate1, guids.nameplate1 = plate, wolf
events.NAME_PLATE_UNIT_ADDED("nameplate1")
assert(#icons == 1 and icons[1].shown and icons[1].atlas == "questobjective")
-- Progress arrives as events, coalesced into one rebuild on the next frame.
objectives[1][1].finished = true
events.QUEST_LOG_UPDATE()
events.UNIT_QUEST_LOG_CHANGED("player")
events.UNIT_QUEST_LOG_CHANGED("party1")
assert(#timers == 1 and icons[1].shown)
timers[1]()
assert(not icons[1].shown, "no longer needed")
objectives[1][1].finished = false
ns.db.questPlates = false
changed.TweaksForever_questPlates()
assert(not icons[1].shown, "switched off")
ns.db.questPlates = true
changed.TweaksForever_questPlates()
assert(#icons == 1 and icons[1].shown, "one icon per plate, reused")
events.NAME_PLATE_UNIT_REMOVED("nameplate1")
assert(not icons[1].shown)
-- A plate addon code isn't handed, and a secret GUID, show nothing.
plates.nameplate2, guids.nameplate2 = nil, wolf
events.NAME_PLATE_UNIT_ADDED("nameplate2")
plates.nameplate3, guids.nameplate3 = { UnitFrame = { HealthBarsContainer = {} } }, "secret"
events.NAME_PLATE_UNIT_ADDED("nameplate3")
assert(#icons == 1)
print("questprogress: ok")
