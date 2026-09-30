---@type string, TFNamespace
local _, ns = ...
local L = ns.L

ns.Feature({
	key = "repair",
	category = "Vendors",
	name = "Repair automatically",
	tooltip = "At any merchant who repairs, with the cost shown in chat.",
	default = true,
	conflicts = {
		{
			addon = "Leatrix_Plus",
			when = function()
				return LeaPlusDB and LeaPlusDB.AutoRepairGear == "On"
			end,
		},
	},
})

ns.Feature({
	key = "repairGuild",
	category = "Vendors",
	name = "Use guild funds for repairs when allowed",
	default = true,
	parent = "repair",
})

-- Whether the guild bank will cover `cost` (a withdraw limit of -1 is unlimited).
local function GuildCovers(cost)
	if not (ns.Active("repairGuild") and IsInGuild() and CanGuildBankRepair and CanGuildBankRepair()) then
		return false
	end
	local limit = GetGuildBankWithdrawMoney()
	return limit == -1 or limit >= cost
end

ns.On("MERCHANT_SHOW", function()
	if not (ns.Active("repair") and CanMerchantRepair()) then
		return
	end
	local cost, canRepair = GetRepairAllCost()
	if not canRepair or cost == 0 then
		return
	end
	if GuildCovers(cost) then
		RepairAllItems(true)
		ns.Print(L["repaired for %s from guild funds."]:format(C_CurrencyInfo.GetCoinTextureString(cost)))
	elseif GetMoney() >= cost then
		RepairAllItems()
		ns.Print(L["repaired for %s."]:format(C_CurrencyInfo.GetCoinTextureString(cost)))
	else
		ns.Print(L["not enough money to repair (%s)."]:format(C_CurrencyInfo.GetCoinTextureString(cost)))
	end
end)
