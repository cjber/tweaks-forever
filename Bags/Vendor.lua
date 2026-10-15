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
		{ polestar = "qol.autoRepair" },
	},
})

ns.Feature({
	key = "repairGuild",
	category = "Vendors",
	name = "Repair with guild funds",
	tooltip = "When your guild lets you repair from its bank and your withdrawal limit covers the cost. Otherwise "
		.. "the repair comes out of your own money.",
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

-- Set while a merchant is open and the repair is still waiting for money: junk sold here can pay for it.
local owed = false

-- Repair everything if the guild or your money covers it. `quiet` leaves a shortfall unannounced, for retries.
---@param quiet boolean?
local function Repair(quiet)
	owed = false
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
		owed = true
		if not quiet then
			ns.Print(L["not enough money to repair (%s)."]:format(C_CurrencyInfo.GetCoinTextureString(cost)))
		end
	end
end

ns.On("MERCHANT_SHOW", function()
	Repair()
end)

-- Selling junk (ours, the game's or another addon's) starts after the repair, so try again as the money comes in.
ns.On("PLAYER_MONEY", function()
	if owed then
		Repair(true)
	end
end)

ns.On("MERCHANT_CLOSED", function()
	owed = false
end)
