---@type string, TFNamespace
local _, ns = ...
local L = ns.L

local KEY = "trainAll"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Train all button",
	tooltip = "Adds a Train all button beside the class trainer's Train button. One click buys every spell the "
		.. "trainer is offering that your gold covers. It buys nothing on its own and stays disabled, saying why in "
		.. "its tooltip, when nothing is available or you cannot pay for it all.",
	default = false,
	conflicts = {
		{
			addon = "Leatrix_Plus",
			when = function()
				return LeaPlusDB and LeaPlusDB.ShowTrainAllButton == "On"
			end,
		},
	},
})

-- What the trainer is offering right now: how many services, and what they cost together.
---@param count fun(): number
---@param service fun(index: number): string?
---@param price fun(index: number): number?
---@return number services
---@return number total
local function Offers(count, service, price)
	local services, total = 0, 0
	for index = 1, count() do
		if service(index) == "available" then
			services = services + 1
			total = total + (price(index) or 0)
		end
	end
	return services, total
end

-- Buy each service the trainer offers as available, in order, only while the gold on hand covers it.
---@param count fun(): number
---@param service fun(index: number): string?
---@param price fun(index: number): number?
---@param money fun(): number
---@param buy fun(index: number)
local function Buy(count, service, price, money, buy)
	local total = count()
	for index = 1, total do
		if service(index) == "available" and (price(index) or 0) <= money() then
			buy(index)
		end
	end
end

---@param index number
---@return string?
local function ServiceType(index)
	local _, kind = GetTrainerServiceInfo(index)
	return kind
end

---@param index number
---@return number?
local function ServiceCost(index)
	local cost = GetTrainerServiceCost(index)
	return cost
end

---@class TFTrainAllButton: Button
---@field services? number
---@field total? number

---@type TFTrainAllButton?
local button

-- The button is only drawn for the class trainer, whose services are the player's class spells; a profession
-- trainer's list carries its own confirmation and is left alone.
local function Showing()
	return ns.Active(KEY) and not IsTradeskillTrainer()
end

local function Tooltip()
	if not button then
		return
	end
	local services, total = button.services or 0, button.total or 0
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	if services == 0 then
		GameTooltip_AddNormalLine(GameTooltip, L["Nothing is available to train right now."])
	else
		GameTooltip_AddNormalLine(GameTooltip, L["Train %d skills for %s"]:format(services, GetMoneyString(total)))
		if GetMoney() < total then
			GameTooltip_AddErrorLine(GameTooltip, L["Not enough gold for all of them."])
		end
	end
	GameTooltip:Show()
end

local function Refresh()
	if not button then
		return
	end
	if not Showing() then
		button:Hide()
		return
	end
	local services, total = Offers(GetNumTrainerServices, ServiceType, ServiceCost)
	button.services, button.total = services, total
	button:SetEnabled(services > 0 and GetMoney() >= total)
	button:Show()
end

local function Click()
	if not Showing() then
		return
	end
	Buy(GetNumTrainerServices, ServiceType, ServiceCost, GetMoney, BuyTrainerService)
	Refresh()
end

-- The trainer frame loads on demand, when the player first opens a trainer, so the button is made then and
-- anchored to the stock Train button.
local function Attach()
	if not (ns.Active(KEY) and ClassTrainerFrame and ClassTrainerTrainButton) then
		if button then
			button:Hide()
		end
		return
	end
	if not button then
		button = CreateFrame("Button", nil, ClassTrainerFrame, "UIPanelButtonTemplate") --[[@as TFTrainAllButton]]
		button:SetSize(80, ClassTrainerTrainButton:GetHeight())
		button:SetPoint("RIGHT", ClassTrainerTrainButton, "LEFT", -4, 0)
		button:SetText(L["Train all"])
		button:SetMotionScriptsWhileDisabled(true)
		button:SetScript("OnClick", Click)
		button:SetScript("OnEnter", Tooltip)
		button:SetScript("OnLeave", GameTooltip_Hide)
		hooksecurefunc("ClassTrainerFrame_Update", Refresh)
	end
	Refresh()
end

ns.Init(function()
	ns.On("ADDON_LOADED", function(addon)
		if addon == "Blizzard_TrainerUI" then
			Attach()
		end
	end)
	if C_AddOns.IsAddOnLoaded("Blizzard_TrainerUI") then
		Attach()
	end
	ns.OnSettingChanged(KEY, Attach)
end)
