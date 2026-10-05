---@type string, TFNamespace
local _, ns = ...

local L = ns.L
-- Declared before the feature, so the settings button and a row's click reach them.
local OpenPicker, RefreshPicker
local KEY = "spellReach"
local POSITION, SIZE, STYLE, TARGET_ONLY =
	"spellReachPosition", "spellReachSize", "spellReachStyle", "spellReachTargets"

-- Nameplate addons that already show range, or take over the plates the icons sit under.
ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Spell reach under nameplates",
	tooltip = "Puts a small icon for each attack you track on every enemy nameplate. An icon in full colour means that "
		.. "spell can reach the enemy; out of range it turns a solid red, fades or hides. Melee and ranged spells are "
		.. "both answered. Where the icons sit, their size, the out of range look, which plates they show on and which "
		.. "spells they follow are under this setting.",
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
	button = function()
		return OpenPicker()
	end,
})

ns.Feature({
	key = POSITION,
	category = "Interface",
	name = "Icons sit",
	tooltip = "Where the icons sit on the health bar: to its right (beside the level), to its left (beside the raid "
		.. "marker), or centred below it, clear of the cast bar.",
	default = "right",
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
	key = TARGET_ONLY,
	category = "Interface",
	name = "Only on my target",
	tooltip = "On: the icons show only on your current target's nameplate. Off: they show on every enemy.",
	default = false,
	parent = KEY,
})

