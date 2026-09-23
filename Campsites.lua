---@type string, TFNamespace
local _, ns = ...

ns.Feature({
	key = "campTooltips",
	category = "Interface",
	name = "Explain campsite benefits",
	tooltip = "Hovering a camp feature, such as a Camp Tent or Mana Well, shows exactly what sitting nearby gives "
		.. "you and whether you have it. Hovering a campfire or your Camp Benefits buff lists every benefit a camp "
		.. "can give, with the ones you have and their time left.",
	default = true,
})

ns.Feature({
	key = "campPopup",
	category = "Interface",
	name = "Show camp benefits near a campfire",
	tooltip = "Coming near a campfire opens a small panel below your buffs listing every camp benefit: the ones "
		.. "you have with their time left, and what the others would give. Closing it hides it until the next "
		.. "campfire. Hidden in combat.",
	default = true,
})

local CAMP_BENEFITS, CAMPFIRE_NEARBY = 1229741, 1283391
local TENT = 1229451
-- Leaving a campfire and coming back within this many seconds doesn't reopen a panel you closed, in case the
-- game drops and re-adds Campfire Nearby while you stand still.
local REOPEN_AFTER = 10

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

-- The auras that change what the panel shows.
local WATCHED = { [CAMP_BENEFITS] = true, [CAMPFIRE_NEARBY] = true }
for _, benefit in ipairs(ns.CampBenefits) do
	WATCHED[benefit[1]] = true
end

-- Every camp benefit as { benefit, left }, the ones you have first, each group in the game's order. `remaining`
-- gives seconds left on an aura, 0 for no expiry, nil without it.
---@param remaining fun(aura: integer): number?
---@return TFCampRow[]
local function Listing(remaining)
	local have, missing = {}, {}
	for _, benefit in ipairs(ns.CampBenefits) do
		local left = remaining(benefit[1])
		table.insert(left and have or missing, { benefit = benefit, left = left })
	end
	for _, row in ipairs(missing) do
		have[#have + 1] = row
	end
	return have
end

-- Whether an incremental aura update touches a watched aura, keeping `instances` (auraInstanceID -> true) current.
---@param info UnitAuraUpdateInfo
---@param instances TFMarks
---@return boolean
local function Touches(info, instances)
	local hit = false
	for _, aura in ipairs(info.addedAuras or {}) do
		if WATCHED[aura.spellId] then
			instances[aura.auraInstanceID] = true
			hit = true
		end
	end
	for _, id in ipairs(info.updatedAuraInstanceIDs or {}) do
		hit = hit or instances[id] or false
	end
	for _, id in ipairs(info.removedAuraInstanceIDs or {}) do
		if instances[id] then
			instances[id] = nil
			hit = true
		end
	end
	return hit
end

ns.Camp = { Listing = Listing, Touches = Touches }

-- Aura data is secret in combat and wherever else the game restricts it: no reading, comparing or arithmetic then.
local function AurasSecret()
	return InCombatLockdown() or C_Secrets.ShouldAurasBeSecret()
end

-- Seconds left on the aura, 0 for no expiry, nil without it. Only call when AurasSecret() is false.
---@param aura integer
---@return number?
local function Remaining(aura)
	local info = C_UnitAuras.GetPlayerAuraBySpellID(aura)
	return info and (info.expirationTime > 0 and info.expirationTime - GetTime() or 0)
end

-- Minutes and up without seconds, but seconds in the last minute rather than an empty string.
---@param left number
---@return string
local function Time(left)
	return SecondsToTime(left, left >= 60)
end

-- A benefit as one line of a list: green with its time left if you have it, grey otherwise.
---@param tooltip GameTooltip
---@param row TFCampRow
local function AddRow(tooltip, row)
	local aura, feature, effect = unpack(row.benefit)
	local text
	if not row.left then
		text = feature .. ": " .. effect
	elseif aura == TENT then
		text = feature .. ": rested" .. (row.left > 0 and ", again in " .. Time(row.left) or "")
	else
		-- The time goes by the name, where wrapping can't strand it on a line of its own.
		text = feature .. (row.left > 0 and " (" .. Time(row.left) .. ")" or "") .. ": " .. effect
	end
	local color = row.left and GREEN_FONT_COLOR or GRAY_FONT_COLOR
	tooltip:AddLine(text, color.r, color.g, color.b, true)
end

-- What a camp can give, for the campfire tooltip and the panel. No object scan tells which features this camp
-- has, so it is every benefit there is.
---@param tooltip GameTooltip
local function AddCampList(tooltip)
	local hint = "Sit or craft near a camp feature for a minute to gain its benefit:"
	tooltip:AddLine(hint, 1, 1, 1, true)
	for _, row in ipairs(Listing(Remaining)) do
		AddRow(tooltip, row)
	end
end

---@param tooltip GameTooltip
---@param aura integer
local function AddStatus(tooltip, aura)
	local left = Remaining(aura)
	local text
	if not left then
		tooltip:AddLine("You don't have this", GRAY_FONT_COLOR:GetRGB())
		return
	elseif aura == TENT then
		text = left > 0 and "Rested, again in " .. Time(left) or "Rested"
	else
		text = left > 0 and "Active: " .. Time(left) or "Active"
	end
	tooltip:AddLine(text, GREEN_FONT_COLOR:GetRGB())
end

local byAura = {}
for _, benefit in ipairs(ns.CampBenefits) do
	byAura[benefit[1]] = benefit
end

---@param tooltip GameTooltip
---@param aura integer
local function AddFeature(tooltip, aura)
	local _, _, effect, seconds = unpack(byAura[aura])
	local text = seconds and "Sitting nearby: " .. effect .. " for " .. Time(seconds) or effect
	local r, g, b = GREEN_FONT_COLOR:GetRGB()
	tooltip:AddLine(text, r, g, b, true)
	if not AurasSecret() then
		AddStatus(tooltip, aura)
	end
end

local function InitTooltips()
	local byEntry, byName = {}, {}
	for _, feature in ipairs(FEATURES) do
		local spell, entry, aura = unpack(feature)
		byEntry[entry] = aura
		local name = C_Spell.GetSpellName(spell)
		if name then
			byName[name] = aura
		end
	end

	---@param data TooltipData
	---@return integer?
	local function AuraOf(data)
		local entry = type(data.guid) == "string" and data.guid:match("^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)")
		local line = data.lines and data.lines[1]
		return entry and byEntry[tonumber(entry)] or line and byName[line.leftText]
	end

	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, function(tooltip, data)
		if tooltip ~= GameTooltip or not ns.Active("campTooltips") then
			return
		end
		local aura = AuraOf(data)
		if aura == CAMP_BENEFITS then
			if AurasSecret() then
				return
			end
			AddCampList(tooltip)
		elseif aura then
			AddFeature(tooltip, aura)
		else
			return
		end
		tooltip:Show()
	end)

	-- The Camp Benefits buff lists only what you have; add what the rest would give. Only your own buff: the list
	-- is of your auras.
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.UnitAura, function(tooltip, data)
		if tooltip ~= GameTooltip or not ns.Active("campTooltips") or AurasSecret() or data.id ~= CAMP_BENEFITS then
			return
		end
		local info = tooltip:GetPrimaryTooltipInfo()
		local unit = info and info.getterArgs and info.getterArgs[1]
		if not unit or not UnitIsUnit(unit, "player") then
			return
		end
		local missing = {}
		for _, row in ipairs(Listing(Remaining)) do
			if not row.left then
				missing[#missing + 1] = row
			end
		end
		if #missing == 0 then
			return
		end
		tooltip:AddLine(" ")
		tooltip:AddLine("Not yet gained:", GRAY_FONT_COLOR:GetRGB())
		for _, row in ipairs(missing) do
			AddRow(tooltip, row)
		end
		tooltip:Show()
	end)
