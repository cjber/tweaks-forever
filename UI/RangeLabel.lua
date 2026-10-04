---@type string, TFNamespace
local _, ns = ...
local L = ns.L

local KEY = "targetRange"

-- Nameplate addons that already show range, or take over the plates the label sits on.
ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Range to your target",
	tooltip = "Shows how far your target is, in the game's own font on the target frame's health bar and on the "
		.. "target's nameplate: Melee, the band of your main attack such as 8-35, or how far past it the target "
		.. "is. The bands come from the class spells you know, so they follow your character. Hidden with no "
		.. "target or with a dead one.",
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

-- The class spells that set the range bands, closest reach first: the melee ability where the class has one,
-- then its main attack, then a longer spell where it has one. Only the spells the character knows are used, and
-- each band's yards are the client's own spell data. Spell ID and range verified against the pinned Forever
-- client build 1.60.1.70205 on wago.tools (SpellMisc RangeIndex, SpellRange RangeMin/RangeMax).
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

-- Every band of the class the character knows, ascending by reach: each melee or ranged spell the book holds,
-- with its yards and whether the target is inside. The client reads are passed in so the specs can drive them.
---@param class string
---@param known fun(id: integer): boolean
---@param info fun(id: integer): SpellInfo?
---@param inRange fun(id: integer): boolean
---@return TFRangeBand[]
function Model.Bands(class, known, info, inRange)
	local bands = {}
	for _, spell in ipairs(SPELLS[class] or {}) do
		local facts = known(spell.id) and info(spell.id)
		if facts then
			bands[#bands + 1] = {
				min = facts.minRange,
				max = facts.maxRange,
				melee = spell.melee,
				inRange = inRange(spell.id),
			}
		end
	end
	return bands
end

-- The band the target falls in: the closest reach it is inside, or how far past the longest one it is. Inside a
-- melee ability reads "Melee", or "Too close" when a longer spell starts beyond that reach.
---@param bands TFRangeBand[] ascending by max
---@return TFRangeLabel
function Model.Label(bands)
	local inside
	for _, band in ipairs(bands) do
		if band.inRange then
			inside = band
			break
		end
	end
	if not inside then
		return { kind = "beyond", max = bands[#bands].max }
	end
	if inside.melee then
		for _, band in ipairs(bands) do
			if not band.inRange and band.min > inside.max then
				return { kind = "close" }
			end
		end
		return { kind = "melee" }
	end
	return { kind = "span", min = inside.min, max = inside.max }
end

-- The English labels, as whole phrases for translators; a band is its format string.
local LABELS = {
	melee = L["Melee"],
	close = L["Too close"],
	span = L["%d-%d"],
	beyond = L["%d+"],
}

---@param label TFRangeLabel
---@return string
local function Text(label)
	if label.kind == "span" then
		return LABELS.span:format(label.min, label.max)
	end
	if label.kind == "beyond" then
		return LABELS.beyond:format(label.max)
	end
	return LABELS[label.kind]
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
	return Model.Bands(class, Known, C_Spell.GetSpellInfo, inRange)
end

-- The FontStrings drawn, by the bar they sit on. Weak keys: a plate is pooled, and its label lives and dies with
-- it. Blizzard's frames never have a field of ours written to them.
---@type table<Frame, FontString>
local labels = setmetatable({}, { __mode = "k" })
-- The labels shown right now, so a target change hides the last plate's.
---@type FontString[]
local shown = {}

-- The nameplate frame the target's label is on, so the plate it leaves is cleared before the client pools it for
-- another unit.
---@type NamePlateFrame?
local plateFrame

---@param bar Frame
---@param font string
---@param x number
---@return FontString
local function Attach(bar, font, x)
	local label = labels[bar]
	if not label then
		label = bar:CreateFontString(nil, "OVERLAY", font)
		label:SetPoint("LEFT", bar, "LEFT", x, 0)
		label:SetJustifyH("LEFT")
		label:SetTextColor(1, 1, 1, 0.85)
		labels[bar] = label
	end
	return label
end

---@param bar Frame
---@param font string
---@param x number
---@param text string
local function Draw(bar, font, x, text)
	local label = Attach(bar, font, x)
	label:SetText(text)
	label:Show()
	shown[#shown + 1] = label
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
	for _, label in ipairs(shown) do
		label:Hide()
	end
	wipe(shown)
	plateFrame = nil
	if not ns.Active(KEY) or not UnitExists("target") or UnitIsDeadOrGhost("target") then
		return
	end
	local bands = Bands()
	if #bands == 0 then
		return
	end
	local text = Text(Model.Label(bands))
	local bar = TargetBar()
	if bar then
		Draw(bar, "TextStatusBarText", 4, text)
	end
	local frame, plateBar = TargetPlate()
	if plateBar then
		Draw(plateBar, "SystemFont_NamePlate_Outlined", 2, text)
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
	-- The plate the label is on leaves: clear it before the plate is pooled and handed to another unit.
	ns.On("NAME_PLATE_UNIT_REMOVED", function(unit)
		if C_NamePlate.GetNamePlateForUnit(unit) == plateFrame then
			Render()
		end
	end)
	ns.On("PLAYER_ENTERING_WORLD", Render)
end)
