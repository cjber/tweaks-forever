---@type string, TFNamespace
local _, ns = ...

ns.Feature({
	key = "lootConfirm",
	category = "Automation",
	name = "Skip loot confirmations",
	tooltip = "Confirms the game's warning when you roll Need or Disenchant on loot, and when you loot a Bind on "
		.. "Pickup item. Only the warnings your own clicks raise, and nothing rolls or loots by itself.",
	default = false,
	conflicts = {
		{
			addon = "Leatrix_Plus",
			when = function()
				return LeaPlusDB and LeaPlusDB.NoConfirmLoot == "On"
			end,
		},
	},
})

local function Roll(rollID, rollType)
	if ns.Active("lootConfirm") then
		ConfirmLootRoll(rollID, rollType)
		StaticPopup_Hide("CONFIRM_LOOT_ROLL")
	end
end

ns.On("CONFIRM_LOOT_ROLL", Roll)
ns.On("CONFIRM_DISENCHANT_ROLL", Roll)

ns.On("LOOT_BIND_CONFIRM", function(slot)
	if ns.Active("lootConfirm") then
		ConfirmLootSlot(slot)
		StaticPopup_Hide("LOOT_BIND")
	end
end)
