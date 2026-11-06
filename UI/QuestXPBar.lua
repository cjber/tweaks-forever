---@type string, TFNamespace
local _, ns = ...
local L = ns.L

local KEY = "questXPBar"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Quest XP on the experience bar",
	tooltip = "Draws the XP of the quests in your log on the experience bar: the quests ready to hand in from "
		.. "where your XP is now, then the rest of the log fainter after them. Pointing at the bar adds both "
		.. "totals and the level they reach.",
	default = false,
	conflicts = {
		{ addon = "Dominos_Progress", title = "Dominos" },
	},
})

-- XP needed to advance from each level, 1 to 60: the original game's table (warcraft.wiki.gg, Experience to level,
-- Vanilla / Classic table). A quest log can carry more than one level's worth, so the tooltip walks these.
local LEVEL_XP = {
	400,
	900,
	1400,
	2100,
	2800,
	3600,
	4500,
	5400,
	6500,
	7600,
	8800,
	10100,
	11400,
	12900,
	14400,
	16000,
	17700,
	19400,
	21300,
	23200,
	25200,
	27300,
	29400,
	31700,
	34000,
	36400,
	38800,
	41400,
	44300,
	47400,
	50800,
	54500,
	58600,
	62800,
	67100,
	71600,
	76100,
	80800,
	85700,
	90700,
	95800,
	101000,
	106300,
	111800,
	117500,
	123200,
	129100,
	135100,
	141200,
	147500,
	153900,
	160400,
	167100,
	173900,
	180800,
	187900,
	195000,
	202300,
	209800,
	217400,
}

-- How often the bar catches up with a burst of quest log and XP events, in seconds.
local THROTTLE = 0.25
-- The bar's own fill art, recoloured gold: the experience fill for the quests ready to hand in, and the
-- prediction fill the game uses for rested XP, fainter, for the rest of the log.
local COMPLETED_ATLAS, PENDING_ATLAS = "UI-HUD-ExperienceBar-Fill-Experience", "UI-HUD-ExperienceBar-Fill-Prediction"
local COMPLETED_ALPHA, PENDING_ALPHA = 0.9, 0.45
local GOLD_R, GOLD_G, GOLD_B = 1, 0.82, 0.05

---@class TFQuestXPBar
local Model = {}
ns.QuestXPBar = Model

-- How much of the bar is filled by `value` of `max`, never past either end.
---@param value number
---@param max number
---@return number
local function Fraction(value, max)
	if max <= 0 then
		return 0
	end
	return math.max(0, math.min(1, value / max))
end

-- Where the current XP ends, where the completed quests end and where the whole quest log ends, as fractions of
-- the bar. Both quest totals stop at the end of the bar; the tooltip carries the overflow.
---@param xp number
---@param max number
---@param completed number
---@param pending number
---@return number current, number completedEnd, number allEnd
function Model.Segments(xp, max, completed, pending)
	local current = Fraction(xp, max)
	local completedEnd = math.min(1, current + Fraction(completed, max))
	local allEnd = math.min(1, completedEnd + Fraction(pending, max))
	return current, completedEnd, allEnd
end

-- XP from the quests ready to hand in, and from the rest of the log. Quests with no reward XP add nothing.
---@param entries { xp: number, complete: boolean }[]
---@return number completed, number pending
function Model.Totals(entries)
	local completed, pending = 0, 0
	for _, entry in ipairs(entries) do
		if entry.xp and entry.xp > 0 then
			if entry.complete then
				completed = completed + entry.xp
			else
				pending = pending + entry.xp
			end
		end
	end
	return completed, pending
end

-- The level and percentage within it that `gained` XP from `level` reaches. Past the last level, the cap and 100%.
---@param level number
---@param xp number
---@param gained number
---@param maxLevel number
---@return number reached, number percent
function Model.Reach(level, xp, gained, maxLevel)
	local reached = level
	local into = xp + gained
	while reached < maxLevel do
		local need = LEVEL_XP[reached]
		if not need or need <= 0 or into < need then
			break
		end
		into = into - need
		reached = reached + 1
	end
	if reached >= maxLevel then
		return maxLevel, 100
	end
	local need = LEVEL_XP[reached]
	if not need or need <= 0 then
		return reached, 0
	end
	return reached, math.floor(into / need * 100 + 0.5)
end

-- Nothing shows at the level cap or while the game has the bar hidden.
---@param level number
---@param maxLevel number
---@param barVisible boolean
---@return boolean hidden
function Model.Hidden(level, maxLevel, barVisible)
	return not barVisible or maxLevel <= 0 or level >= maxLevel
end

