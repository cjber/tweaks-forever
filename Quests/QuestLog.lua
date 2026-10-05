---@type string, TFNamespace
local _, ns = ...
local L = ns.L

ns.Feature({
	key = "foreverQuests",
	category = "Interface",
	name = "Highlight new Forever quests",
	tooltip = "A soft gold background marks quests added in WoW: Forever in the quest log and quest text.",
	default = true,
	conflicts = { { addon = "ForeverQuestTint" }, { addon = "ForeverQuestTracker" } },
})
ns.Feature({
	key = "bulkAbandon",
	category = "Interface",
	name = "Abandon multiple quests",
	tooltip = "Adds an Abandon quests button to the quest log. Choose quests, then confirm once for the whole selection.",
	default = true,
})

---@class TFQuestLog
local Model = {}
ns.QuestLog = Model

---@return QuestInfo[]
function Model.Entries()
	local entries = {}
	for index = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(index)
		if info and not info.isHeader and not info.isHidden and info.questID > 0 then
			entries[#entries + 1] = info
		end
	end
	return entries
end

---@param id integer
---@return boolean
function Model.CanAbandon(id)
	return (C_QuestLog.GetLogIndexForQuestID(id) or 0) > 0
		and not C_QuestLog.IsQuestDisabledForSession(id)
		and C_QuestLog.CanAbandonQuest(id)
end

-- Snapshot IDs, never log indices: removing a quest changes every later index.
---@param selected table<integer, boolean>
---@return integer[]
function Model.Selection(selected)
	local ids = {}
	for _, info in ipairs(Model.Entries()) do
		if selected[info.questID] and Model.CanAbandon(info.questID) then
			ids[#ids + 1] = info.questID
		end
	end
	return ids
end

---@param ids integer[]
function Model.Abandon(ids)
	if InCombatLockdown() then
		return
	end
	local previous = C_QuestLog.GetSelectedQuest()
	for _, id in ipairs(ids) do
		if Model.CanAbandon(id) then
			C_QuestLog.SetSelectedQuest(id)
			C_QuestLog.SetAbandonQuest()
			C_QuestLog.AbandonQuest()
		end
	end
	if previous and (C_QuestLog.GetLogIndexForQuestID(previous) or 0) > 0 then
		C_QuestLog.SetSelectedQuest(previous)
	end
end

ns.Init(function()
	---@type table<Frame, Texture>
	local tints = {}
	---@param frame Frame?
	---@param id integer?
	local function Tint(frame, id)
		if not frame then
			return
		end
		local show = ns.Active("foreverQuests") and id and ns.ForeverQuests[id]
		local texture = tints[frame]
		if show and not texture then
			texture = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
			texture:SetAllPoints()
			texture:SetColorTexture(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 0.08)
			tints[frame] = texture
		end
		if texture then
			texture:SetShown(not not show)
		end
	end
	local function RefreshTint()
		for _, texture in pairs(tints) do
			texture:Hide()
		end
		if QuestScrollFrame and QuestScrollFrame.titleFramePool then
			for button in QuestScrollFrame.titleFramePool:EnumerateActive() do
				Tint(button, button.questID)
			end
		end
		Tint(QuestMapFrame.DetailsFrame.ScrollFrame.Contents, QuestMapFrame.DetailsFrame.questID)
		Tint(QuestLogPopupDetailFrame, QuestLogPopupDetailFrame.questID)
		Tint(QuestFrameDetailPanel, QuestFrame:IsShown() and GetQuestID() or nil)
	end
	hooksecurefunc("QuestLogQuests_Update", RefreshTint)
	hooksecurefunc("QuestMapFrame_ShowQuestDetails", RefreshTint)
	QuestLogPopupDetailFrame:HookScript("OnShow", RefreshTint)
	QuestFrameDetailPanel:HookScript("OnShow", RefreshTint)
	ns.On("QUEST_DETAIL", function()
		C_Timer.After(0, RefreshTint)
	end)
	ns.OnSettingChanged("foreverQuests", RefreshTint)

	local panel = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
	panel:SetSize(380, 460)
	panel:SetPoint("CENTER")
	panel:SetFrameStrata("DIALOG")
	panel:Hide()
	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", 0, -7)
	title:SetText(L["Abandon quests"])
	local selected, page = {}, 1
	local pending ---@type integer[]?
	local rows = {} ---@type CheckButton[]
	local PAGE_SIZE = 10
	local Refresh
	---@param text string
	---@param x number
	---@param y number
	---@param width number
	---@param click function
	local function Button(text, x, y, width, click)
		local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		button:SetSize(width, 24)
		button:SetPoint("TOPLEFT", x, y)
		button:SetText(text)
		button:SetScript("OnClick", click)
		return button
	end
	Button(L["Select all"], 16, -34, 110, function()
		for _, info in ipairs(Model.Entries()) do
			selected[info.questID] = Model.CanAbandon(info.questID)
		end
		pending = nil
		Refresh()
	end)
	Button(L["Clear selection"], 132, -34, 130, function()
		selected, pending = {}, nil
		Refresh()
	end)
	local note = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	note:SetPoint("TOPLEFT", 18, -368)
	note:SetSize(344, 42)
	note:SetJustifyH("LEFT")
	local abandon = Button(L["Abandon selected"], 16, -420, 210, function()
		if pending then
			Model.Abandon(pending)
			selected, pending = {}, nil
		else
			pending = Model.Selection(selected)
		end
		Refresh()
	end)
	Button(L["Cancel"], 242, -420, 120, function()
		panel:Hide()
	end)
	Button(L["Previous"], 16, -334, 110, function()
		page = math.max(1, page - 1)
		Refresh()
	end)
	Button(L["Next"], 252, -334, 110, function()
		page = page + 1
		Refresh()
	end)
	local pages = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	pages:SetPoint("TOP", 0, -340)
	for index = 1, PAGE_SIZE do
		local row = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
		row:SetSize(26, 26)
		row:SetHitRectInsets(0, -312, 0, 0)
		row:SetPoint("TOPLEFT", 16, -64 - (index - 1) * 26)
		local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("LEFT", row, "RIGHT", 2, 0)
		label:SetWidth(310)
		label:SetJustifyH("LEFT")
		row:SetFontString(label)
		row:SetScript("OnClick", function()
			local info = Model.Entries()[(page - 1) * PAGE_SIZE + index]
			if info then
				selected[info.questID] = row:GetChecked()
			end
			pending = nil
			Refresh()
		end)
		rows[index] = row
	end
	Refresh = function()
		local entries = Model.Entries()
		local count = math.max(1, math.ceil(#entries / PAGE_SIZE))
		page = math.min(page, count)
		pages:SetText(PAGE_NUMBER_WITH_MAX:format(page, count))
		for index, row in ipairs(rows) do
			local info = entries[(page - 1) * PAGE_SIZE + index]
			row:SetShown(info ~= nil)
			if info then
				row:SetText(ns.QuestTitle(info.questID, info.title))
				row:SetChecked(not not selected[info.questID])
				row:SetEnabled(not InCombatLockdown() and Model.CanAbandon(info.questID))
				Tint(row, info.questID)
			end
		end
		local ids = Model.Selection(selected)
		abandon:SetEnabled(#ids > 0 and not InCombatLockdown())
		abandon:SetText(
			pending and L["Confirm abandon (%d)"]:format(#pending) or L["Abandon selected (%d)"]:format(#ids)
		)
		note:SetText(
			pending and L["Abandon these quests? Their progress and associated quest items will be lost."]
				or L["Choose quests to abandon. Nothing is removed until you confirm."]
		)
	end
	panel:SetScript("OnHide", function()
		selected, pending, page = {}, nil, 1
	end)
	panel:SetScript("OnShow", Refresh)
	-- Parented to the list itself, which the world map hides while a quest's details are shown: the button goes
	-- with it, rather than sitting over the details page.
	local open = CreateFrame("Button", nil, QuestScrollFrame, "UIPanelButtonTemplate")
	open:SetFrameLevel(QuestScrollFrame:GetFrameLevel() + 1)
	open:SetSize(140, 22)
	open:SetPoint("BOTTOM", 0, 4)
	open:SetText(L["Abandon quests"])
	open:SetScript("OnClick", function()
		panel:SetShown(not panel:IsShown())
	end)
	local function Setting()
		open:SetShown(ns.Active("bulkAbandon"))
		if not ns.Active("bulkAbandon") then
			panel:Hide()
		end
	end
	ns.OnSettingChanged("bulkAbandon", Setting)
	for _, event in ipairs({ "QUEST_LOG_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
		ns.On(event, function()
			pending = nil
			if panel:IsShown() then
				Refresh()
			end
		end)
	end
	Setting()
	RefreshTint()
end)
