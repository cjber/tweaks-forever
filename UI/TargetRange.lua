---@type string, TFNamespace
local _, ns = ...

local KEY = "targetRange"

-- Nameplate addons that already show range, or take over the plates the shade sits on.
ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Shade a target out of range",
	tooltip = "Lays a faint red shade over your target's health bar, on the target frame and on its nameplate, "
		.. "while your attacks cannot reach it, the way an action button reddens. It follows the class spells "
		.. "you know: your ranged attacks, or your melee ability when you have none. No shade with no target or "
		.. "with a dead one.",
	default = false,
	conflicts = {
		{ addon = "Plater" },
		{ addon = "Kui_Nameplates" },
		{ addon = "NeatPlates" },
		{ addon = "TidyPlates_ThreatPlates" },
		{ addon = "Platynator" },
		{ addon = "ElvUI" },
	},
})

-- The class spells that say whether the target can be reached: the melee ability where the class has one, then
-- its ranged attacks. Only the spells the character knows are used, and the client answers for each whether the
-- target is inside its range; it gives no distance in yards to a hostile unit. Spell ID and range verified
-- against the pinned Forever client build 1.60.1.70205 on wago.tools (SpellMisc RangeIndex, SpellRange).
local SPELLS = {
	WARRIOR = { { id = 78, melee = true } }, -- Heroic Strike, 0-5
	PALADIN = { { id = 20271 }, { id = 879 } }, -- Judgement 0-10, Exorcism 0-30
	HUNTER = { { id = 2973, melee = true }, { id = 75 } }, -- Raptor Strike 0-5, Auto Shot 8-35
	ROGUE = { { id = 1752, melee = true } }, -- Sinister Strike 0-5
	PRIEST = { { id = 585 } }, -- Smite 0-30
	SHAMAN = { { id = 8042 }, { id = 403 } }, -- Earth Shock 0-20, Lightning Bolt 0-30
	MAGE = { { id = 116 }, { id = 133 } }, -- Frostbolt 0-30, Fireball 0-35
	WARLOCK = { { id = 686 } }, -- Shadow Bolt 0-30
	DRUID = { { id = 6807, melee = true }, { id = 5176 } }, -- Maul 0-5, Wrath 0-30
}

---@class TFTargetRange
local Model = {}
ns.TargetRange = Model

