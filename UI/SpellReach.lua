---@type string, TFNamespace
local _, ns = ...

local KEY = "spellReach"

-- Nameplate addons that already show range, or take over the plates the icons sit under.
ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Spell reach under nameplates",
	tooltip = "Puts a small icon for each of your class's main attacks under every enemy nameplate. An icon in "
		.. "full colour means that spell can reach the enemy; dark red means it cannot. The icons follow the "
		.. "spells you know, one for each reach: a shaman sees a shock and Lightning Bolt.",
	default = false,
	conflicts = {
		{ addon = "RangeLens" },
		{ addon = "Plater" },
		{ addon = "Kui_Nameplates" },
		{ addon = "NeatPlates" },
		{ addon = "TidyPlates_ThreatPlates" },
		{ addon = "Platynator" },
		{ addon = "ElvUI" },
	},
})

-- The class spells shown, one for each reach a class fights at, closest first. Only the spells the character
-- knows are drawn, and the client answers for each whether the enemy is inside its range; it gives no distance
-- in yards to a hostile unit. Spell ID and range verified against the pinned Forever client build 1.60.1.70205
-- on wago.tools (SpellMisc RangeIndex, SpellRange).
local SPELLS = {
	WARRIOR = { 78 }, -- Heroic Strike, 0-5
	PALADIN = { 20271, 879 }, -- Judgement 0-10, Exorcism 0-30
	HUNTER = { 2973, 75 }, -- Raptor Strike 0-5, Auto Shot 8-35
	ROGUE = { 1752 }, -- Sinister Strike 0-5
	PRIEST = { 585 }, -- Smite 0-30
	SHAMAN = { 8042, 403 }, -- Earth Shock 0-20, Lightning Bolt 0-30
	MAGE = { 116, 133 }, -- Frostbolt 0-30, Fireball 0-35
	WARLOCK = { 686 }, -- Shadow Bolt 0-30
	DRUID = { 6807, 5176 }, -- Maul 0-5, Wrath 0-30
}

local SIZE, GAP = 14, 2
local REACHES, OUT = { 1, 1, 1 }, { 0.6, 0.1, 0.1 }
local PERIOD = 0.2

---@class TFSpellReach
local Model = {}
ns.SpellReach = Model

-- The icons for one enemy, in the class's order: each spell the character knows, with whether it reaches. A
-- spell the client cannot answer for is left out. The client reads are passed in so the specs can drive them.
---@param class string
---@param known fun(id: integer): boolean
---@param inRange fun(id: integer): boolean?
---@return TFReachIcon[]
function Model.Icons(class, known, inRange)
	local icons = {}
	for _, id in ipairs(SPELLS[class] or {}) do
		if known(id) then
			local reaches = inRange(id)
			if reaches ~= nil then
				icons[#icons + 1] = { id = id, reaches = reaches }
			end
		end
	end
	return icons
end

-- Every base spell in the player's book, so a rank the character has learnt stands for its base: a level 60 mage
-- knows a rank of Frostbolt, not rank 1.
---@type table<integer, true>
local learnt = {}

local function ScanSpells()
	wipe(learnt)
	for index = 1, C_SpellBook.GetNumSpellBookSkillLines() do
		local line = C_SpellBook.GetSpellBookSkillLineInfo(index)
		for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
			local item = C_SpellBook.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
			if item then
				for _, id in ipairs({ item.actionID, item.spellID }) do
					if id then
						learnt[C_SpellBook.FindBaseSpellByID(id) or id] = true
					end
				end
			end
		end
	end
end

---@param id integer
---@return boolean
local function Known(id)
	return C_SpellBook.IsSpellKnown(id) or learnt[id] == true
end

-- The icon rows drawn, by the plate they hang under. Weak keys: a plate is pooled, and its row lives and dies
-- with it. Blizzard's frames never have a field of ours written to them.
---@type table<NamePlateFrame, TFReachRow>
local rows = setmetatable({}, { __mode = "k" })
-- The plates on screen, by the unit token each carries.
---@type table<string, NamePlateFrame>
local plates = {}

---@param plate NamePlateFrame
---@param unitFrame NamePlateUnitFrame
---@return TFReachRow
local function Row(plate, unitFrame)
	local row = rows[plate]
	if not row then
		row = CreateFrame("Frame", nil, unitFrame) --[[@as TFReachRow]]
		row:SetSize(SIZE, SIZE)
		row:SetPoint("TOP", unitFrame.HealthBarsContainer, "BOTTOM", 0, -GAP)
		row.icons = {}
		rows[plate] = row
	end
	return row
end

---@param row TFReachRow
---@param index integer
---@return Texture
local function Icon(row, index)
	local icon = row.icons[index]
	if not icon then
		icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetSize(SIZE, SIZE)
		icon:SetPoint("LEFT", row, "LEFT", (index - 1) * (SIZE + GAP), 0)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		row.icons[index] = icon
	end
	return icon
end

---@param plate NamePlateFrame
local function Clear(plate)
	local row = rows[plate]
	if row then
		row:Hide()
	end
end

---@param unit string
---@param plate NamePlateFrame
local function Draw(unit, plate)
	local unitFrame = plate.UnitFrame
	if not unitFrame or not UnitCanAttack("player", unit) or UnitIsDeadOrGhost(unit) then
		Clear(plate)
		return
	end
	local _, class = UnitClass("player")
	local icons = Model.Icons(class, Known, function(id)
		return C_Spell.IsSpellInRange(id, unit)
	end)
	if #icons == 0 then
		Clear(plate)
		return
	end
	local row = Row(plate, unitFrame)
	row:SetWidth(#icons * SIZE + (#icons - 1) * GAP)
	for index, spell in ipairs(icons) do
		local icon = Icon(row, index)
		icon:SetTexture(C_Spell.GetSpellTexture(spell.id))
		icon:SetVertexColor(unpack(spell.reaches and REACHES or OUT))
		icon:Show()
	end
	for index = #icons + 1, #row.icons do
		row.icons[index]:Hide()
	end
	row:Show()
end

local function DrawAll()
	for unit, plate in pairs(plates) do
		Draw(unit, plate)
	end
end

-- Range to a plate's unit raises no event, so the plates are asked a few times a second while any is on screen
-- and the feature is on.
---@type FunctionContainer?
local ticker

local function Sync()
	local wanted = ns.Active(KEY) and next(plates) ~= nil
	if wanted and not ticker then
		ticker = C_Timer.NewTicker(PERIOD, DrawAll)
	elseif not wanted and ticker then
		ticker:Cancel()
		ticker = nil
	end
	if ns.Active(KEY) then
		DrawAll()
	else
		for _, plate in pairs(plates) do
			Clear(plate)
		end
	end
end

ns.Init(function()
	local function Rescan()
		if ns.Active(KEY) then
			ScanSpells()
			Sync()
		end
	end
	Rescan()
	ns.OnSettingChanged(KEY, function()
		ScanSpells()
		Sync()
	end)
	ns.On("SPELLS_CHANGED", Rescan)
	ns.On("NAME_PLATE_UNIT_ADDED", function(unit)
		plates[unit] = C_NamePlate.GetNamePlateForUnit(unit)
		Sync()
	end)
	-- The plate is pooled and handed to another unit: its row goes before that.
	ns.On("NAME_PLATE_UNIT_REMOVED", function(unit)
		local plate = plates[unit]
		plates[unit] = nil
		if plate then
			Clear(plate)
		end
		Sync()
	end)
end)
