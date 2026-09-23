---@type string, TFNamespace
local _, ns = ...

ns.Feature({
	key = "quietErrors",
	category = "Interface",
	name = "Quiet repeated combat errors",
	tooltip = "No red text or spoken error for the ones a spammed macro repeats: not ready yet, out of range, "
		.. "not enough mana, rage or energy, no target, and facing the wrong way. Full bags and other errors "
		.. "still show.",
	default = true,
	conflicts = {
		{
			addon = "Leatrix_Plus",
			when = function()
				return LeaPlusDB and LeaPlusDB.HideErrorMessages == "On"
			end,
		},
	},
})

-- Suffixes of the client's LE_GAME_ERR_* message types. Retail hides most of these already; WoW Forever's
-- override (Blizzard_UIErrorsFrame/Camelot) shows them all again.
local NAMES = {
	"ABILITY_COOLDOWN",
	"SPELL_COOLDOWN",
	"ITEM_COOLDOWN",
	"OUT_OF_RANGE",
	"SPELL_OUT_OF_RANGE",
	"GENERIC_NO_TARGET",
	"GENERIC_NO_VALID_TARGETS",
	"NO_ATTACK_TARGET",
	"INVALID_ATTACK_TARGET",
	"BADATTACKFACING",
	"BADATTACKPOS",
	"OUT_OF_ARCANE_CHARGES",
	"OUT_OF_CHI",
	"OUT_OF_COMBO_POINTS",
	"OUT_OF_ENERGY",
	"OUT_OF_ESSENCE",
	"OUT_OF_FOCUS",
	"OUT_OF_FURY",
	"OUT_OF_HOLY_POWER",
	"OUT_OF_INSANITY",
	"OUT_OF_LUNAR_POWER",
	"OUT_OF_MAELSTROM",
	"OUT_OF_MANA",
	"OUT_OF_PAIN",
	"OUT_OF_POWER_DISPLAY",
	"OUT_OF_RAGE",
	"OUT_OF_RUNES",
	"OUT_OF_RUNIC_POWER",
	"OUT_OF_SOUL_SHARDS",
}

ns.Init(function()
	local quiet = {}
	for _, name in ipairs(NAMES) do
		local messageType = _G["LE_GAME_ERR_" .. name]
		if messageType then
			quiet[messageType] = true
		end
	end
	-- The frame plays the error's voice line only when this passes, so one check silences text and sound.
	local ShouldDisplay = UIErrorsFrame.ShouldDisplayMessageType
	function UIErrorsFrame.ShouldDisplayMessageType(frame, messageType, message)
		if quiet[messageType] and ns.Active("quietErrors") then
			return false
		end
		return ShouldDisplay(frame, messageType, message)
	end
end)
