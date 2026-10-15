---@type string, TFNamespace
local _, ns = ...

-- Things the game asks you to click through. Each acts only while its feature is on and not already handled
-- by another addon; holding Shift skips quest and gossip automation for that window.

local function Leatrix(key)
	return {
		addon = "Leatrix_Plus",
		when = function()
			return LeaPlusDB and LeaPlusDB[key] == "On"
		end,
	}
end

ns.Feature({
	key = "quests",
	category = "Automation",
	name = "Accept and turn in quests",
	tooltip = "Quests are accepted and turned in for you as you talk to an NPC. Hold Shift while talking to skip "
		.. "it. A quest with a choice of rewards is left for you to pick, and so is one that flags you for PvP or "
		.. "costs gold to hand in.",
	default = false,
	conflicts = {
		Leatrix("AutomateQuests"),
		{
			addon = "Questie",
			when = function()
				local profile = Questie and Questie.db and Questie.db.profile
				return profile and (profile.autoaccept or profile.autocomplete)
			end,
		},
		{ addon = "AutoTurnIn" },
		{ polestar = "behavior.autoAccept" },
		{ polestar = "behavior.autoTurnin" },
	},
})

ns.Feature({
	key = "gossip",
	category = "Automation",
	name = "Skip single-option gossip",
	tooltip = "Goes straight to the only thing an NPC offers, or a flight master's flight map. Hold Shift to see it.",
	default = false,
	conflicts = { Leatrix("AutomateGossip"), { polestar = "qol.skipGossip" } },
})

ns.Feature({
	key = "summons",
	category = "Automation",
	name = "Accept summons",
	tooltip = "Not while you are in combat.",
	default = false,
	conflicts = { Leatrix("AutoAcceptSummon"), { polestar = "qol.acceptSummon" } },
})

ns.Feature({
	key = "resurrections",
	category = "Automation",
	name = "Accept resurrections",
	tooltip = "From your group, and not from someone in combat, so a battle resurrection is still yours to time.",
	default = false,
	conflicts = { Leatrix("AutoAcceptRes"), { polestar = "qol.acceptResurrect" } },
})

ns.Feature({
	key = "releasePvP",
	category = "Automation",
	name = "Release in battlegrounds",
	tooltip = "Releases your spirit as soon as you die in a battleground, unless you can resurrect yourself (a "
		.. "soulstone or Reincarnation).",
	default = false,
	conflicts = { Leatrix("AutoReleasePvP"), { polestar = "qol.autoReleasePvP" } },
})

ns.Feature({
	key = "declineDuels",
	category = "Automation",
	name = "Decline duels",
	default = false,
	conflicts = { Leatrix("NoDuelRequests"), { polestar = "qol.declineDuels" } },
})

ns.Feature({
	key = "duelFriends",
	category = "Automation",
	name = "Except friends and guild",
	tooltip = "Duels from your friends, Battle.net friends and guild still ask you.",
	default = false,
	parent = "declineDuels",
})

ns.Feature({
	key = "partyFriends",
	category = "Automation",
	name = "Accept party invites from friends",
	tooltip = "From your friends, Battle.net friends and guild. Not while you are queued for a battleground, since "
		.. "joining could take you out of the queue. Hold Shift to answer it yourself.",
	default = false,
	conflicts = { Leatrix("AcceptPartyFriends"), { polestar = "qol.acceptPartyFriends" } },
})

ns.Feature({
	key = "partyStrangers",
	category = "Automation",
	name = "Decline party invites from strangers",
	tooltip = "Invites from anyone who isn't your friend, Battle.net friend or in your guild are declined.",
	default = false,
	conflicts = { Leatrix("NoPartyInvites"), { polestar = "qol.declinePartyStrangers" } },
})

ns.Feature({
	key = "fastLoot",
	category = "Automation",
	name = "Faster auto loot",
	tooltip = "Takes everything at once instead of waiting for the loot window. Only while auto loot applies.",
	default = true,
	conflicts = {
		Leatrix("FasterLooting"),
		{ addon = "SpeedyAutoLoot" },
		{ addon = "AutoLootPlus" },
		{ polestar = "qol.fastLoot" },
	},
})

