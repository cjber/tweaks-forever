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

-- With Polestar loaded, each of these stands down while Polestar's own matching setting is on.
local polestar = {
	quests = "behavior.autoAccept,behavior.autoTurnin",
	gossip = "qol.skipGossip",
	summons = "qol.acceptSummon",
	resurrections = "qol.acceptResurrect",
	releasePvP = "qol.autoReleasePvP",
	declineDuels = "qol.declineDuels",
	fastLoot = "qol.fastLoot",
	partyFriends = "qol.acceptPartyFriends",
	partyStrangers = "qol.declinePartyStrangers",
}
for key, paths in pairs(polestar) do
	local found = {}
	for _, conflict in ipairs(features[key].conflicts) do
		if conflict.polestar then
			found[#found + 1] = conflict.polestar
		end
	end
	assert(table.concat(found, ",") == paths, key .. " names Polestar's " .. paths)
end

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
local pvp, autoAccepted, areaTrigger, cost, choices = false, false, false, 0, 0
env.QuestFlagsPVP = function()
	return pvp
end
env.QuestIsFromAreaTrigger = function()
	return areaTrigger
end
env.GetQuestID = function()
	return 99
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
autoAccepted = true
assert(Quest("QUEST_DETAIL") == "AcknowledgeAutoAcceptQuest", "a quest the server accepted is acknowledged")
pvp = true
assert(Quest("QUEST_DETAIL") == "AcknowledgeAutoAcceptQuest", "even one that flags for PvP: it is already yours")
pvp, areaTrigger = false, true
assert(Quest("QUEST_DETAIL") == "", "an area's quest is Blizzard's popup to answer")
autoAccepted, areaTrigger = false, false
local Ack = env.AcknowledgeAutoAcceptQuest
env.QuestGetAutoAccept, env.AcknowledgeAutoAcceptQuest = nil, nil
assert(Quest("QUEST_DETAIL") == "AcceptQuest", "a client without the auto-accept calls still accepts")
env.QuestGetAutoAccept = function()
	return autoAccepted
end
env.AcknowledgeAutoAcceptQuest = Ack

-- A PvP-flagging quest is left open, and the NPC's list moves past it on the next visit.
pvp = true
assert(Quest("QUEST_DETAIL") == "", "a quest that flags you for PvP is left to accept")
pvp = false
available = { { questID = 99, isTrivial = false }, { questID = 100, isTrivial = false } }
assert(talk({}) == "quest 100", "the gossip list skips the quest left for you")
available = {}
env.GetNumActiveQuests = function()
	return 0
end
env.GetNumAvailableQuests = function()
	return 2
end
env.GetAvailableQuestInfo = function(index)
	return false, 0, false, false, index == 1 and 99 or 100
end
env.SelectAvailableQuest = function(index)
	calls[#calls + 1] = "select " .. index
end
assert(Quest("QUEST_GREETING") == "select 2", "the greeting list skips it too")

assert(Quest("QUEST_PROGRESS") == "CompleteQuest", "a completable quest moves on to its reward")
assert(Quest("QUEST_COMPLETE") == "GetQuestReward(0)", "a quest with no reward choice is handed in")
choices = 1
assert(Quest("QUEST_COMPLETE") == "GetQuestReward(1)", "a lone reward is taken")
cost = 500
assert(Quest("QUEST_COMPLETE") == "", "a hand-in that costs gold waits for you to pay")
choices = 0
assert(Quest("QUEST_COMPLETE") == "", "with no reward choice too")
cost = nil
assert(Quest("QUEST_COMPLETE") == "GetQuestReward(0)", "no cost reported is no cost")
cost, choices = 0, 2
assert(Quest("QUEST_COMPLETE") == "", "a choice of rewards is yours")
choices = 0
shift = true
autoAccepted = true
assert(Quest("QUEST_DETAIL") == "" and Quest("QUEST_COMPLETE") == "", "Shift skips the quest frame too")
autoAccepted = false
shift = false
db.quests = false
assert(Quest("QUEST_DETAIL") == "" and Quest("QUEST_COMPLETE") == "", "off leaves the quest frame alone")

-- Duels from friends and guild, and party invites by who sent them.
assert(not features.duelFriends.default and features.duelFriends.parent == "declineDuels")
assert(not features.partyFriends.default and not features.partyStrangers.default, "invite options start off")
local friends, bnet, guild, queue = { Pal = true }, { "Buddy-OtherRealm" }, { "Mate-Realm" }, "none"
env.C_FriendList = {
	GetFriendInfo = function(name)
		return friends[name] and {} or nil
	end,
	IsFriend = function(guid)
		return guid == "Player-1-PAL"
	end,
}
env.C_BattleNet = {
	GetAccountInfoByGUID = function(guid)
		return guid == "Player-1-BUD" and { isFriend = true } or nil
	end,
	GetFriendAccountInfo = function(index)
		return { gameAccountInfo = { characterName = bnet[index] } }
	end,
}
env.BNGetNumFriends = function()
	return #bnet
end
env.IsGuildMember = function(guid)
	return guid == "Player-1-MATE"
end
env.IsInGuild = function()
	return true
end
env.GetNumGuildMembers = function()
	return #guild
end
env.GetGuildRosterInfo = function(index)
	return guild[index]
end
env.Ambiguate = function(name)
	return (name:gsub("%-.*", ""))
end
env.GetMaxBattlefieldID = function()
	return 1
end
env.GetBattlefieldStatus = function()
	return queue
end
local cancelled, accepted, declined, inGroup = 0, 0, 0, false
env.CancelDuel = function()
	cancelled = cancelled + 1
end
env.AcceptGroup = function()
	accepted = accepted + 1
end
env.DeclineGroup = function()
	declined = declined + 1
end
env.IsInGroup = function()
	return inGroup
end
local timers, hidden = {}, {}
env.C_Timer = {
	After = function(_, fn)
		timers[#timers + 1] = fn
	end,
}
env.StaticPopup_Hide = function(name)
	hidden[#hidden + 1] = name
end
local function Tick()
	local due = timers
	timers = {}
	for _, fn in ipairs(due) do
		fn()
	end
end

db.declineDuels = true
handlers.DUEL_REQUESTED("Pal")
assert(cancelled == 1, "without the exception every duel is declined")
db.duelFriends = true
for _, name in ipairs({ "Pal", "Buddy", "Mate-Realm" }) do
	handlers.DUEL_REQUESTED(name)
end
assert(cancelled == 1, "friends, Battle.net friends and guild still ask")
handlers.DUEL_REQUESTED("Stranger")
assert(cancelled == 2, "a stranger's duel is declined")
db.declineDuels, db.duelFriends = false, false

db.partyFriends = true
for index = #hidden, 1, -1 do
	hidden[index] = nil
end
handlers.PARTY_INVITE_REQUEST("Pal", false, false, false, true, false, "Player-1-PAL")
assert(accepted == 1, "a friend's invite is accepted")
Tick()
assert(#hidden == 0, "the popup stays until you are in the group")
handlers.PARTY_INVITE_REQUEST("Buddy", false, false, false, true, false, "Player-1-BUD")
inGroup = true
Tick()
assert(accepted == 2 and hidden[1] == "PARTY_INVITE", "a Battle.net friend's too, popup gone once grouped")
handlers.PARTY_INVITE_REQUEST("Mate", false, false, false, true, false, "Player-1-MATE")
assert(accepted == 3, "a guildmate's too")
timers = {}
queue = "queued"
handlers.PARTY_INVITE_REQUEST("Pal", false, false, false, true, false, "Player-1-PAL")
assert(accepted == 3, "not while queued for a battleground")
queue, shift = "none", true
handlers.PARTY_INVITE_REQUEST("Pal", false, false, false, true, false, "Player-1-PAL")
assert(accepted == 3, "Shift leaves it to you")
shift = false
handlers.PARTY_INVITE_REQUEST("Stranger", false, false, false, true, false, "Player-1-X")
assert(accepted == 3 and declined == 0, "a stranger's invite is left alone without the decline option")
db.partyStrangers = true
for index = #hidden, 1, -1 do
	hidden[index] = nil
end
handlers.PARTY_INVITE_REQUEST("Stranger", false, false, false, true, false, "Player-1-X")
assert(declined == 1 and hidden[1] == "PARTY_INVITE", "a stranger's invite is declined")
handlers.PARTY_INVITE_REQUEST("Pal", false, false, false, true, false, "Player-1-PAL")
assert(declined == 1, "a friend's never is")
db.partyFriends, db.partyStrangers = false, false
handlers.PARTY_INVITE_REQUEST("Pal", false, false, false, true, false, "Player-1-PAL")
assert(accepted == 4 and declined == 1, "both off leave invites alone")

print("automation: ok")
