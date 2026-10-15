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

-- Summons, resurrections and battleground release: guarded, and a popup hidden only once the accept took.
local timers, hidden = {}, {}
env.C_Timer = {
	After = function(delay, fn)
		timers[#timers + 1] = { delay = delay, fn = fn }
	end,
}
env.StaticPopup_Hide = function(name)
	hidden[#hidden + 1] = name
end
local function Tick()
	local due = timers
	timers = {}
	for _, timer in ipairs(due) do
		timer.fn()
	end
	return due
end
local summonLeft, canTeleport, combat, summoned = 60, true, false, 0
env.C_SummonInfo = {
	ConfirmSummon = function()
		summoned = summoned + 1
	end,
	GetSummonConfirmTimeLeft = function()
		return summonLeft
	end,
}
env.PlayerCanTeleport = function()
	return canTeleport
end
env.UnitAffectingCombat = function()
	return combat
end

db.summons = true
handlers.CONFIRM_SUMMON()
assert(summoned == 1, "a summon is accepted")
Tick()
assert(#hidden == 0, "the popup stays while the game still holds the summon")
summonLeft = 0
Tick()
assert(
	table.concat(hidden, ",") == "CONFIRM_SUMMON,CONFIRM_SUMMON_STARTING_AREA,CONFIRM_SUMMON_SCENARIO",
	"and goes once the summon is taken, whichever summon popup the game showed"
)
hidden, summonLeft, summoned = {}, 60, 0
handlers.CONFIRM_SUMMON()
local ticks = 0
while #timers > 0 do
	Tick()
	ticks = ticks + 1
end
assert(summoned == 1 and #hidden == 0, "a refused accept leaves the popup for you")
assert(ticks == 20, "checked for ten seconds, then left")
summoned = 0
canTeleport = false
handlers.CONFIRM_SUMMON()
assert(summoned == 0, "not where you can't teleport from")
canTeleport, combat = true, true
handlers.CONFIRM_SUMMON()
assert(summoned == 0, "not in combat")
combat = false
handlers.PLAYER_REGEN_ENABLED()
assert(summoned == 1, "accepted once the fight ends, if it still stands")
timers, summoned = {}, 0
summonLeft = 0
handlers.PLAYER_REGEN_ENABLED()
assert(summoned == 0, "no summon pending, nothing to accept")
summonLeft, shift = 60, true
handlers.CONFIRM_SUMMON()
shift = false
handlers.PLAYER_REGEN_ENABLED()
assert(summoned == 0, "Shift leaves it to you, even after a fight")
db.summons = false

local offer, delay, offererCombat, resurrected = "Ally", 0, false, 0
env.ResurrectGetOfferer = function()
	return offer
end
env.GetCorpseRecoveryDelay = function()
	return delay
end
env.UnitExists = function(unit)
	return unit == "Ally" or unit == "Other"
end
env.UnitAffectingCombat = function(unit)
	return unit == "Ally" and offererCombat
end
env.AcceptResurrect = function()
	resurrected = resurrected + 1
end
db.resurrections = true
timers, hidden = {}, {}
handlers.RESURRECT_REQUEST("Ally")
assert(resurrected == 1 and #hidden == 0, "a group member's resurrection is accepted; the game closes its popups")
resurrected = 0
delay = 5
handlers.RESURRECT_REQUEST("Ally")
assert(resurrected == 0 and timers[1].delay > 5, "the corpse recovery delay is waited out")
delay = 0
shift = true
Tick()
shift = false
assert(resurrected == 1, "then accepted, Shift then no matter")
timers, resurrected = {}, 0
delay = 5
handlers.RESURRECT_REQUEST("Ally")
offer, delay = "Stranger", 0
Tick()
assert(resurrected == 0, "a different offer standing when the delay ends is not accepted")
offer, delay = "Ally", 5
handlers.RESURRECT_REQUEST("Ally")
offer = "Other"
handlers.RESURRECT_REQUEST("Other")
delay = 0
Tick()
assert(resurrected == 1, "a newer offer replaces the older wait: one accept")
timers, resurrected, offer = {}, 0, "Stranger"
handlers.RESURRECT_REQUEST("Stranger")
assert(resurrected == 0, "not from outside the group")
offer, offererCombat = "Ally", true
handlers.RESURRECT_REQUEST("Ally")
assert(resurrected == 0, "not from someone in combat")
offererCombat, shift = false, true
handlers.RESURRECT_REQUEST("Ally")
assert(resurrected == 0, "Shift leaves it to you")
shift = false
db.resurrections = false

local released = 0
env.IsInInstance = function()
	return true, "pvp"
end
env.UnitIsDead = function()
	return true
end
env.C_DeathInfo = {
	GetSelfResurrectOptions = function()
		return {}
	end,
}
env.RepopMe = function()
	released = released + 1
end
db.releasePvP = true
timers = {}
handlers.PLAYER_DEAD()
Tick()
assert(released == 1, "released in a battleground")
handlers.PLAYER_DEAD()
shift = true
Tick()
assert(released == 1, "Shift held just after dying keeps you where you fell")
handlers.PLAYER_DEAD()
shift = false
Tick()
assert(released == 1, "so does Shift held as you die")
shift = false

do
	-- Duels from friends and guild, and party invites by who sent them.
	assert(not features.duelFriends.default and features.duelFriends.parent == "declineDuels")
	assert(not features.partyFriends.default and not features.partyStrangers.default, "invite options start off")
	local friends, guild, queue = { ["Pal-Home"] = true }, { "Mate-Home" }, "none"
	-- One Battle.net friend on two accounts: Retail first, then this game on another realm.
	local games = {
		{ clientProgram = "WoW", wowProjectID = 1, characterName = "Bob", realmName = "Home" },
		{ clientProgram = "WoW", wowProjectID = 99, characterName = "Buddy", realmName = "Other Realm" },
	}
	env.BNET_CLIENT_WOW, env.WOW_PROJECT_ID = "WoW", 99
	env.GetNormalizedRealmName = function()
		return "Home"
	end
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
		GetFriendNumGameAccounts = function()
			return #games
		end,
		GetFriendGameAccountInfo = function(_, slot)
			return games[slot]
		end,
	}
	env.BNGetNumFriends = function()
		return 1
	end
	env.IsGuildMember = function(guid)
		return guid == "Player-1-MATE"
	end
	env.IsInGuild = function()
		return true
	end
	local rosterAsked = false
	env.C_GuildInfo = {
		GuildRoster = function()
			rosterAsked = true
		end,
	}
	env.GetNumGuildMembers = function()
		return #guild
	end
	env.GetGuildRosterInfo = function(index)
		return guild[index]
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
	local inviteTimers, inviteHidden = {}, {}
	env.C_Timer = {
		After = function(_, fn)
			inviteTimers[#inviteTimers + 1] = fn
		end,
	}
	env.StaticPopup_Hide = function(name)
		inviteHidden[#inviteHidden + 1] = name
	end
	local function InviteTick()
		local due = inviteTimers
		inviteTimers = {}
		for _, fn in ipairs(due) do
			fn()
		end
	end
	local function Clear()
		for index = #inviteHidden, 1, -1 do
			inviteHidden[index] = nil
		end
	end
	local function Invite(name, guid, tank)
		handlers.PARTY_INVITE_REQUEST(name, tank or false, false, false, true, false, guid, false)
	end

	db.declineDuels = true
	handlers.DUEL_REQUESTED("Pal")
	assert(cancelled == 1, "without the exception every duel is declined")
	db.duelFriends = true
	handlers.PLAYER_ENTERING_WORLD()
	assert(rosterAsked, "the guild roster is asked for")
	for _, name in ipairs({ "Pal", "Buddy-OtherRealm", "Mate" }) do
		handlers.DUEL_REQUESTED(name)
	end
	assert(cancelled == 1, "friends, Battle.net friends and guild still ask")
	handlers.DUEL_REQUESTED("Mate-Elsewhere")
	assert(cancelled == 2, "a guildmate's namesake on another realm is declined")
	handlers.DUEL_REQUESTED("Bob")
	assert(cancelled == 3, "a Battle.net friend's character in another game version doesn't count")
	handlers.DUEL_REQUESTED("Stranger")
	assert(cancelled == 4, "a stranger's duel is declined")
	db.declineDuels, db.duelFriends = false, false

	db.partyFriends = true
	Clear()
	Invite("Pal", "Player-1-PAL")
	assert(accepted == 1, "a friend's invite is accepted")
	InviteTick()
	assert(#inviteHidden == 0, "the popup stays until you are in the group")
	inGroup = true
	InviteTick()
	assert(inviteHidden[1] == "PARTY_INVITE", "and goes once grouped")
	inGroup = false
	Invite("Buddy", "Player-1-BUD")
	Invite("Mate", "Player-1-MATE")
	assert(accepted == 3, "a Battle.net friend's and a guildmate's too")
	inviteTimers = {}
	Invite("Pal", "Player-1-PAL", true)
	assert(accepted == 3, "an invite asking for a role is left to you")
	queue = "queued"
	Invite("Pal", "Player-1-PAL")
	assert(accepted == 3, "not while queued for a battleground")
	queue = "none"
	env.WillAcceptInviteRemoveQueues = function()
		return true
	end
	Invite("Pal", "Player-1-PAL")
	assert(accepted == 3, "nor when the game says joining drops a queue")
	env.WillAcceptInviteRemoveQueues = nil
	shift = true
	Invite("Pal", "Player-1-PAL")
	assert(accepted == 3, "Shift leaves it to you")
	shift = false
	Invite("Stranger", "Player-1-X")
	assert(accepted == 3 and declined == 0, "a stranger's invite is left alone without the decline option")
	db.partyStrangers = true
	Clear()
	inviteTimers = {}
	Invite("Stranger", "Player-1-X")
	assert(declined == 1 and #inviteHidden == 0, "a stranger's invite is declined")
	InviteTick()
	assert(inviteHidden[1] == "PARTY_INVITE", "its popup inviteHidden the next frame, after the game showed it")
	shift = true
	Invite("Stranger", "Player-1-X")
	assert(declined == 1, "Shift leaves a stranger's to you too")
	shift = false
	Invite("Pal", "Player-1-PAL")
	assert(declined == 1 and accepted == 4, "a friend's never is declined")
	db.partyFriends, db.partyStrangers = false, false
	inviteTimers = {}
	Invite("Pal", "Player-1-PAL")
	assert(accepted == 4 and declined == 1, "both off leave invites alone")
end

print("automation: ok")