local function Quests()
	return ns.Active("quests") and not IsShiftKeyDown()
end

-- Quests left open this session because they flag you for PvP, by quest ID, so the NPC's list goes on to the next
-- quest instead of opening the same one again.
local leftForYou = {}

-- Completed quests first, then new ones, one per window: each pick reopens the NPC's list.
local function PickGossipQuest()
	for _, quest in ipairs(C_GossipInfo.GetActiveQuests()) do
		if quest.isComplete then
			C_GossipInfo.SelectActiveQuest(quest.questID)
			return true
		end
	end
	for _, quest in ipairs(C_GossipInfo.GetAvailableQuests()) do
		if not quest.isTrivial and not leftForYou[quest.questID] then
			C_GossipInfo.SelectAvailableQuest(quest.questID)
			return true
		end
	end
	return false
end

-- The server sends each option's type and the game draws its icon from it, so every taxi option carries this
-- icon (Interface\GossipFrame\TaxiGossipIcon) whatever its text or language.
local TAXI_ICON = 132057

-- A lone option, or a flight master's taxi among several. The game already selects a lone option it flags
-- (selectOptionWhenOnlyOption) unless the NPC forces gossip, and selecting it again would repeat the request.
local function GossipOption(options)
	if #options == 1 and not C_GossipInfo.ForceGossip() then
		return not options[1].selectOptionWhenOnlyOption and options[1] or nil
	end
	for _, option in ipairs(options) do
		if option.icon == TAXI_ICON then
			return option
		end
	end
	return nil
end

local function SkipGossip()
	if C_GossipInfo.GetNumAvailableQuests() > 0 or C_GossipInfo.GetNumActiveQuests() > 0 then
		return
	end
	local option = GossipOption(C_GossipInfo.GetOptions())
	if option and option.status == Enum.GossipOptionStatus.Available then
		C_GossipInfo.SelectOptionByIndex(option.orderIndex)
	end
end

ns.On("GOSSIP_SHOW", function()
	if Quests() and PickGossipQuest() then
		return
	end
	if ns.Active("gossip") and not IsShiftKeyDown() then
		SkipGossip()
	end
end)

ns.On("QUEST_GREETING", function()
	if not Quests() then
		return
	end
	for index = 1, GetNumActiveQuests() do
		local _, isComplete = GetActiveTitle(index)
		if isComplete then
			-- Forever's quest greeting takes an index; Ketho's legacy signature omits it.
			---@diagnostic disable-next-line: redundant-parameter
			SelectActiveQuest(index)
			return
		end
	end
	for index = 1, GetNumAvailableQuests() do
		local isTrivial, _, _, _, questID = GetAvailableQuestInfo(index)
		if not isTrivial and not leftForYou[questID] then
			-- Forever's quest greeting takes an index; Ketho's legacy signature omits it.
			---@diagnostic disable-next-line: redundant-parameter
			SelectAvailableQuest(index)
			return
		end
	end
end)

-- One the server has already accepted (an item that starts a quest) only needs acknowledging; Blizzard closes an
-- area's own and offers it in a popup. A quest that flags you for PvP waits for you to accept it. The auto-accept
-- calls are guarded: Ketho lists them for retail only.
ns.On("QUEST_DETAIL", function()
	if not Quests() then
		return
	end
	if QuestGetAutoAccept and QuestGetAutoAccept() then
		if AcknowledgeAutoAcceptQuest and not (QuestIsFromAreaTrigger and QuestIsFromAreaTrigger()) then
			AcknowledgeAutoAcceptQuest()
		end
	elseif QuestFlagsPVP() then
		leftForYou[GetQuestID()] = true
	else
		AcceptQuest()
	end
end)

-- An escort or group quest someone else started.
ns.On("QUEST_ACCEPT_CONFIRM", function()
	if Quests() then
		ConfirmAcceptQuest()
		StaticPopup_Hide("QUEST_ACCEPT")
	end
end)

ns.On("QUEST_PROGRESS", function()
	if Quests() and IsQuestCompletable() then
		CompleteQuest()
	end
end)

