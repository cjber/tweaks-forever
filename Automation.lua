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
	name = "Accept and turn in quests automatically",
	tooltip = "Hold Shift while talking to skip it. A quest with a choice of rewards is left for you to pick.",
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
	},
})

ns.Feature({
	key = "gossip",
	category = "Automation",
	name = "Skip gossip with a single option",
	tooltip = "Goes straight to the only thing an NPC offers (vendor, trainer, flight map). Hold Shift to see it.",
	default = false,
	conflicts = { Leatrix("AutomateGossip") },
})

ns.Feature({
	key = "summons",
	category = "Automation",
	name = "Accept summons",
	tooltip = "Not while you are in combat.",
	default = false,
	conflicts = { Leatrix("AutoAcceptSummon") },
})

ns.Feature({
	key = "resurrections",
	category = "Automation",
	name = "Accept resurrections",
	tooltip = "From your group, and not from someone in combat, so a battle resurrection is still yours to time.",
	default = false,
	conflicts = { Leatrix("AutoAcceptRes") },
})

ns.Feature({
	key = "releasePvP",
	category = "Automation",
	name = "Release your spirit in battlegrounds",
	tooltip = "Unless you can resurrect yourself (a soulstone or Reincarnation).",
	default = false,
	conflicts = { Leatrix("AutoReleasePvP") },
})

ns.Feature({
	key = "declineDuels",
	category = "Automation",
	name = "Decline duels",
	default = false,
	conflicts = { Leatrix("NoDuelRequests") },
})

ns.Feature({
	key = "fastLoot",
	category = "Automation",
	name = "Faster auto loot",
	tooltip = "Takes everything at once instead of waiting for the loot window. Only while auto loot applies.",
	default = true,
	conflicts = { Leatrix("FasterLooting"), { addon = "SpeedyAutoLoot" }, { addon = "AutoLootPlus" } },
})

local function Quests()
	return ns.Active("quests") and not IsShiftKeyDown()
end

-- Completed quests first, then new ones, one per window: each pick reopens the NPC's list.
local function PickGossipQuest()
	for _, quest in ipairs(C_GossipInfo.GetActiveQuests()) do
		if quest.isComplete then
			C_GossipInfo.SelectActiveQuest(quest.questID)
			return true
		end
	end
	for _, quest in ipairs(C_GossipInfo.GetAvailableQuests()) do
		if not quest.isTrivial then
			C_GossipInfo.SelectAvailableQuest(quest.questID)
			return true
		end
	end
	return false
end

-- The game already skips an option it flags (selectOptionWhenOnlyOption); this extends that to any lone option.
local function SkipGossip()
	local options = C_GossipInfo.GetOptions()
	if
		#options ~= 1
		or C_GossipInfo.GetNumAvailableQuests() > 0
		or C_GossipInfo.GetNumActiveQuests() > 0
		or C_GossipInfo.ForceGossip()
	then
		return
	end
	local option = options[1]
	if option.status == Enum.GossipOptionStatus.Available and not option.selectOptionWhenOnlyOption then
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
		local isTrivial = GetAvailableQuestInfo(index)
		if not isTrivial then
			-- Forever's quest greeting takes an index; Ketho's legacy signature omits it.
			---@diagnostic disable-next-line: redundant-parameter
			SelectAvailableQuest(index)
			return
		end
	end
end)

ns.On("QUEST_DETAIL", function()
	if Quests() then
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

ns.On("QUEST_COMPLETE", function()
	local choices = GetNumQuestChoices()
	if Quests() and choices <= 1 then
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

ns.On("DUEL_REQUESTED", function()
	if ns.Active("declineDuels") then
		CancelDuel()
		StaticPopup_Hide("DUEL_REQUESTED")
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
