local _, ns = ...

ns.Feature({
	key = "campTooltips",
	category = "Interface",
	name = "Explain campsite features",
	tooltip = "Hovering a camp feature, such as a Camp Tent or Mana Well, shows what sitting nearby gives you and "
		.. "whether you have it. Hovering a campfire shows how long your camp benefits last.",
	default = true,
})

local CAMP_BENEFITS = 1229741

-- { placement spell, object it places, aura it grants }. An upgrade grants its base feature's aura. The object's
-- name is the placement spell's name; the entry catches an object named otherwise (the two Faction Banners).
local FEATURES = {
	{ 1307227, 529161, CAMP_BENEFITS }, -- Basic Campfire
	{ 1307252, 630660, CAMP_BENEFITS }, -- Journeyman Campfire
	{ 1307237, 650137, CAMP_BENEFITS }, -- Expert Campfire
	{ 1307230, 528996, 1229451 }, -- Camp Tent: Boosted Rest
	{ 1307391, 612140, 1229451 }, -- Sewing Machine
	{ 1307395, 612122, 1229451 }, -- Tanning Rack
	{ 1307229, 612275, 1229519 }, -- Camp Chair: Boosted Critical Chance
	{ 1307243, 612088, 1229519 }, -- Field Guide
	{ 1307397, 612082, 1229519 }, -- Trapper's Workbench
	{ 1307259, 651948, 1230587 }, -- Mana Well: Boosted Mana Regeneration
	{ 1307172, 612139, 1230587 }, -- Alchemy Laboratory
	{ 1307242, 612120, 1230587 }, -- Fermenter
	{ 1307392, 651950, 1230172 }, -- Sharpening Wheel: Extra Strength
	{ 1307175, 612125, 1230172 }, -- Anvil
	{ 1307261, 612136, 1230172 }, -- Master Forge
	{ 1307234, 651952, 1230653 }, -- Enchanted Lute: Boosted Stats
	{ 1307176, 612143, 1230653 }, -- Arcane Forge
	{ 1307223, 612130, 1230653 }, -- Arcane Salvager
	{ 1307244, 651953, 1230124 }, -- First Aid Kit: Boosted Stamina
	{ 1307265, 612110, 1230124 }, -- Plague Doctor's Laboratory
	{ 1307396, 612091, 1230124 }, -- Toxin Study
	{ 1307245, 651954, 1230098 }, -- Fish Bowl: Boosted Stats
	{ 1307246, 612092, 1230098 }, -- Fishing Hut
	{ 1307247, 612090, 1230098 }, -- Fishing Rack
	{ 1307251, 651955, 1229513 }, -- Incense Candle: Boosted Intellect
	{ 1307248, 612087, 1229513 }, -- Greenhouse
	{ 1307254, 651956, 1230164 }, -- Lodestone: Boosted Attack Power
	{ 1307264, 612134, 1230164 }, -- Molten Foundry
	{ 1307386, 654285, 1230164 }, -- Rock Garden
	{ 1307239, 612351, 1229718 }, -- Faction Banner (Alliance): Boosted Spirit
	{ 1307240, 612350, 1229718 }, -- Faction Banner (Horde)
	{ 1307255, 612142, 1229718 }, -- Loom
	{ 1307393, 612123, 1229718 }, -- Spinning Wheel
}

ns.Init(function()
	local byEntry, byName = {}, {}
	for _, feature in ipairs(FEATURES) do
		local spell, entry, aura = unpack(feature)
		byEntry[entry] = aura
		local name = C_Spell.GetSpellName(spell)
		if name then
			byName[name] = aura
		end
	end

	local function AuraOf(data)
		local entry = type(data.guid) == "string" and data.guid:match("^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)")
		local line = data.lines and data.lines[1]
		return entry and byEntry[tonumber(entry)] or line and byName[line.leftText]
	end

	-- Seconds left on the aura, 0 for no expiry, nil without it. Aura data can be secret in combat, so no answer there.
	local function Remaining(aura)
		local info = C_UnitAuras.GetPlayerAuraBySpellID(aura)
		return info and (info.expirationTime > 0 and info.expirationTime - GetTime() or 0)
	end

	local function AddStatus(tooltip, aura, active)
		if InCombatLockdown() then
			return
		end
		local left = Remaining(aura)
		if not left then
			tooltip:AddLine("You don't have this", GRAY_FONT_COLOR:GetRGB())
		elseif left > 0 then
			tooltip:AddLine(active .. ": " .. SecondsToTime(left, true), GREEN_FONT_COLOR:GetRGB())
		else
			tooltip:AddLine(active, GREEN_FONT_COLOR:GetRGB())
		end
	end

	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, function(tooltip, data)
		if tooltip ~= GameTooltip or not ns.Active("campTooltips") then
			return
		end
		local aura = AuraOf(data)
		if not aura then
			return
		end
		if aura == CAMP_BENEFITS then
			local hint = "Sit or craft nearby for a minute to gain each feature's benefit in this camp."
			tooltip:AddLine(hint, 1, 1, 1, true)
			AddStatus(tooltip, aura, "Camp benefits")
		else
			local description = C_Spell.GetSpellDescription(aura)
			local text = description and description ~= "" and description or C_Spell.GetSpellName(aura)
			local r, g, b = GREEN_FONT_COLOR:GetRGB()
			tooltip:AddLine("Sitting nearby: " .. text, r, g, b, true)
			AddStatus(tooltip, aura, "Active")
		end
		tooltip:Show()
	end)
end)
