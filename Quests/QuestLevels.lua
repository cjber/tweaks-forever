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
	tooltip = "An NPC's list of quests and the quest's own title show its level, such as [12].",
	default = true,
	parent = "questLevels",
	conflicts = { { polestar = "qol.questLevels" } },
})

---@param id integer
---@param title string
---@return string
function ns.QuestTitle(id, title)
	if not GetCVarBool("showQuestLevel") or title:match("^%[%d+%+?%]") then
		return title
	end
	local level = C_QuestLog.GetQuestDifficultyLevel(id)
	return level and level > 0 and ("[%d] %s"):format(level, title) or title
end

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

-- The greeting panel's quest buttons, as Blizzard has just laid them out (its own pool; `isActive` says which list).
-- Their text is the game's own format around the title, so only the title inside it changes.
local function LevelGreeting()
	if not ns.Active("questLevelsDialogs") or not GetCVarBool("showQuestLevel") then
		return
	end
	for _, child in ipairs({ QuestFrameGreetingPanel:GetChildren() }) do
		local button = child --[[@as TFGreetingButton]]
		if button.isActive ~= nil and button:IsShown() and button:IsObjectType("Button") then
			local index = button:GetID()
			local title, level
			if button.isActive == 1 then
				title, level = GetActiveTitle(index), GetActiveLevel(index)
			else
				title, level = GetAvailableTitle(index), GetAvailableLevel(index)
			end
			local text = button:GetText()
			local levelled = title and WithLevel(title, level)
			-- Already levelled when the panel shows again without Blizzard redrawing the button.
			if text and title and levelled and levelled ~= title and not text:find(levelled, 1, true) then
				local start, stop = text:find(title, 1, true)
				if start then
					button:SetText(text:sub(1, start - 1) .. levelled .. text:sub(stop + 1))
				end
			end
		end
	end
end

-- The quest's own title on the detail and reward pages, after Blizzard's QuestInfo_Display has set it.
---@param template table?
local function LevelTitle(template)
	if
		not ns.Active("questLevelsDialogs")
		or not (template == QUEST_TEMPLATE_DETAIL or template == QUEST_TEMPLATE_REWARD)
	then
		return
	end
	local id, title = GetQuestID(), QuestInfoTitleHeader:GetText()
	if id and id > 0 and title then
		QuestInfoTitleHeader:SetText(ns.QuestTitle(id, title))
	end
end

-- The client already uses this CVar for its tracker and map pins. Let its own callbacks redraw them.
ns.Init(function()
	local function Apply()
		SetCVar("showQuestLevel", ns.Active("questLevels") and "1" or "0")
	end
	ns.OnSettingChanged("questLevels", Apply)
	Apply()
	QuestFrameGreetingPanel:HookScript("OnShow", LevelGreeting)
	hooksecurefunc("QuestInfo_Display", LevelTitle)
end)
