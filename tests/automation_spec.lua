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
env._G = env
setfenv(assert(loadfile("Automation.lua")), env)("TweaksForever", ns)
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
print("automation: ok")