-- The class's attacks, closest reach first, that the icons follow until the player picks their own. Only the
-- spells the character knows are drawn. The order is the class's main melee ability first where it fights in
-- melee, the main ranged attack first for a caster. Spell ID and range verified against the pinned Forever client
-- build 1.60.1.70205 on wago.tools (SpellMisc RangeIndex, SpellRange).
local DEFAULTS = {
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

-- Items used on an enemy whose own use range is 5 yards, the client's Combat Range (SpellRange 2), so a unit
-- inside one is in melee reach. The spell range check answers nil for a melee ability, so it cannot be asked.
-- IDs and the 5 yard band are LibRangeCheck-3.0's (MIT), the harm list Range Lens uses. Their item data must be
-- loaded before the check answers, so the first one the client holds is requested and remembered.
local MELEE_ITEMS =
	{ 8149, 15826, 16308, 17117, 22259, 22432, 206466, 208760, 208855, 209027, 209057, 213036, 221199, 225943 }
local MELEE_RANGE, MAX_TRACKED = 5, 4

local GAP, BORDER = 2, 1
local MIN_SIZE, MAX_SIZE = 50, 200
-- Out of range: a desaturated texture tinted with the vertex colour, so it reads as solid red rather than the
-- icon's own colours darkened. Faded keeps the desaturation but drops the colour and the alpha.
local OUT = { 1, 0.08, 0.08 }
local FADED = { 0.6, 0.6, 0.6 }
local FADED_ALPHA = 0.7
local PERIOD = 0.2

local WHITE = CreateColor(1, 1, 1) --[[@as colorRGBA]]
local RED = CreateColor(unpack(OUT)) --[[@as colorRGBA]]
local GREY = CreateColor(unpack(FADED)) --[[@as colorRGBA]]

---@class TFSpellReach
local Model = {}
ns.SpellReach = Model

-- The spell ids the icons follow for one character: the player's own picks for this specialisation, stance or
-- form when they have made any, otherwise the class's default attacks, in both cases only the spells still known.
---@param class string
---@param saved table<string, integer[]>
---@param context string
---@param known TFSpellKnown
---@return integer[]
function Model.Tracked(class, saved, context, known)
	local picked = saved[context]
	if not picked then
		return Model.Default(class, known)
	end
	local ids = {}
	for _, id in ipairs(picked) do
		if known(id) then
			ids[#ids + 1] = id
		end
	end
	return ids
end

-- The class's own attacks that the character knows, in the class's order.
---@param class string
---@param known TFSpellKnown
---@return integer[]
function Model.Default(class, known)
	local ids = {}
	for _, id in ipairs(DEFAULTS[class] or {}) do
		if known(id) then
			ids[#ids + 1] = id
		end
	end
	return ids
end

-- Add a spell to a tracked list or take it out again, keeping the order the player added them.
---@param list integer[]
---@param id integer
---@return integer[]
function Model.Toggle(list, id)
	for index, value in ipairs(list) do
		if value == id then
			table.remove(list, index)
			return list
		end
	end
	list[#list + 1] = id
	return list
end

-- The key one character's picks are remembered under: the active specialisation and the current stance or form,
-- so each keeps its own attacks. Both are 0 where the client has neither.
---@param group integer?
---@param form integer?
---@return string
function Model.Context(group, form)
	return string.format("%d:%d", group or 0, form or 0)
end

-- Whether a spell is fought at melee reach: a range the client files as Combat Range (5 yards), not a longer
-- ranged one. Such a spell's own range check answers nil, so the icons answer it with the 5 yard item check.
---@param maxRange number?
---@return boolean
function Model.Melee(maxRange)
	return maxRange ~= nil and maxRange > 0 and maxRange <= MELEE_RANGE
end

-- The spellbook entries worth offering: the character's own spells that can be cast on an enemy and have a range,
-- melee included, by name.
---@param ids integer[]
---@param facts TFSpellFacts
---@return TFReachChoice[]
function Model.Choices(ids, facts)
	local choices = {}
	for _, id in ipairs(ids) do
		local spell = facts(id)
		if spell and spell.harmful and spell.range and spell.range > 0 then
			choices[#choices + 1] = { id = id, name = spell.name, icon = spell.icon }
		end
	end
	table.sort(choices, function(a, b)
		return a.name < b.name
	end)
	return choices
end

-- The icons for one enemy, in the order the attacks are tracked: each with whether it reaches. A spell no read
-- answered for is left out. The client reads are passed in so the specs can drive them.
---@param ids integer[]
---@param known TFSpellKnown
---@param reaches TFSpellReaches
---@return TFReachIcon[]
function Model.Icons(ids, known, reaches)
	local icons = {}
	for _, id in ipairs(ids) do
		if known(id) then
			local answer = reaches(id)
			-- A secret answer is kept as it is: the engine reads it when the icon is drawn, never this file.
			if not canaccessvalue(answer) or answer ~= nil then
				icons[#icons + 1] = { id = id, reaches = answer }
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
-- The same spells, in book order, for the picker.
---@type integer[]
local book = {}

local function ScanSpells()
	wipe(learnt)
	wipe(book)
	for index = 1, C_SpellBook.GetNumSpellBookSkillLines() do
		local line = C_SpellBook.GetSpellBookSkillLineInfo(index)
		for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
			local item = C_SpellBook.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
			if item then
				for _, id in ipairs({ item.actionID, item.spellID }) do
					if id then
						local base = C_SpellBook.FindBaseSpellByID(id) or id
						if not learnt[base] then
							learnt[base] = true
							book[#book + 1] = base
						end
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

-- A spellbook entry's name, icon and range, and whether it can be cast on an enemy, for the picker and for
-- deciding whether its own range check can answer.
---@param id integer
---@return TFFacts?
local function Facts(id)
	local info = C_Spell.GetSpellInfo(id)
	if not info then
		return nil
	end
	return {
		name = info.name,
		icon = info.iconID,
		range = info.maxRange,
		harmful = C_Spell.IsSpellHarmful(id),
	}
end

-- Whether a spell is fought at melee reach, remembered per spell: the client gives no distance to a hostile unit.
---@type table<integer, boolean>
local melee = {}

---@param id integer
---@return boolean
local function IsMelee(id)
	local cached = melee[id]
	if cached == nil then
		local facts = Facts(id)
		cached = Model.Melee(facts and facts.range)
		melee[id] = cached
	end
	return cached
end

-- The 5 yard item the client holds, if any, and whether its data has been asked for.
---@type integer?
local meleeItem
local requested = false

---@param id integer
---@return boolean
local function ItemReady(id)
	return C_Item.GetItemInfo(id) ~= nil
end

-- Pick the first 5 yard item whose data is loaded. None loaded yet: ask the client for each once. The answer
-- arrives with GET_ITEM_INFO_RECEIVED, which redraws.
local function LoadItem()
	if meleeItem and ItemReady(meleeItem) then
		return
	end
	meleeItem = nil
	for _, id in ipairs(MELEE_ITEMS) do
		if ItemReady(id) then
			meleeItem = id
			return
		end
	end
	if not requested then
		requested = true
		for _, id in ipairs(MELEE_ITEMS) do
			if not ItemReady(id) then
				C_Item.RequestLoadItemDataByID(id)
			end
		end
	end
end

-- Whether the unit is inside melee reach: the 5 yard item check the client answers for any unit, hostile ones in
-- combat included. Nil until the item's data or a distance is known.
---@param unit string
---@return boolean?
local function MeleeReaches(unit)
	if not meleeItem then
		return nil
	end
	return C_Item.IsItemInRange(meleeItem, unit)
end

-- Whether a spell reaches the unit: the client's own range check, and a melee ability, whose range check answers
-- nil, the 5 yard item check. A secret answer is handed straight back for the engine to draw.
---@param id integer
---@param unit string
---@return boolean?
local function Reaches(id, unit)
	local answer = C_Spell.IsSpellInRange(id, unit)
	if not canaccessvalue(answer) then
		return answer
	end
	if answer == nil and IsMelee(id) then
		return MeleeReaches(unit)
	end
	return answer
end

-- The character's picks, keyed by specialisation, stance or form.
---@return table<string, integer[]>
local function Saved()
	TweaksForeverCharDB.spellReach = TweaksForeverCharDB.spellReach or {}
	return TweaksForeverCharDB.spellReach
end

---@return string
local function Class()
	local _, class = UnitClass("player")
	return class
end

---@return string
local function Context()
	-- Where the client keeps a specialisation it answers with the active one; a client without it is one context.
	local group = C_SpecializationInfo
		and C_SpecializationInfo.GetActiveSpecGroup
		and C_SpecializationInfo.GetActiveSpecGroup()
	return Model.Context(group, GetShapeshiftForm())
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
	if position == "left" then
		row:SetPoint("RIGHT", unitFrame.RaidTargetFrame or bar, "LEFT", -GAP, 0)
	elseif position == "below" then
		row:SetPoint("TOP", unitFrame.CastBarsContainer or bar, "BOTTOM", 0, -GAP)
	else
		row:SetPoint("LEFT", unitFrame.PlayerLevelDiffFrame or bar, "RIGHT", GAP, 0)
	end
end

-- The out of range look, and the plain bright icon in range. A desaturated texture is greyscale before the
-- vertex colour tints it, so solid red reads as red rather than the icon's own colours run through red. A
-- secret answer cannot be read, so the engine's own setters take it and pick one of the same looks.
---@param icon Texture
---@param border Texture
---@param reaches boolean
---@param style string?
local function Paint(icon, border, reaches, style)
	if not canaccessvalue(reaches) then
		local hidden = style == "hidden"
		icon:SetAlphaFromBoolean(reaches, 1, hidden and 0 or style == "faded" and FADED_ALPHA or 1)
		border:SetAlphaFromBoolean(reaches, 1, hidden and 0 or 1)
		icon:SetVertexColorFromBoolean(reaches, WHITE, style == "faded" and GREY or RED)
		icon:Show()
		border:Show()
		return
	end
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
	if ns.db[TARGET_ONLY] and plate ~= C_NamePlate.GetNamePlateForUnit("target") then
		Clear(plate)
		return
	end
	local ids = Model.Tracked(Class(), Saved(), Context(), Known)
	local icons = Model.Icons(ids, Known, function(id)
		return Reaches(id, unit)
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
		icon:SetTexture(C_Spell.GetSpellTexture(spell.id)) -- art-ok: a square spell icon in a square, files only
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

-- The picker: the character's own harmful spells with a range, melee included, each with a stock checkbox and
-- its icon and name, so a spell is one click. Scrolls with the game's own list widgets and scroll bar.
local ROW_HEIGHT, ICON_SIZE, PICKER_WIDTH, PICKER_HEIGHT = 40, 32, 360, 460

---@type TFSpellReachPicker?
local picker

---@param panel TFSpellReachPicker
---@param index integer
---@return TFReachPickerRow
local function PickerRow(panel, index)
	local pool = panel.Rows
	local row = pool[index]
	if not row then
		row = CreateFrame("CheckButton", nil, panel.Content, "UICheckButtonTemplate") --[[@as TFReachPickerRow]]
		row:SetSize(PICKER_WIDTH - 76, ROW_HEIGHT)
		row.Icon = row:CreateTexture(nil, "ARTWORK")
		row.Icon:SetSize(ICON_SIZE, ICON_SIZE)
		row.Icon:SetPoint("LEFT", row, "LEFT", 34, 0)
		row.Text:ClearAllPoints()
		row.Text:SetPoint("LEFT", row.Icon, "RIGHT", 8, 0)
		row.Text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		row.Text:SetJustifyH("LEFT")
		row.Text:SetFontObject("GameFontNormal")
		row:SetScript("OnClick", function(self)
			local saved = Saved()
			local list = saved[Context()]
			if not list then
				-- The class's own attacks are on screen, so the first pick starts from those.
				list = {}
				for _, id in ipairs(Model.Default(Class(), Known)) do
					list[#list + 1] = id
				end
				saved[Context()] = list
			end
			Model.Toggle(list, self.spell)
			RefreshPicker()
			if ns.Active(KEY) then
				DrawAll()
			end
		end)
		pool[index] = row
	end
	return row
end

-- Fill the panel for the current character, specialisation, stance or form: every known harmful spell with a
-- range, melee included, the tracked ones ticked, the rest disabled once the row is full.
function RefreshPicker()
	local panel = assert(picker)
	local choices = Model.Choices(book, Facts)
	local tracked = Model.Tracked(Class(), Saved(), Context(), Known)
	local chosen = {}
	for _, id in ipairs(tracked) do
		chosen[id] = true
	end
	local full = #tracked >= MAX_TRACKED
	for index, choice in ipairs(choices) do
		local row = PickerRow(panel, index)
		row.spell = choice.id
		row.Icon:SetTexture(choice.icon) -- art-ok: a square spell icon in a square, files only
		row.Text:SetText(choice.name)
		row:SetChecked(chosen[choice.id] == true)
		row:SetEnabled(chosen[choice.id] == true or not full)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
		row:Show()
	end
	for index = #choices + 1, #panel.Rows do
		panel.Rows[index]:Hide()
	end
	panel.Content:SetHeight(math.max(#choices * ROW_HEIGHT, 1))
end

---@return TFSpellReachPicker
local function BuildPicker()
	local panel = CreateFrame("Frame", "TweaksForeverSpellReachPicker", UIParent, "BasicFrameTemplateWithInset")
	---@cast panel TFSpellReachPicker
	panel:SetSize(PICKER_WIDTH, PICKER_HEIGHT)
	panel:SetFrameStrata("DIALOG")
	panel:SetClampedToScreen(true)
	panel.TitleText:SetText(L["Spells to track"])
	local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	note:SetPoint("TOPLEFT", 20, -40)
	note:SetPoint("RIGHT", -20, 0)
	note:SetJustifyH("LEFT")
	note:SetText(L["Tick the spells the icons follow, up to four. Melee and ranged spells can be mixed."])
	local scroll = CreateFrame("ScrollFrame", nil, panel, "ScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 24, -78)
	scroll:SetPoint("BOTTOMRIGHT", -36, 20)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetWidth(PICKER_WIDTH - 76)
	scroll:SetScrollChild(content)
	panel.Content, panel.Rows = content, {}
	panel:SetScript("OnKeyDown", function(self, key)
		self:SetPropagateKeyboardInput(key ~= "ESCAPE")
		if key == "ESCAPE" then
			self:Hide()
		end
	end)
	panel:EnableKeyboard(true)
	picker = panel
	return panel
end

---@return TFSpellReachPicker
function OpenPicker()
	local panel = picker or BuildPicker()
	ScanSpells()
	RefreshPicker()
	panel:Show()
	return panel
end

-- Exposed for the settings button, and for the specs to drive the panel without a client.
ns.SpellReach.Open = OpenPicker
ns.SpellReach.Refresh = RefreshPicker

ns.Init(function()
	-- A saved "Show on" choice from before the toggle: a target-only player keeps that.
	if ns.db[TARGET_ONLY] == "target" then
		ns.db[TARGET_ONLY] = true
	elseif ns.db[TARGET_ONLY] == "all" then
		ns.db[TARGET_ONLY] = false
	end
	local function Rescan()
		if ns.Active(KEY) then
			ScanSpells()
			LoadItem()
		end
		Sync()
	end
	Rescan()
	ns.OnSettingChanged(KEY, Rescan)
	-- Position, size, out of range look and which plates redraw on the next tick, with no reload.
	for _, key in ipairs({ POSITION, SIZE, STYLE, TARGET_ONLY }) do
		ns.OnSettingChanged(key, Sync)
	end
	ns.On("SPELLS_CHANGED", Rescan)
	ns.On("GET_ITEM_INFO_RECEIVED", function()
		if ns.Active(KEY) then
			LoadItem()
			Sync()
		end
	end)
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