-- Every band of the class the character knows: each melee or ranged spell the book holds, and whether the
-- target is inside it. The client reads are passed in so the specs can drive them.
---@param class string
---@param known fun(id: integer): boolean
---@param inRange fun(id: integer): boolean
---@return TFRangeBand[]
function Model.Bands(class, known, inRange)
	local bands = {}
	for _, spell in ipairs(SPELLS[class] or {}) do
		if known(spell.id) then
			bands[#bands + 1] = { melee = spell.melee, inRange = inRange(spell.id) }
		end
	end
	return bands
end

-- Whether the target is out of reach: outside every ranged attack the character knows, or outside the melee
-- ability when it knows no ranged one. A hunter inside Auto Shot's minimum range is out of reach of the shot.
---@param bands TFRangeBand[]
---@return boolean
function Model.OutOfReach(bands)
	local ranged = false
	for _, band in ipairs(bands) do
		ranged = ranged or not band.melee
	end
	for _, band in ipairs(bands) do
		if band.inRange and (not ranged or not band.melee) then
			return false
		end
	end
	return #bands > 0
end

-- The class's spell IDs, to pick our own out of SPELL_RANGE_CHECK_UPDATE, which fires for every spell the UI
-- watches.
---@type table<integer, true>
local ours = {}
for _, list in pairs(SPELLS) do
	for _, spell in ipairs(list) do
		ours[spell.id] = true
	end
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

-- Spells whose range the client watches for us. Enabled once and left alone: the flag is not refcounted, so
-- switching it off when the feature does would break Blizzard's own range check for the same spell.
---@type table<integer, true>
local watched = {}

---@param id integer
local function Watch(id)
	if not watched[id] and C_Spell.SpellHasRange(id) then
		watched[id] = true
		C_Spell.EnableSpellRangeCheck(id, true)
	end
end

---@return TFRangeBand[]
local function Bands()
	local _, class = UnitClass("player")
	for _, spell in ipairs(SPELLS[class] or {}) do
		if Known(spell.id) then
			Watch(spell.id)
		end
	end
	local function inRange(id)
		return C_Spell.IsSpellInRange(id, "target")
	end
	return Model.Bands(class, Known, inRange)
end

-- The shades drawn, by the bar they cover. Weak keys: a plate is pooled, and its shade lives and dies with it.
-- Blizzard's frames never have a field of ours written to them.
---@type table<Frame, Texture>
local shades = setmetatable({}, { __mode = "k" })
-- The shades shown right now, so a target change clears the last plate's.
---@type Texture[]
local shown = {}

-- The nameplate frame the target's shade is on, so the plate it leaves is cleared before the client pools it for
-- another unit.
---@type NamePlateFrame?
local plateFrame

---@param bar Frame
local function Shade(bar)
	local shade = shades[bar]
	if not shade then
		shade = bar:CreateTexture(nil, "OVERLAY")
		shade:SetAllPoints(bar)
		shade:SetColorTexture(0.45, 0, 0, 0.5)
		shades[bar] = shade
	end
	shade:Show()
	shown[#shown + 1] = shade
end

-- The target frame's health bar, as the frame XML lays it out.
---@return StatusBar?
local function TargetBar()
	local content = TargetFrame and TargetFrame.TargetFrameContent
	local main = content and content.TargetFrameContentMain
	local health = main and main.HealthBarsContainer
	return health and health.HealthBar
end

-- The current target's nameplate, when a plate of ours has it.
---@return NamePlateFrame?, NamePlateHealthBar?
local function TargetPlate()
	local frame = C_NamePlate.GetNamePlateForUnit("target")
	local unit = frame and frame.UnitFrame
	local health = unit and unit.HealthBarsContainer
	return frame, health and health.healthBar
end

local lastDead = false

local function Render()
	for _, shade in ipairs(shown) do
		shade:Hide()
	end
	wipe(shown)
	plateFrame = nil
	if not ns.Active(KEY) or not UnitExists("target") or UnitIsDeadOrGhost("target") then
		return
	end
	if not Model.OutOfReach(Bands()) then
		return
	end
	local bar = TargetBar()
	if bar then
		Shade(bar)
	end
	local frame, plateBar = TargetPlate()
	if plateBar then
		Shade(plateBar)
		plateFrame = frame
	end
end

ns.Init(function()
	local function Rescan()
		if ns.Active(KEY) then
			ScanSpells()
			Render()
		end
	end
	Rescan()
	ns.OnSettingChanged(KEY, function()
		ScanSpells()
		Render()
	end)
	ns.On("SPELLS_CHANGED", Rescan)
	ns.On("SPELL_RANGE_CHECK_UPDATE", function(spellID)
		if ours[spellID] then
			Render()
		end
	end)
	ns.On("PLAYER_TARGET_CHANGED", function()
		lastDead = UnitExists("target") and UnitIsDeadOrGhost("target") or false
		Render()
	end)
	-- Only on the moment a target dies or comes back: health changes are far more frequent than a death.
	ns.On("UNIT_HEALTH", function(unit)
		if unit == "target" then
			local dead = UnitIsDeadOrGhost("target")
			if dead ~= lastDead then
				lastDead = dead
				Render()
			end
		end
	end)
	-- A plate's unit token is a nameplate token, not "target", so the plate is compared to the one the target
	-- resolves to.
	ns.On("NAME_PLATE_UNIT_ADDED", function(unit)
		local frame = C_NamePlate.GetNamePlateForUnit(unit)
		if frame and frame == C_NamePlate.GetNamePlateForUnit("target") then
			Render()
		end
	end)
	-- The plate the shade is on leaves: clear it before the plate is pooled and handed to another unit.
	ns.On("NAME_PLATE_UNIT_REMOVED", function(unit)
		if C_NamePlate.GetNamePlateForUnit(unit) == plateFrame then
			Render()
		end
	end)
	ns.On("PLAYER_ENTERING_WORLD", Render)
end)
