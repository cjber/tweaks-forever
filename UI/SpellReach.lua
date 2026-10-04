---@type string, TFNamespace
local _, ns = ...

local KEY = "spellReach"
local POSITION, SIZE, STYLE, TARGETS = "spellReachPosition", "spellReachSize", "spellReachStyle", "spellReachTargets"

-- Nameplate addons that already show range, or take over the plates the icons sit under.
ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Spell reach under nameplates",
	tooltip = "Puts a small icon for each of your class's main attacks on every enemy nameplate. An icon in full "
		.. "colour means that spell can reach the enemy; out of range it turns a solid red, fades or hides. The "
		.. "icons follow the spells you know, one for each reach: a shaman sees a shock and Lightning Bolt. "
		.. "Position, size and the out of range look are under this setting.",
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

ns.Feature({
	key = POSITION,
	category = "Interface",
	name = "Icons sit",
	tooltip = "Where the icons sit on the health bar: to its left (beside the raid marker), to its right (beside "
		.. "the level), or centred below it, clear of the cast bar.",
	default = "left",
	options = {
		{ "left", "Left of the health bar" },
		{ "right", "Right of the health bar" },
		{ "below", "Below the health bar" },
	},
	parent = KEY,
})

ns.Feature({
	key = SIZE,
	category = "Interface",
	name = "Icon size",
	tooltip = "The icon's size as a percentage of the health bar's height. 100% matches the bar.",
	default = 100,
	slider = { min = 50, max = 200, step = 5 },
	parent = KEY,
})

ns.Feature({
	key = STYLE,
	category = "Interface",
	name = "Out of range icons",
	tooltip = "A spell that cannot reach the enemy turns a solid red, fades out or hides, so what reaches is clear "
		.. "at a glance.",
	default = "red",
	options = {
		{ "red", "Red" },
		{ "faded", "Faded" },
		{ "hidden", "Hidden" },
	},
	parent = KEY,
})