-- Every quest in the log with a reward, as { xp, complete }.
---@return { xp: number, complete: boolean }[]
function Model.Entries()
	local entries = {}
	for index = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(index)
		if info and info.questID > 0 and not info.isHeader then
			local reward = GetQuestLogRewardXP(info.questID)
			local xp = type(reward) == "number" and reward or 0
			if xp > 0 then
				entries[#entries + 1] = { xp = xp, complete = C_QuestLog.IsComplete(info.questID) }
			end
		end
	end
	return entries
end

-- The two totals from the quest log now.
---@return number completed, number pending
function Model.Read()
	return Model.Totals(Model.Entries())
end

ns.Init(function()
	local bars = {}
	local experience = StatusTrackingBarInfo and StatusTrackingBarInfo.BarsEnum.Experience
	for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
		local bar = experience and container and container.bars and container.bars[experience]
		if bar then
			bars[#bars + 1] = bar
		end
	end
	if #bars == 0 then
		return
	end

	-- Our own frame and two textures over the game's bar; the bar itself is only read.
	local overlay = CreateFrame("Frame", nil, UIParent)
	overlay:SetFrameStrata("LOW")
	overlay:Hide()
	local completedTexture = overlay:CreateTexture(nil, "ARTWORK")
	completedTexture:SetAtlas(COMPLETED_ATLAS) -- art-ok: a bar fill stretched over a span of the bar, as the game draws it
	completedTexture:SetDesaturated(true)
	completedTexture:SetVertexColor(GOLD_R, GOLD_G, GOLD_B, COMPLETED_ALPHA)
	completedTexture:Hide()
	local pendingTexture = overlay:CreateTexture(nil, "ARTWORK")
	pendingTexture:SetAtlas(PENDING_ATLAS) -- art-ok: the game's own prediction fill, stretched the same way
	pendingTexture:SetDesaturated(true)
	pendingTexture:SetVertexColor(GOLD_R, GOLD_G, GOLD_B, PENDING_ALPHA)
	pendingTexture:Hide()

	local current, completedEnd, allEnd = 0, 0, 0
	local bar, scheduled, deferred = nil, false, false

	-- A segment from `from` to `to` of the bar, in the overlay's own width.
	---@param texture Texture
	---@param from number
	---@param to number
	local function Segment(texture, from, to)
		texture:ClearAllPoints()
		local width = overlay:GetWidth()
		if to <= from or width <= 0 then
			texture:Hide()
			return
		end
		texture:SetPoint("TOPLEFT", overlay, "TOPLEFT", from * width, 0)
		texture:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", from * width, 0)
		texture:SetWidth((to - from) * width)
		texture:Show()
	end

	local function Layout()
		Segment(completedTexture, current, completedEnd)
		Segment(pendingTexture, completedEnd, allEnd)
	end

	local function VisibleBar()
		for _, candidate in ipairs(bars) do
			if candidate:IsVisible() then
				return candidate
			end
		end
	end

	local function Hide()
		overlay:Hide()
		bar = nil
	end

	local function Update()
		scheduled = false
		local shown = VisibleBar()
		local level = UnitLevel("player")
		local maxLevel = GetMaxLevelForPlayerExpansion()
		if not ns.Active(KEY) or not shown or Model.Hidden(level, maxLevel, shown:IsVisible()) then
			Hide()
			return
		end
		-- The game's bar is protected: wait for combat to end before laying anything over it.
		if shown:IsProtected() and InCombatLockdown() then
			deferred = true
			return
		end
		deferred = false
		local max = UnitXPMax("player")
		if max <= 0 then
			Hide()
			return
		end
		local completed, pending = Model.Read()
		if completed <= 0 and pending <= 0 then
			Hide()
			return
		end
		current, completedEnd, allEnd = Model.Segments(UnitXP("player"), max, completed, pending)
		if bar ~= shown then
			bar = shown
			overlay:ClearAllPoints()
			overlay:SetAllPoints(shown.StatusBar)
			overlay:SetFrameLevel(shown:GetFrameLevel() + 2)
		end
		overlay:Show()
		Layout()
	end

	local function Refresh()
		if scheduled then
			return
		end
		scheduled = true
		C_Timer.After(THROTTLE, function()
			ns.SafeCall("quest XP bar", Update)
		end)
	end

	overlay:SetScript("OnSizeChanged", function()
		Layout()
	end)

	for _, candidate in ipairs(bars) do
		candidate:HookScript("OnShow", Refresh)
		candidate:HookScript("OnHide", Refresh)
		candidate:HookScript("OnEnter", function()
			if not ns.Usable(GameTooltip) then
				return
			end
			if not ns.Active(KEY) or not GameTooltip:IsShown() or GameTooltip:GetOwner() ~= UIParent then
				return
			end
			local level = UnitLevel("player")
			local maxLevel = GetMaxLevelForPlayerExpansion()
			if Model.Hidden(level, maxLevel, true) then
				return
			end
			local completed, pending = Model.Read()
			local total = completed + pending
			local reached, percent = Model.Reach(level, UnitXP("player"), total, maxLevel)
			GameTooltip:AddLine(L["Completed quests: %s XP"]:format(BreakUpLargeNumbers(completed)), 1, 1, 1)
			GameTooltip:AddLine(
				L["All quests in log: %s XP (reaches level %d, %d%%)"]:format(
					BreakUpLargeNumbers(total),
					reached,
					percent
				),
				1,
				1,
				1
			)
			GameTooltip:Show()
		end)
	end

	Update()
	ns.OnSettingChanged(KEY, Update)
	hooksecurefunc(ns, "RefreshConflicts", Update)
	ns.On("QUEST_LOG_UPDATE", Refresh)
	ns.On("QUEST_TURNED_IN", Refresh)
	ns.On("PLAYER_XP_UPDATE", Refresh)
	ns.On("PLAYER_LEVEL_UP", Refresh)
	ns.On("UPDATE_EXHAUSTION", Refresh)
	ns.On("PLAYER_REGEN_ENABLED", function()
		if deferred then
			Update()
		end
	end)
end)
