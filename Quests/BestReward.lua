---@type string, TFNamespace
local _, ns = ...

local KEY = "bestReward"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Mark the best-selling quest reward",
	tooltip = "When a quest lets you choose a reward, a gold coin marks the one that sells to a merchant for the most."
		.. " Nothing is chosen for you.",
	default = true,
	conflicts = { { polestar = "qol.rewardHighlight" } },
})

-- The game's gold coin icon, a square file drawn square.
local COIN = "Interface\\MoneyFrame\\UI-GoldIcon"
local COIN_SIZE = 16

---@class TFRewardChoice
---@field index integer the choice's index among the quest's reward choices
---@field value number? its sell price times its count; nil while the item isn't cached

---@class TFBestReward
local Model = {}
ns.BestReward = Model

-- The choice that sells for strictly the most, and whether any value is still unknown. A tie at the top or nothing
-- worth selling marks none.
---@param choices TFRewardChoice[]
---@return integer? index
---@return boolean pending
function Model.Best(choices)
	local best, top, tied, pending = nil, 0, false, false
	for _, choice in ipairs(choices) do
		local value = choice.value
		if value == nil then
			pending = true
		elseif value > top then
			best, top, tied = choice.index, value, false
		elseif value == top and value > 0 then
			tied = true
		end
	end
	if pending or tied or #choices < 2 then
		return nil, pending
	end
	return best, false
end

-- A choice's sell value, nil while unknown. A currency choice (loot type 1) sells for nothing.
---@param index integer
---@return number?
local function Value(index)
	if GetQuestItemInfoLootType and GetQuestItemInfoLootType("choice", index) == 1 then
		return 0
	end
	local link = GetQuestItemLink("choice", index)
	if not link then
		return nil
	end
	local _, _, count = GetQuestItemInfo("choice", index)
	local price = select(11, C_Item.GetItemInfo(link))
	return price and price * math.max(count or 1, 1) or nil
end

---@type Frame?
local marker
-- The reward panel is the quest display on screen; a price is still loading.
local onReward, waiting = false, false

---@return Frame
local function Marker()
	if not marker then
		marker = CreateFrame("Frame", nil, QuestInfoRewardsFrame)
		marker:SetSize(COIN_SIZE, COIN_SIZE)
		local coin = marker:CreateTexture(nil, "OVERLAY")
		coin:SetTexture(COIN) -- art-ok: the game's square gold coin file, drawn square
		coin:SetAllPoints()
	end
	return marker
end

-- The quest frame's `nth` shown choice button. Read only: Blizzard lays out the choices in order, after any fixed
-- rewards, and marks each with type "choice".
---@param nth integer
---@return TFRewardButton?
local function ChoiceButton(nth)
	local seen = 0
	for _, button in
		ipairs((QuestInfoRewardsFrame.RewardButtons or {}) --[[@as TFRewardButton[] ]])
	do
		if button:IsShown() and button.type == "choice" then
			seen = seen + 1
			if seen == nth then
				return button
			end
		end
	end
end

local function Update()
	waiting = false
	if marker then
		marker:Hide()
	end
	if not (onReward and ns.Active(KEY) and QuestFrameRewardPanel:IsVisible()) then
		return
	end
	local count = GetNumQuestChoices()
	if count < 2 then
		return
	end
	local choices = {}
	for index = 1, count do
		choices[index] = { index = index, value = Value(index) }
	end
	local best, pending = Model.Best(choices)
	waiting = pending
	local button = best and ChoiceButton(best)
	if button then
		local frame = Marker()
		-- In the rewards frame, so the scroll frame clips and scrolls it with the button.
		frame:SetFrameLevel(button:GetFrameLevel() + 2)
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", button.Icon or button, "TOPRIGHT", -2, -2)
		frame:Show()
	end
end

-- Laid out after Blizzard's QuestInfo_Display; the quest log's own display shares the rewards frame, so only the
-- reward template counts.
---@param template table?
local function Displayed(template)
	onReward = template == QUEST_TEMPLATE_REWARD
	Update()
end

local function Retry()
	if waiting then
		Update()
	end
end

ns.Init(function()
	hooksecurefunc("QuestInfo_Display", Displayed)
	ns.On("GET_ITEM_INFO_RECEIVED", Retry)
	-- A choice's item arriving re-lays the rewards without QuestInfo_Display.
	ns.On("QUEST_ITEM_UPDATE", Retry)
	ns.On("QUEST_FINISHED", function()
		onReward = false
		Update()
	end)
	ns.OnSettingChanged(KEY, Update)
	-- Polestar's matching option changes take effect at once too.
	hooksecurefunc(ns, "RefreshConflicts", Update)
end)