-- A hand-in that costs gold waits for you to pay it.
ns.On("QUEST_COMPLETE", function()
	local choices = GetNumQuestChoices()
	if Quests() and choices <= 1 and (GetQuestMoneyToGet() or 0) <= 0 then
		GetQuestReward(choices)
	end
end)

ns.On("CONFIRM_SUMMON", function()
	if ns.Active("summons") and not UnitAffectingCombat("player") then
		C_SummonInfo.ConfirmSummon()
		StaticPopup_Hide("CONFIRM_SUMMON")
	end
end)

-- The event names the offerer, and a name resolves to a unit only for a group member; anyone
-- else's combat state is unknown, so their resurrection waits for a click.
ns.On("RESURRECT_REQUEST", function(offerer)
	if ns.Active("resurrections") and UnitExists(offerer) and not UnitAffectingCombat(offerer) then
		AcceptResurrect()
		StaticPopup_Hide("RESURRECT")
		StaticPopup_Hide("RESURRECT_NO_SICKNESS")
		StaticPopup_Hide("RESURRECT_NO_TIMER")
	end
end)

ns.On("PLAYER_DEAD", function()
	local _, instanceType = IsInInstance()
	if not (ns.Active("releasePvP") and instanceType == "pvp") then
		return
	end
	-- The release popup and any self-resurrection options arrive just after the event.
	C_Timer.After(0.5, function()
		if UnitIsDead("player") and #C_DeathInfo.GetSelfResurrectOptions() == 0 then
			RepopMe()
		end
	end)
end)

-- Whether a player is your friend, Battle.net friend or guildmate. An invite carries the inviter's GUID; a duel
-- request only a name, matched against the friends list, Battle.net friends' characters and the guild roster.
---@param name string?
---@param guid string?
---@return boolean
local function Known(name, guid)
	if guid and guid ~= "" then
		local account = C_BattleNet.GetAccountInfoByGUID(guid)
		return C_FriendList.IsFriend(guid) or IsGuildMember(guid) or (account and account.isFriend) or false
	end
	if not name then
		return false
	end
	local short = Ambiguate(name, "none")
	if C_FriendList.GetFriendInfo(short) then
		return true
	end
	for index = 1, BNGetNumFriends() do
		local account = C_BattleNet.GetFriendAccountInfo(index)
		local game = account and account.gameAccountInfo
		if game and game.characterName and Ambiguate(game.characterName, "none") == short then
			return true
		end
	end
	if IsInGuild() then
		for index = 1, GetNumGuildMembers() do
			local member = GetGuildRosterInfo(index)
			if member and Ambiguate(member, "none") == short then
				return true
			end
		end
	end
	return false
end

ns.On("DUEL_REQUESTED", function(challenger)
	if ns.Active("declineDuels") and not (ns.Active("duelFriends") and Known(challenger)) then
		CancelDuel()
		StaticPopup_Hide("DUEL_REQUESTED")
	end
end)

-- In a battleground queue, or invited into one: joining a group can drop you from it.
local function Queued()
	for index = 1, GetMaxBattlefieldID() do
		local status = GetBattlefieldStatus(index)
		if status == "queued" or status == "confirm" then
			return true
		end
	end
	return false
end

ns.On("PARTY_INVITE_REQUEST", function(inviter, _, _, _, _, _, guid)
	local known = Known(inviter, guid)
	if known and ns.Active("partyFriends") and not IsShiftKeyDown() and not Queued() then
		AcceptGroup()
		-- The popup goes once you are in the group; a refused accept leaves it for you.
		C_Timer.After(0.5, function()
			if IsInGroup() then
				StaticPopup_Hide("PARTY_INVITE")
			end
		end)
	elseif not known and ns.Active("partyStrangers") then
		DeclineGroup()
		StaticPopup_Hide("PARTY_INVITE")
	end
end)

ns.On("LOOT_READY", function(autoLoot)
	if not (ns.Active("fastLoot") and autoLoot) then
		return
	end
	for slot = GetNumLootItems(), 1, -1 do
		LootSlot(slot)
	end
end)