end

-- The panel: a tooltip of our own with a close button, as ItemRefTooltip is, below the buffs and debuffs so
-- it stays clear of the minimap and the quest tracker under it.
local function InitPanel()
	---@type GameTooltip?
	local panel
	local instances = {}
	local dismissed, leftAt = false, nil

	local function Panel()
		if not panel then
			-- Generated XML conflates the global GameTooltip's item-comparison children with the frame type.
			panel = CreateFrame("GameTooltip", "TweaksForeverCampTooltip", UIParent, "GameTooltipTemplate") --[[@as GameTooltip]]
			panel:SetFrameStrata("MEDIUM")
			local close = CreateFrame("Button", nil, panel, "UIPanelCloseButtonNoScripts")
			close:SetPoint("TOPRIGHT", 2, 2)
			close:SetScript("OnClick", function()
				dismissed = true
				panel:Hide()
			end)
		end
		return panel
	end

	local function Hide()
		if panel then
			panel:Hide()
		end
	end

	local function Rescan()
		wipe(instances)
		for spell in pairs(WATCHED) do
			local aura = C_UnitAuras.GetPlayerAuraBySpellID(spell)
			if aura then
				instances[aura.auraInstanceID] = true
			end
		end
	end

	local function Refresh()
		if AurasSecret() then
			Hide()
			return
		end
		local near = C_UnitAuras.GetPlayerAuraBySpellID(CAMPFIRE_NEARBY)
		if not near then
			leftAt = leftAt or GetTime()
		elseif leftAt then
			dismissed = dismissed and GetTime() - leftAt < REOPEN_AFTER
			leftAt = nil
		end
		if not near or dismissed or not ns.Active("campPopup") then
			Hide()
			return
		end
		local tooltip = Panel()
		tooltip:SetOwner(UIParent, "ANCHOR_NONE")
		tooltip:SetPoint("TOPRIGHT", DebuffFrame, "BOTTOMRIGHT", 0, -8)
		GameTooltip_SetTitle(tooltip, "Camp")
		AddCampList(tooltip)
		tooltip:Show()
	end

	local events = CreateFrame("Frame")
	events:RegisterUnitEvent("UNIT_AURA", "player")
	events:SetScript("OnEvent", function(_, _, _, info)
		if AurasSecret() then
			return
		end
		if info.isFullUpdate then
			Rescan()
			Refresh()
		elseif Touches(info, instances) then
			Refresh()
		end
	end)
	ns.On("PLAYER_REGEN_DISABLED", Hide)
	-- Updates during combat were unreadable, so start again from what the player has now.
	ns.On("PLAYER_REGEN_ENABLED", function()
		Rescan()
		Refresh()
	end)
	Settings.SetOnValueChangedCallback("TweaksForever_campPopup", Refresh)
	if not AurasSecret() then
		Rescan()
		Refresh()
	end
end

ns.Init(function()
	InitTooltips()
	InitPanel()
end)
