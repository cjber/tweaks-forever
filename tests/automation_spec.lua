local features, handlers, db = {}, {}, {}
local ns = {
	Feature = function(feature)
		features[feature.key] = feature
	end,
	On = function(event, fn)
		handlers[event] = fn
	end,
	Active = function(key)
		return db[key]
	end,
}

local TAXI, CHAT, VENDOR = 132057, 132053, 132060
local Available, Unavailable = 0, 2
local shift, forced = false, false
local options, active, available = {}, {}, {}
local selected
local env = setmetatable({
	Enum = { GossipOptionStatus = { Available = Available, Unavailable = Unavailable } },
	IsShiftKeyDown = function()
		return shift
	end,
	C_GossipInfo = {
		GetOptions = function()
			return options
		end,
		GetActiveQuests = function()
			return active
		end,
		GetAvailableQuests = function()
			return available
		end,
		GetNumActiveQuests = function()
			return #active
		end,
		GetNumAvailableQuests = function()
			return #available
		end,
		ForceGossip = function()
			return forced
		end,
		SelectOptionByIndex = function(index)
			selected = "option " .. index
		end,
		SelectAvailableQuest = function(questID)
			selected = "quest " .. questID
		end,
		SelectActiveQuest = function(questID)
			selected = "quest " .. questID
		end,
	},
}, { __index = _G })
setfenv(assert(loadfile("Features/Automation.lua")), env)("TweaksForever", ns)
assert(features.gossip.default == false)

local function option(orderIndex, icon, flagged, status)
	return {
		orderIndex = orderIndex,
		icon = icon,
		selectOptionWhenOnlyOption = flagged or false,
		status = status or Available,
	}
end

local function talk(list)
	options, selected = list, nil
	handlers.GOSSIP_SHOW()
	return selected
end

local flightMaster = { option(0, CHAT), option(1, TAXI) }
assert(talk(flightMaster) == nil, "the setting is off by default")

db.gossip = true
assert(talk(flightMaster) == "option 1", "a flight master opens the flight map")
forced = true
assert(talk(flightMaster) == "option 1", "the taxi is picked even when the NPC forces gossip")
forced = false
assert(talk({ option(0, TAXI, true), option(1, VENDOR) }) == "option 0", "the game's flag only covers a lone option")
assert(talk({ option(0, CHAT), option(1, TAXI, false, Unavailable) }) == nil)

shift = true
assert(talk(flightMaster) == nil, "Shift shows the gossip")
shift = false

assert(talk({ option(0, VENDOR), option(1, CHAT) }) == nil, "an innkeeper or vendor keeps its choices")

assert(talk({ option(3, VENDOR) }) == "option 3", "a lone option is taken")
assert(talk({ option(3, TAXI, true) }) == nil, "the game selects a lone flagged option itself")
forced = true
assert(talk({ option(3, VENDOR) }) == nil, "a forced lone option stays open")
assert(talk({ option(3, TAXI, true) }) == "option 3", "the game leaves a forced taxi, so it is picked here")
forced = false

available = { { questID = 42, isTrivial = false } }
assert(talk(flightMaster) == nil, "offered quests keep the gossip open while quest automation is off")
db.quests = true
assert(talk(flightMaster) == "quest 42", "a quest is picked before the flight map")
available = {}
active = { { questID = 7, isComplete = true } }
assert(talk(flightMaster) == "quest 7", "a turn-in is picked before the flight map")
active = {}

db.gossip = false
assert(talk(flightMaster) == nil, "the setting off leaves every option alone")
assert(features.fastLoot.default == true, "fast looting starts on")
local looted = {}
env.GetNumLootItems = function()
	return 3
end
env.LootSlot = function(slot)
	looted[#looted + 1] = slot
end
db.fastLoot = features.fastLoot.default
handlers.LOOT_READY(true)
assert(table.concat(looted, ",") == "3,2,1", "auto loot takes every slot")
looted = {}
handlers.LOOT_READY(false)
handlers.LOOT_READY(nil)
assert(#looted == 0, "manual or modified-click looting remains manual")
db.fastLoot = false
handlers.LOOT_READY(true)
assert(#looted == 0, "the toggle disables fast looting immediately")

-- The quest frame: a PvP-flagging quest and a hand-in that costs gold wait for the player.
local calls = {}
local pvp, autoAccepted, cost, choices = false, false, 0, 0
env.QuestFlagsPVP = function()
	return pvp
end
env.QuestGetAutoAccept = function()
	return autoAccepted
end
env.GetQuestMoneyToGet = function()
	return cost
end
env.GetNumQuestChoices = function()
	return choices
end
for _, name in ipairs({ "AcceptQuest", "AcknowledgeAutoAcceptQuest", "GetQuestReward", "CompleteQuest" }) do
	env[name] = function(...)
		calls[#calls + 1] = name .. (select("#", ...) > 0 and "(" .. tostring((...)) .. ")" or "")
	end
end
env.IsQuestCompletable = function()
	return true
end
local function Quest(event)
	calls = {}
	handlers[event]()
	return table.concat(calls, ",")
end

db.quests = true
assert(Quest("QUEST_DETAIL") == "AcceptQuest", "an ordinary quest is accepted")
pvp = true
assert(Quest("QUEST_DETAIL") == "", "a quest that flags you for PvP is left to accept")
pvp, autoAccepted = false, true
assert(Quest("QUEST_DETAIL") == "AcknowledgeAutoAcceptQuest", "a quest the server accepted is acknowledged")
autoAccepted = false
assert(Quest("QUEST_PROGRESS") == "CompleteQuest")
assert(Quest("QUEST_COMPLETE") == "GetQuestReward(0)", "a quest with no reward choice is handed in")
choices = 1
assert(Quest("QUEST_COMPLETE") == "GetQuestReward(1)", "a lone reward is taken")
cost = 500
assert(Quest("QUEST_COMPLETE") == "", "a hand-in that costs gold waits for you to pay")
cost, choices = 0, 2
assert(Quest("QUEST_COMPLETE") == "", "a choice of rewards is yours")
choices = 0
shift = true
assert(Quest("QUEST_DETAIL") == "" and Quest("QUEST_COMPLETE") == "", "Shift skips the quest frame too")
shift = false
db.quests = false
assert(Quest("QUEST_DETAIL") == "" and Quest("QUEST_COMPLETE") == "", "off leaves the quest frame alone")

print("automation: ok")