ns.Feature({
	key = TARGETS,
	category = "Interface",
	name = "Show on",
	tooltip = "Show the icons on every enemy at once, or only on your current target's nameplate.",
	default = "all",
	options = {
		{ "all", "All enemies" },
		{ "target", "Target only" },
	},
	parent = KEY,
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

local GAP, BORDER = 2, 1
local MIN_SIZE, MAX_SIZE = 50, 200
-- Out of range: a desaturated texture tinted with the vertex colour, so it reads as solid red rather than the
-- icon's own colours darkened. Faded keeps the desaturation but drops the colour and the alpha.
local OUT = { 1, 0.08, 0.08 }
local FADED = { 0.6, 0.6, 0.6 }
local FADED_ALPHA = 0.7
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

-- The size one icon is drawn at: the health bar's height scaled by the chosen percentage. The default of 100%
-- is the bar height, so the icons sit in the plate at the same scale as the game's own art.
---@param barHeight number
---@param percent number?
---@return integer
function Model.Size(barHeight, percent)
	local scale = math.min(MAX_SIZE, math.max(MIN_SIZE, tonumber(percent) or 100))
	return math.max(1, math.floor(barHeight * scale / 100 + 0.5))
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

-- The icon rows drawn, by the plate they hang on. Weak keys: a plate is pooled, and its row lives and dies
-- with it. Blizzard's frames never have a field of ours written to them.
---@type table<NamePlateFrame, TFReachRow>
local rows = setmetatable({}, { __mode = "k" })
-- The plates on screen, by the unit token each carries.
---@type table<string, NamePlateFrame>
local plates = {}

-- Parented to the plate, not its unit frame: a plate is pooled and takes a fresh unit frame each time it is
-- handed a unit, and the row must follow the plate rather than the frame it was first built under.
---@param plate NamePlateFrame
---@return TFReachRow
local function Row(plate)
	local row = rows[plate]
	if not row then
		local unitFrame = plate.UnitFrame
		row = CreateFrame("Frame", nil, plate) --[[@as TFReachRow]]
		if unitFrame and unitFrame.GetFrameLevel then
			row:SetFrameLevel(unitFrame:GetFrameLevel() + 5)
		end
		row.icons = {}
		row.borders = {}
		rows[plate] = row
	end
	return row
end

-- The dark 1 px edge round an icon, drawn behind it in the stock plate's own style, so the icon is not a raw
-- square of art.
---@param row TFReachRow
---@param index integer
---@return Texture
local function Border(row, index)
	local border = row.borders[index]
	if not border then
		border = row:CreateTexture(nil, "BACKGROUND")
		border:SetColorTexture(0, 0, 0, 0.8)
		row.borders[index] = border
	end
	return border
end

---@param row TFReachRow
---@param index integer
---@return Texture
local function Icon(row, index)
	local icon = row.icons[index]
	if not icon then
		icon = row:CreateTexture(nil, "ARTWORK")
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

-- The health bar's height in the plate's own units, which our row shares. The bar can be absent before Blizzard
-- has laid the plate out; the stock Medium height stands in.
---@param unitFrame NamePlateUnitFrame
---@return number
local function BarHeight(unitFrame)
	local health = unitFrame.HealthBarsContainer
	local bar = health and health.healthBar
	local height = bar and bar.GetHeight and bar:GetHeight()
	if type(height) == "number" and height > 0 then
		return height
	end
	return 14
end

-- Lay the row against the health bar's neighbours, vertically centred on the bar when beside it and centred
-- under it otherwise. Beside the bar the icons clear the raid marker on the left and the level on the right;
-- below the bar they clear the stock cast bar by sitting under the plate.
---@param row TFReachRow
---@param unitFrame NamePlateUnitFrame
---@param size integer
---@param count integer
local function Place(row, unitFrame, size, count)
	local health = unitFrame.HealthBarsContainer
	local bar = health and health.healthBar or health
	row:SetSize(count * size + (count - 1) * GAP, size)
	row:ClearAllPoints()
	local position = ns.db[POSITION]
	if position == "right" then
		row:SetPoint("LEFT", unitFrame.PlayerLevelDiffFrame or bar, "RIGHT", GAP, 0)
	elseif position == "below" then
		row:SetPoint("TOP", unitFrame.CastBarsContainer or bar, "BOTTOM", 0, -GAP)
	else
		row:SetPoint("RIGHT", unitFrame.RaidTargetFrame or bar, "LEFT", -GAP, 0)
	end
end

-- The out of range look, and the plain bright icon in range. A desaturated texture is greyscale before the
-- vertex colour tints it, so solid red reads as red rather than the icon's own colours run through red.
---@param icon Texture
---@param border Texture
---@param reaches boolean
---@param style string?
local function Paint(icon, border, reaches, style)
	icon:SetDesaturated(not reaches)
	if reaches then
		icon:SetVertexColor(1, 1, 1)
		icon:SetAlpha(1)
	elseif style == "hidden" then
		icon:Hide()
		border:Hide()
		return
	elseif style == "faded" then
		icon:SetVertexColor(unpack(FADED))
		icon:SetAlpha(FADED_ALPHA)
	else
		icon:SetVertexColor(unpack(OUT))
		icon:SetAlpha(1)
	end
	icon:Show()
	border:Show()
end

---@param unit string
---@param plate NamePlateFrame
local function Draw(unit, plate)
	local unitFrame = plate.UnitFrame
	if not unitFrame or not UnitCanAttack("player", unit) or UnitIsDeadOrGhost(unit) then
		Clear(plate)
		return
	end
	-- Target only: the token's own plate is the one the game hands back, so no unit comparison that can be
	-- secret in an instance is needed.
	if ns.db[TARGETS] == "target" and plate ~= C_NamePlate.GetNamePlateForUnit("target") then
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
	local row = Row(plate)
	local size = Model.Size(BarHeight(unitFrame), ns.db[SIZE])
	Place(row, unitFrame, size, #icons)
	local style = ns.db[STYLE]
	for index, spell in ipairs(icons) do
		local icon, border = Icon(row, index), Border(row, index)
		icon:ClearAllPoints()
		icon:SetPoint("LEFT", row, "LEFT", (index - 1) * (size + GAP), 0)
		icon:SetSize(size, size)
		icon:SetTexture(C_Spell.GetSpellTexture(spell.id))
		border:ClearAllPoints()
		border:SetPoint("TOPLEFT", icon, "TOPLEFT", -BORDER, BORDER)
		border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", BORDER, -BORDER)
		Paint(icon, border, spell.reaches, style)
	end
	for index = #icons + 1, #row.icons do
		row.icons[index]:Hide()
		row.borders[index]:Hide()
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
		end
		Sync()
	end
	Rescan()
	ns.OnSettingChanged(KEY, Rescan)
	-- Position, size, out of range look and which plates redraw on the next tick, with no reload.
	for _, key in ipairs({ POSITION, SIZE, STYLE, TARGETS }) do
		ns.OnSettingChanged(key, Sync)
	end
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
