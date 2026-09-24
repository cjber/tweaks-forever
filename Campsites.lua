---@type string, TFNamespace
local _, ns = ...

ns.Feature({
	key = "campTooltips",
	category = "Interface",
	name = "Explain campsite benefits",
	tooltip = "Hovering a camp feature, such as a Camp Tent or Mana Well, shows exactly what sitting nearby gives "
		.. "you and whether you have it. Hovering a campfire lists every benefit a camp can give. Your Campfire "
		.. "Nearby buff adds the benefits you have, and which way the campfire is once you have lit or sat by it; "
		.. "your Camp Benefits buff adds the ones you haven't gained yet.",
	default = true,
})

local CAMP_BENEFITS, CAMPFIRE_NEARBY = 1229741, 1283391
local TENT = 1229451
-- About the reach of Campfire Nearby: a campfire remembered farther off than this is not the one you are near.
local NEARBY_YARDS = 120
-- Closer than this, a direction means nothing.
local HERE_YARDS = 8

-- { placement spell, object it places, aura it grants }. An upgrade grants its base feature's aura. The object's
-- name is the placement spell's name; the entry catches an object named otherwise (the two Faction Banners).
local FEATURES = {
	{ 1307227, 529161, CAMP_BENEFITS }, -- Basic Campfire
	{ 1307252, 630660, CAMP_BENEFITS }, -- Journeyman Campfire
	{ 1307237, 650137, CAMP_BENEFITS }, -- Expert Campfire
	{ 1307230, 528996, TENT }, -- Camp Tent: Boosted Rest
	{ 1307391, 612140, TENT }, -- Sewing Machine
	{ 1307395, 612122, TENT }, -- Tanning Rack
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
-- The placement spells of each campfire tier: the features that grant Camp Benefits.
local CAMPFIRES = {}
for _, feature in ipairs(FEATURES) do
	if feature[3] == CAMP_BENEFITS then
		CAMPFIRES[feature[1]] = true
	end
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

-- Which way the campfire lies, relative to where you face, a whole sector a side.
local SIDES = {
	"ahead",
	"ahead to your left",
	"to your left",
	"behind you to the left",
	"behind you",
	"behind you to the right",
	"to your right",
	"ahead to your right",
}

-- Where a campfire is, as a tooltip line. Bearings run counter-clockwise from north, as GetPlayerFacing's do.
---@param north number yards the campfire lies north of you
---@param west number yards it lies west of you
---@param facing number
---@return string
local function Toward(north, west, facing)
	local yards = math.sqrt(north ^ 2 + west ^ 2)
	if yards < HERE_YARDS then
		return "Campfire: right here"
	end
	local turn = (math.atan2(west, north) - facing) % (2 * math.pi)
	local side = SIDES[math.floor(turn / (math.pi / 4) + 0.5) % 8 + 1]
	return ("Campfire: about %d yd %s"):format(math.floor(yards / 5 + 0.5) * 5, side)
end

ns.Camp = { Listing = Listing, Toward = Toward }

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

-- What a camp can give, for the campfire tooltip. No object scan tells which features this camp
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

-- Where you last lit a campfire or gained Camp Benefits, which only a campfire's side grants.
---@type {x: number, y: number, map: integer}?
local fire
local benefitsInstance

---@return number?, number?, integer?
local function Here()
	local x, y, _, map = UnitPosition("player")
	if not (canaccessvalue(x) and canaccessvalue(y) and canaccessvalue(map)) or not (x and y and map) then
		return nil
	end
	return x, y, map
end

local function Remember()
	local x, y, map = Here()
	if x and y and map then
		fire = { x = x, y = y, map = map }
	end
end

---@return string?
local function Direction()
	local x, y, map = Here()
	local facing = GetPlayerFacing()
	if not fire or not x or map ~= fire.map or not canaccessvalue(facing) or not facing then
		return nil
	end
	local north, west = fire.x - x, fire.y - y
	if north ^ 2 + west ^ 2 > NEARBY_YARDS ^ 2 then
		return nil
	end
	return Toward(north, west, facing)
end

-- Campfire Nearby: the benefits you have and which way the campfire is.
---@param tooltip GameTooltip
local function AddNearby(tooltip)
	local direction = Direction()
	local active = {}
	for _, row in ipairs(Listing(Remaining)) do
		if row.left then
			active[#active + 1] = row
		end
	end
	if not direction and #active == 0 then
		return
	end
	tooltip:AddLine(" ")
	if direction then
		tooltip:AddLine(direction, HIGHLIGHT_FONT_COLOR:GetRGB())
	end
	for _, row in ipairs(active) do
		AddRow(tooltip, row)
	end
	tooltip:Show()
end

-- The Camp Benefits buff lists only what you have: add what the rest would give.
---@param tooltip GameTooltip
local function AddMissing(tooltip)
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
	-- An object's GUID and name can be secret under the game's restrictions, and a secret is no table key.
	local function AuraOf(data)
		local guid = data.guid
		local entry = canaccessvalue(guid)
			and type(guid) == "string"
			and guid:match("^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)")
		if entry and byEntry[tonumber(entry)] then
			return byEntry[tonumber(entry)]
		end
		local line = data.lines and data.lines[1]
		local name = line and line.leftText
		return canaccessvalue(name) and name and byName[name] or nil
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

	-- Only your own buffs: the lines are about your auras.
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.UnitAura, function(tooltip, data)
		if tooltip ~= GameTooltip or not ns.Active("campTooltips") or AurasSecret() then
			return
		end
		-- A spell flagged always-secret keeps its id secret even outside restrictions, and on a restricted map
		-- UnitIsUnit answers with a secret boolean.
		local id = data.id
		if not canaccessvalue(id) or (id ~= CAMP_BENEFITS and id ~= CAMPFIRE_NEARBY) then
			return
		end
		local info = tooltip:GetPrimaryTooltipInfo()
		local unit = info and info.getterArgs and info.getterArgs[1]
		local mine = unit and UnitIsUnit(unit, "player")
		if not canaccessvalue(mine) or not mine then
			return
		end
		if id == CAMPFIRE_NEARBY then
			AddNearby(tooltip)
		else
			AddMissing(tooltip)
		end
	end)
end

local function TrackCampfire()
	-- Only your own casts: another unit's may carry secret arguments.
	local casts = CreateFrame("Frame")
	casts:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	casts:SetScript("OnEvent", function(_, _, _, _, spell)
		if canaccessvalue(spell) and CAMPFIRES[spell] then
			Remember()
		end
	end)
	-- Camp Benefits comes and refreshes only by a campfire, so each is a fresh fix on where it is.
	local auras = CreateFrame("Frame")
	auras:RegisterUnitEvent("UNIT_AURA", "player")
	auras:SetScript("OnEvent", function(_, _, _, info)
		if AurasSecret() then
			return
		end
		if info.isFullUpdate then
			local aura = C_UnitAuras.GetPlayerAuraBySpellID(CAMP_BENEFITS)
			benefitsInstance = aura and aura.auraInstanceID
			return
		end
		for _, aura in ipairs(info.addedAuras or {}) do
			if aura.spellId == CAMP_BENEFITS then
				benefitsInstance = aura.auraInstanceID
				Remember()
			end
		end
		for _, id in ipairs(info.updatedAuraInstanceIDs or {}) do
			if id == benefitsInstance then
				Remember()
			end
		end
	end)
end

ns.Init(function()
	InitTooltips()
	TrackCampfire()
end)
