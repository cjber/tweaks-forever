---@type string, TFNamespace
local _, ns = ...

ns.Feature({
	key = "questLevels",
	category = "Interface",
	name = "Show quest levels",
	tooltip = "Shows quest levels in the tracker, on map quest tooltips, and beside quest names added by Tweaks Forever.",
	default = true,
})

ns.Feature({
	key = "questLevelsDialogs",
	category = "Interface",
	name = "In quest dialogs too",
	tooltip = "The quest greeting's list (an NPC or board with only quests) and the quest's own title on its detail "
		.. "and reward pages show its level, such as [12].",
	default = true,
	parent = "questLevels",
	conflicts = { { polestar = "qol.questLevels" } },
})

-- `title` with `level` in front, as the tracker shows it; unchanged when the level is unknown or already there.
---@param title string
---@param level number?
---@return string
local function WithLevel(title, level)
	if not level or level <= 0 or title:match("^%[%d+%+?%]") then
		return title
	end
	return ("[%d] %s"):format(level, title)
end

---@param id integer
---@param title string
---@return string
function ns.QuestTitle(id, title)
	if not GetCVarBool("showQuestLevel") then
		return title
	end
	return WithLevel(title, C_QuestLog.GetQuestDifficultyLevel(id))
end

-- Levels the NPC's own lists gave, by quest ID: the log API knows only quests in your log, and a detail page is
-- mostly for one you haven't taken yet.
---@type table<integer, number>
local offered = {}

local function Dialogs()
	return ns.Active("questLevelsDialogs") and GetCVarBool("showQuestLevel")
end

-- The greeting panel's quest buttons, as Blizzard has just laid them out (its own pool; `isActive` says which
-- list). Their text is the game's own format around the title, so only the title inside it changes, and each button
-- is resized as Blizzard sizes it, in case the title now wraps.
local function LevelGreeting()
	if not Dialogs() then
		return
	end
	for _, child in ipairs({ QuestFrameGreetingPanel:GetChildren() }) do
		local button = child --[[@as TFGreetingButton]]
		if button.isActive ~= nil and button:IsShown() and button:IsObjectType("Button") then
			local index = button:GetID()
			local title, level, id
			if button.isActive == 1 then
				title, level, id = GetActiveTitle(index), GetActiveLevel(index), GetActiveQuestID(index)
			else
				local _, _, _, _, questID = GetAvailableQuestInfo(index)
				title, level, id = GetAvailableTitle(index), GetAvailableLevel(index), questID
			end
			if id and level and level > 0 then
				offered[id] = level
			end
			local text = button:GetText()
			local levelled = title and WithLevel(title, level)
			local start, stop
			-- A list redrawn without Blizzard resetting a button's text is already levelled.
			if text and title and levelled and levelled ~= title and not text:find(levelled, 1, true) then
				start, stop = text:find(title, 1, true)
			end
			if start and stop and levelled then
				button:SetText(text:sub(1, start - 1) .. levelled .. text:sub(stop + 1))
				local icon = button.Icon
				button:SetHeight(math.max(button:GetTextHeight() + 2, icon and icon:GetHeight() or 0))
			end
		end
	end
end

-- The gossip window's quests carry their level too.
local function RememberGossip()
	for _, quest in ipairs(C_GossipInfo.GetAvailableQuests()) do
		if quest.questID and quest.questLevel and quest.questLevel > 0 then
			offered[quest.questID] = quest.questLevel
		end
	end
end

-- The quest's own title on the detail and reward pages, after Blizzard's QuestInfo_Display has set it.
---@param template table?
local function LevelTitle(template)
	if not Dialogs() or not (template == QUEST_TEMPLATE_DETAIL or template == QUEST_TEMPLATE_REWARD) then
		return
	end
	local id, title = GetQuestID(), QuestInfoTitleHeader:GetText()
	if id and id > 0 and title then
		QuestInfoTitleHeader:SetText(WithLevel(title, offered[id] or C_QuestLog.GetQuestDifficultyLevel(id)))
	end
end

-- The client already uses this CVar for its tracker and map pins. Let its own callbacks redraw them.
ns.Init(function()
	local function Apply()
		SetCVar("showQuestLevel", ns.Active("questLevels") and "1" or "0")
	end
	ns.OnSettingChanged("questLevels", Apply)
	Apply()
	-- Blizzard calls this on show and again on every QUEST_LOG_UPDATE while the greeting is open.
	hooksecurefunc("QuestFrameGreetingPanel_OnShow", LevelGreeting)
	hooksecurefunc("QuestInfo_Display", LevelTitle)
	ns.On("GOSSIP_SHOW", RememberGossip)
end)
