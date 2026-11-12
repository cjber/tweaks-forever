---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end
local L = ns.L

local KEY = "rangeStrip"
local ICONS_KEY, LABEL_KEY = "rangeStripIcons", "rangeStripLabel"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Range strip",
	tooltip = "A strip under the game's swing timers naming which of your attacks reach your target, from "
		.. "melee out to your longest reach, with a dead zone where a minimum range leaves a gap. It shows while the "
		.. "swing timers show, with the game's own Interface option and Edit Mode.",
	default = true,
})

ns.Feature({
	key = ICONS_KEY,
	category = "Interface",
	name = "Show icons",
	tooltip = "Each segment starts with its attack's icon: your weapon for Melee, the spell for the rest.",
	default = true,
	parent = KEY,
})

ns.Feature({
	key = LABEL_KEY,
	category = "Interface",
	name = "Show band label",
	tooltip = "The band's name in its colour under the strip.",
	default = true,
	parent = KEY,
})

-- The band keys that are not a reach of their own. Every spell reach is keyed by the spell that names it.
local MELEE, DEAD_ZONE, TOO_FAR = "melee", "dead", "far"
local NAMES = {
	[MELEE] = L["Melee"],
	[DEAD_ZONE] = L["Dead zone"],
	[TOO_FAR] = L["Too far"],
}
local COLOURS = {
	[MELEE] = { 1, 0.82, 0 },
	[DEAD_ZONE] = { 1, 0.13, 0.13 },
	[TOO_FAR] = { 0.55, 0.55, 0.55 },
}
local SPELL_R, SPELL_G, SPELL_B = 0.25, 0.75, 0.25
local UNLIT_R, UNLIT_G, UNLIT_B = 0.5, 0.5, 0.5
-- How far an unlit segment's icon tile is darkened: black over it at 0.6, leaving its colour at 40%.
local UNLIT_DIM = 0.6

-- The strip's shape, from the game's swing timer bars: segments with a square icon tile at their left (17 high with
-- icons, 15 without), 3-wide gaps, a 20-high band label under them, and 6 between the timer and the strip below it.
local LABEL_HEIGHT, SEGMENT_HEIGHT, ICON_SEGMENT_HEIGHT, SEGMENT_GAP, DOCK_GAP = 20, 15, 17, 3, 6
-- The clear between a segment's icon tile and its bar.
local ICON_GAP = 1
local SEGMENT_INSET_X, SEGMENT_INSET_Y = 4, 3
-- Each segment name keeps 3 clear on either side, so the client's own truncation lands inside its segment.
local SEGMENT_TEXT_INSET = 3
-- The game's own swing timer art, stretched by design as the game stretches its timer bars.
local BACKGROUND_ATLAS, BORDER_ATLAS = "ui-swingtimerbar-background", "ui-swingtimerbar-frame"
local FILL_ATLAS = "UI-HUD-CoolDownManager-Bar"

local TICK_INTERVAL = 0.2

-- The spell in the ranged slot's weapon, by its item subclass: bow, gun, crossbow and thrown. Any other weapon, or
-- no weapon, has no shot to name.
---@type table<integer, integer>
local RANGED_SPELLS = {
	[2] = 2480, -- bow: Shoot Bow
	[3] = 7918, -- gun: Shoot Gun
	[18] = 7919, -- crossbow: Shoot Crossbow
	[16] = 2764, -- thrown: Throw
}

-- Melee reach in yards: a spell whose own maximum is no further is not worth a segment beyond Melee.
local MELEE_REACH = 5

-- Each class's reach spells, in the order their labels read when spells share a range. The client answers each
-- spell's current range, so a talent that extends one moves it past the others; nothing here is a fixed distance.
---@type table<string, integer[]>
local REACHES = {
	WARRIOR = { 100, 20252 }, -- Charge or Intercept
	ROGUE = {},
	HUNTER = { 75 }, -- Auto Shot
	DRUID = { 16979, 5176 }, -- Feral Charge (Bear), Wrath
	-- Judgement only: Exorcism and Hammer of Wrath reach some targets and not others.
	PALADIN = { 20271 },
	MAGE = { 2136, 116, 133 }, -- Fire Blast, Frostbolt, Fireball
	PRIEST = { 585, 8092 }, -- Smite, Mind Blast
	WARLOCK = { 5782, 686 }, -- Fear, Shadow Bolt
	SHAMAN = { 8042, 403 }, -- Earth Shock, Lightning Bolt
}

-- Classes whose ranged slot is a reach of its own, joining the spells above: the shot in the slot is the reach.
---@type table<string, boolean>
local RANGED_REACH = {
	WARRIOR = true,
	ROGUE = true,
}

-- The melee spells each class checks its melee reach with: attack spells whose own range is the game's Combat Range,
-- 5 yards. The druid's two are form spells, which answer nothing outside their form. The other classes name no melee
-- attack of their own.
---@type table<string, integer[]>
local MELEE_SPELLS = {
	WARRIOR = { 78 }, -- Heroic Strike
	ROGUE = { 1752 }, -- Sinister Strike
	HUNTER = { 2973, 2974, 1495 }, -- Raptor Strike, Wing Clip, Mongoose Bite
	DRUID = { 1082, 6807 }, -- Claw, Maul
}
-- The game's own Attack, which every class also checks. It is no spellbook entry, so the client may not list it as
-- known or answer it: a true from it is melee reach, and an answer of nothing decides nothing, as any nil does.
local ATTACK_SPELL = 6603
-- A class that names no melee spell of its own still checks Attack, so the loop never allocates.
local NO_SPELLS = {}

---@class TFRangeReach
---@field key string
---@field spell integer the spell that names and checks the segment
---@field spells integer[] every spell sharing this range
---@field min integer
---@field max integer
---@field check boolean? the spell's range answer, filled in when the strip reads it

---@class TFRangeSegment
---@field key string
---@field name string
---@field colour number[]
---@field icon integer? the segment's own icon file: the equipped weapon for Melee, the spell for a spell reach

---@class TFRangeStrip
local Model = {}
ns.RangeStrip = Model

-- The shot spell of a ranged weapon subclass, or nil for a weapon with no shot.
---@param subclass integer?
---@return integer?
function Model.RangedWeapon(subclass)
	return subclass and RANGED_SPELLS[subclass] or nil
end

-- The shot spell of the weapon in the player's ranged slot, or nil when it is empty or is not a ranged weapon.
---@return integer?
function Model.EquippedRanged()
	if type(GetInventoryItemID) ~= "function" then
		return nil
	end
	local got, item = pcall(GetInventoryItemID, "player", INVSLOT_RANGED)
	if not got or not item then
		return nil
	end
	if not (C_Item and C_Item.GetItemInfoInstant) then
		return nil
	end
	local ok, _, _, _, _, _, classID, subclassID = pcall(C_Item.GetItemInfoInstant, item)
	if not ok or classID ~= 2 then
		return nil
	end
	return Model.RangedWeapon(subclassID)
end

-- Whether the player has learned a spell. A spell the client cannot answer for is not shown.
---@param spell integer
---@return boolean
function Model.Known(spell)
	if type(IsPlayerSpell) ~= "function" then
		return false
	end
	local ok, known = pcall(IsPlayerSpell, spell)
	return ok and ns.Readable(known) == true
end

-- Whether the spell reaches the current target: true, false, or nil when the game gave no answer.
---@param spell integer
---@return boolean?
function Model.Check(spell)
	if not (C_Spell and C_Spell.IsSpellInRange) then
		return nil
	end
	local ok, answer = pcall(C_Spell.IsSpellInRange, spell, "target")
	if not ok then
		return nil
	end
	return ns.Readable(answer)
end

-- The spell's name in the player's language. Spell names come from the client, so no locale string is needed.
---@param spell integer
---@return string?
function Model.SpellName(spell)
	if not (C_Spell and C_Spell.GetSpellName) then
		return nil
	end
	local ok, name = pcall(C_Spell.GetSpellName, spell)
	if not ok then
		return nil
	end
	return ns.Readable(name)
end

-- The spell's own icon, as the client draws it in the spellbook. A spell the client has no icon for has no tile.
---@param spell integer
---@return integer?
function Model.SpellTexture(spell)
	if not (C_Spell and C_Spell.GetSpellTexture) then
		return nil
	end
	local ok, texture = pcall(C_Spell.GetSpellTexture, spell)
	if not ok then
		return nil
	end
	return ns.Readable(texture)
end

-- The icon of the weapon in the player's main-hand slot, which the game's own Attack button shows. An empty slot, or
-- a client that cannot answer, has no tile.
---@return integer?
function Model.MainHandTexture()
	if type(GetInventoryItemTexture) ~= "function" then
		return nil
	end
	local ok, texture = pcall(GetInventoryItemTexture, "player", INVSLOT_MAINHAND)
	if not ok then
		return nil
	end
	return ns.Readable(texture)
end

-- The spell's current range from the client: a minimum out to a maximum, or nil when the client gives no range
-- for it. A range the addon cannot read is never guessed: the spell is left out of the strip.
---@param spell integer
---@return integer?, integer?
function Model.SpellRange(spell)
	if not (C_Spell and C_Spell.GetSpellInfo) then
		return nil
	end
	local ok, info = pcall(C_Spell.GetSpellInfo, spell)
	if not ok or type(info) ~= "table" then
		return nil
	end
	local minRange, maxRange = ns.Readable(info.minRange), ns.Readable(info.maxRange)
	if type(minRange) ~= "number" or type(maxRange) ~= "number" then
		return nil
	end
	return minRange, maxRange
end

-- The key of the segment a spell names, stable as its range moves and the segments around it regroup.
---@param spell integer
---@return string
local function SpellKey(spell)
	return "spell" .. spell
end

-- The class's known reaches for the ranged weapon in the slot, near to far. `known` says whether a spell is
-- learned (Model.Known in the game), `rangedSpell` is the equipped shot's spell, and `range` answers a spell's
-- current range. Known spells whose maximum is beyond melee are sorted by it, and spells that share one maximum
-- are one segment named by the first in table order.
---@param class string
---@param known fun(spell: integer): boolean
---@param rangedSpell integer?
---@param range? fun(spell: integer): integer?, integer?
---@return TFRangeReach[]
function Model.Reaches(class, known, rangedSpell, range)
	range = range or Model.SpellRange
	local entry = REACHES[class]
	if not entry then
		return {}
	end
	local candidates = {}
	local function Add(spell)
		if not known(spell) then
			return
		end
		local minRange, maxRange = range(spell)
		if minRange and maxRange and maxRange > MELEE_REACH then
			candidates[#candidates + 1] = {
				spell = spell,
				order = #candidates + 1,
				min = minRange,
				max = maxRange,
			}
		end
	end
	for _, spell in ipairs(entry) do
		Add(spell)
	end
	if RANGED_REACH[class] and rangedSpell then
		Add(rangedSpell)
	end
	table.sort(candidates, function(a, b)
		if a.max ~= b.max then
			return a.max < b.max
		end
		return a.order < b.order
	end)
	local reaches, byMax = {}, {}
	for _, candidate in ipairs(candidates) do
		local reach = byMax[candidate.max]
		if reach then
			reach.spells[#reach.spells + 1] = candidate.spell
		else
			reach = {
				key = SpellKey(candidate.spell),
				spell = candidate.spell,
				spells = { candidate.spell },
				min = candidate.min,
				max = candidate.max,
			}
			byMax[candidate.max] = reach
			reaches[#reaches + 1] = reach
		end
	end
	return reaches
end

-- Melee reach from the melee spells the player knows: true when any of them reaches, false when none does and at
-- least one answered, and nil when none answered or none is known, which decides nothing, as before. A spell the
-- player has not learned is skipped, and an answer of nil decides nothing either. The class's own spells are asked
-- first, then the game's Attack.
---@param class string
---@param known fun(spell: integer): boolean
---@param check fun(spell: integer): boolean?
---@return boolean?
function Model.Melee(class, known, check)
	local answeredFalse = false
	local function Reaches(spell)
		if not known(spell) then
			return false
		end
		local answer = check(spell)
		if answer == true then
			return true
		end
		if answer ~= nil then
			answeredFalse = true
		end
		return false
	end
	for _, spell in ipairs(MELEE_SPELLS[class] or NO_SPELLS) do
		if Reaches(spell) then
			return true
		end
	end
	if Reaches(ATTACK_SPELL) then
		return true
	end
	if answeredFalse then
		return false
	end
	return nil
end

-- Whether the target is within 8 yards, the game's own interact distance. The minimum-range shots players meet
-- (Auto Shot, Charge) start there. Nil when the game cannot answer, and a call that raises answers nothing either.
---@return boolean?
function Model.Interact()
	if type(CheckInteractDistance) ~= "function" then
		return nil
	end
	local ok, within = pcall(CheckInteractDistance, "target", 3)
	if not ok then
		return nil
	end
	return ns.Readable(within)
end

-- The band key, or nil when the answers cannot say. Melee wins when it reaches; otherwise the nearest reach whose
-- spell reaches (smallest maximum range); otherwise the dead zone inside the game's 8-yard check, when a shown
-- reach has a minimum range; otherwise Too far once every check said false. A nil that could change the answer
-- decides nothing, so the label stays hidden rather than naming the wrong band. `interact` is called only when the
-- dead zone could decide it.
---@param melee boolean?
---@param reaches TFRangeReach[]
---@param interact fun(): boolean?
---@return string?
function Model.Band(melee, reaches, interact)
	if melee == true then
		return MELEE
	end
	local nearest
	for _, reach in ipairs(reaches) do
		if reach.check == true and (not nearest or reach.max < nearest.max) then
			nearest = reach
		end
	end
	if nearest then
		for _, reach in ipairs(reaches) do
			if reach.check == nil and reach.max <= nearest.max then
				return nil
			end
		end
		return nearest.key
	end
	-- Melee may still be in reach when its check gave no answer, and a spell band could already be named above.
	if melee ~= false then
		return nil
	end
	local gap = false
	for _, reach in ipairs(reaches) do
		if reach.min > 0 then
			gap = true
		end
	end
	if gap then
		local within = interact()
		if within == true then
			-- A spell with no minimum could still reach inside 8 yards, so its nil answer decides against the gap.
			for _, reach in ipairs(reaches) do
				if reach.check == nil and reach.min < 8 then
					return nil
				end
			end
			return DEAD_ZONE
		elseif within == nil then
			return nil
		end
	end
	for _, reach in ipairs(reaches) do
		if reach.check == nil then
			return nil
		end
	end
	return TOO_FAR
end

ns.Init(function()
	local class = UnitClassBase("player")
	if not class or not REACHES[class] then
		return
	end
	if not (C_Spell and C_Spell.IsSpellInRange and C_Spell.GetSpellName) then
		return
	end

	local timers = {}
	if SwingTimerMainHandFrame then
		timers[#timers + 1] = SwingTimerMainHandFrame
	end
	if SwingTimerRangedFrame then
		timers[#timers + 1] = SwingTimerRangedFrame
	end
	if #timers == 0 then
		return
	end

	-- Our own frame over Blizzard's own timers: theirs is only read and hooked, never written to (WFA-38).
	local strip = CreateFrame("Frame", nil, UIParent)
	strip:SetFrameStrata("MEDIUM")
	strip:SetFrameLevel(10)
	strip:SetHeight(LABEL_HEIGHT + ICON_SEGMENT_HEIGHT)
	strip:Hide()

	-- The game's own font objects, as its swing timers use: they carry the font this locale can render, and its
	-- shadow, so no glyph comes out missing. The band label is a row under the segments, clear of the timers above.
	local label = strip:CreateFontString(nil, "OVERLAY")
	label:SetFontObject(GameFontNormal)
	label:SetJustifyH("CENTER")
	label:SetJustifyV("MIDDLE")
	label:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, 0)
	label:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", 0, 0)
	label:SetHeight(LABEL_HEIGHT)
	label:Hide()

	---@class TFRangeSegmentWidget
	---@field key string
	---@field text FontString
	---@field fill Texture
	---@field background Texture
	---@field border Texture
	---@field icon Texture
	---@field dim Texture
	---@field iconFrame Texture
	---@field iconFile integer? the segment's icon file, set from its segment when the segments are shown
	---@type table<string, TFRangeSegmentWidget>
	local widgets = {}

	-- A segment's own art and name, made once per band and reused as the class's shown reaches change.
	---@param key string
	---@return TFRangeSegmentWidget
	local function Widget(key)
		local widget = widgets[key]
		if widget then
			return widget
		end
		local background = strip:CreateTexture(nil, "BACKGROUND")
		-- art-ok: the game's swing timer bar background, stretched across a segment as the game stretches its bar
		background:SetAtlas(BACKGROUND_ATLAS)
		local fill = strip:CreateTexture(nil, "ARTWORK")
		-- art-ok: a bar fill stretched across its segment, as the game draws the bar
		fill:SetAtlas(FILL_ATLAS)
		fill:Hide()
		local border = strip:CreateTexture(nil, "OVERLAY")
		-- art-ok: the game's swing timer bar border, stretched across a segment as the game stretches its bar
		border:SetAtlas(BORDER_ATLAS)
		-- The segment's icon tile: the attack's own square icon (your weapon for Melee), black over it while its
		-- band is not lit, and the game's swing timer frame over both.
		local icon = strip:CreateTexture(nil, "ARTWORK")
		icon:Hide()
		local dim = strip:CreateTexture(nil, "ARTWORK")
		dim:SetColorTexture(0, 0, 0, UNLIT_DIM)
		dim:Hide()
		local iconFrame = strip:CreateTexture(nil, "OVERLAY")
		-- art-ok: the game's swing timer bar frame over a square icon tile, as the segment's own border
		iconFrame:SetAtlas(BORDER_ATLAS)
		iconFrame:Hide()
		local text = strip:CreateFontString(nil, "OVERLAY")
		text:SetFontObject(GameFontHighlightSmall)
		text:SetJustifyH("CENTER")
		text:SetJustifyV("MIDDLE")
		text:SetTextColor(UNLIT_R, UNLIT_G, UNLIT_B)
		text:SetWordWrap(false)
		widget = {
			key = key,
			background = background,
			fill = fill,
			border = border,
			icon = icon,
			dim = dim,
			iconFrame = iconFrame,
			text = text,
		}
		widgets[key] = widget
		return widget
	end

	-- The segment widgets in shown order, from near to far.
	---@type TFRangeSegmentWidget[]
	local shown = {}

	-- The band lit now, so a layout can dim every other segment's icon.
	local litBand

	-- The strip's two rows: segments 17 high with icons and 15 without, and a 20-high band label under them only
	-- while the label option is on.
	---@return number segmentHeight
	---@return number height
	local function Geometry()
		local segmentHeight = ns.Active(ICONS_KEY) and ICON_SEGMENT_HEIGHT or SEGMENT_HEIGHT
		return segmentHeight, segmentHeight + (ns.Active(LABEL_KEY) and LABEL_HEIGHT or 0)
	end

	-- Equal segments across the timer's width, along the strip's top, each starting with its segment's icon tile while
	-- icons are on, with its fill inset 4 x 3 and its name given the bar's height and clipped to its width: never
	-- wrapping, so a long name ends in an ellipsis inside its own band.
	local function Layout()
		local width = strip:GetWidth()
		if not width or width <= 0 or #shown == 0 then
			return
		end
		local segmentHeight, height = Geometry()
		local icons = ns.Active(ICONS_KEY)
		strip:SetHeight(height)
		local segmentWidth = (width - (#shown - 1) * SEGMENT_GAP) / #shown
		for index, widget in ipairs(shown) do
			local left = (index - 1) * (segmentWidth + SEGMENT_GAP)
			local iconFile = icons and widget.iconFile or nil
			local tile = iconFile and segmentHeight or 0
			local barLeft = left + (tile > 0 and tile + ICON_GAP or 0)
			local barWidth = segmentWidth - (barLeft - left)
			for _, texture in ipairs({ widget.background, widget.border }) do
				texture:ClearAllPoints()
				texture:SetPoint("TOPLEFT", strip, "TOPLEFT", barLeft, 0)
				texture:SetPoint("BOTTOMRIGHT", strip, "BOTTOMLEFT", barLeft + barWidth, height - segmentHeight)
			end
			widget.fill:ClearAllPoints()
			widget.fill:SetPoint("TOPLEFT", widget.background, "TOPLEFT", SEGMENT_INSET_X, -SEGMENT_INSET_Y)
			widget.fill:SetPoint("BOTTOMRIGHT", widget.background, "BOTTOMRIGHT", -SEGMENT_INSET_X, SEGMENT_INSET_Y)
			widget.text:ClearAllPoints()
			widget.text:SetPoint("TOPLEFT", widget.background, "TOPLEFT", SEGMENT_TEXT_INSET, 0)
			widget.text:SetPoint("BOTTOMRIGHT", widget.background, "BOTTOMRIGHT", -SEGMENT_TEXT_INSET, 0)
			if iconFile then
				ns.Art.Icon(widget.icon, iconFile, tile)
				for _, texture in ipairs({ widget.icon, widget.dim, widget.iconFrame }) do
					texture:ClearAllPoints()
					texture:SetPoint("TOPLEFT", strip, "TOPLEFT", left, 0)
				end
				widget.dim:SetSize(tile, tile)
				widget.iconFrame:SetSize(tile, tile)
				widget.icon:Show()
				widget.iconFrame:Show()
				widget.dim:SetShown(widget.key ~= litBand)
			else
				widget.icon:Hide()
				widget.dim:Hide()
				widget.iconFrame:Hide()
			end
		end
	end

	-- One segment per shown band, and every other segment's art and name hidden.
	---@param segments TFRangeSegment[]
	local function ShowSegments(segments)
		shown = {}
		local visible = {}
		for _, segment in ipairs(segments) do
			visible[segment.key] = true
			local widget = Widget(segment.key)
			widget.text:SetText(segment.name)
			widget.iconFile = segment.icon
			widget.background:Show()
			widget.border:Show()
			widget.text:Show()
			shown[#shown + 1] = widget
		end
		for key, widget in pairs(widgets) do
			if not visible[key] then
				widget.fill:Hide()
				widget.background:Hide()
				widget.border:Hide()
				widget.text:Hide()
				widget.icon:Hide()
				widget.dim:Hide()
				widget.iconFrame:Hide()
			end
		end
	end

	-- The band named under the strip, and its segment lit: white when lit, grey otherwise, and no segment at all
	-- for Too far or when the game gave no answer. The label row only exists while the label option is on.
	---@param band string?
	---@param segments TFRangeSegment[]
	local function Apply(band, segments)
		local bandName, bandColour
		if band == TOO_FAR then
			bandName, bandColour = NAMES[TOO_FAR], COLOURS[TOO_FAR]
		elseif band then
			for _, segment in ipairs(segments) do
				if segment.key == band then
					bandName, bandColour = segment.name, segment.colour
				end
			end
		end
		if bandName and bandColour and ns.Active(LABEL_KEY) then
			label:SetText(bandName)
			label:SetTextColor(bandColour[1], bandColour[2], bandColour[3])
			label:Show()
		else
			label:Hide()
		end
		litBand = band
		for _, segment in ipairs(segments) do
			local widget = Widget(segment.key)
			if band == segment.key then
				widget.fill:SetVertexColor(segment.colour[1], segment.colour[2], segment.colour[3])
				widget.fill:Show()
				widget.text:SetTextColor(1, 1, 1)
			else
				widget.fill:Hide()
				widget.text:SetTextColor(UNLIT_R, UNLIT_G, UNLIT_B)
			end
			-- An unlit segment's icon is darkened, as the mock draws it: black over the tile at 0.6.
			widget.dim:SetShown(widget.iconFile ~= nil and ns.Active(ICONS_KEY) and band ~= segment.key)
		end
	end

	-- The shown timer lowest on screen, which the strip docks under.
	local function LowestTimer()
		local lowest
		for _, timer in ipairs(timers) do
			if timer:IsShown() then
				if not lowest or (timer:GetBottom() or 0) < (lowest:GetBottom() or 0) then
					lowest = timer
				end
			end
		end
		return lowest
	end

	local docked
	local laidOut
	local ticker
	local Update

	local function StopTicker()
		if ticker then
			ticker:Cancel()
			ticker = nil
		end
	end

	local function StartTicker()
		if ticker then
			return
		end
		ticker = C_Timer.NewTicker(TICK_INTERVAL, function()
			ns.core.SafeCall("range strip", Update)
		end)
	end

	local function Hide()
		strip:Hide()
		docked = nil
		StopTicker()
	end

	-- The class's known reaches, rebuilt when a spell is learned, a talent moves it or the ranged weapon changes.
	---@type TFRangeReach[]
	local knownReaches = {}
	local function Refresh()
		knownReaches = Model.Reaches(class, Model.Known, Model.EquippedRanged())
	end

	-- The band and its segments, near to far: Melee, then Dead zone when a shown reach has a minimum range, then
	-- the class's known reaches with their client-side names. Each segment's icon is read here, so a changed weapon
	-- or spell icon lays the strip out again. A reach whose name cannot be read is not shown, and a strip with
	-- nothing beyond Melee has nothing to say.
	---@return string?, TFRangeSegment[]
	local function Read()
		local reaches = {}
		local spellSegments = {}
		for _, reach in ipairs(knownReaches) do
			local name = Model.SpellName(reach.spell)
			if name then
				reach.check = Model.Check(reach.spell)
				reaches[#reaches + 1] = reach
				spellSegments[#spellSegments + 1] = {
					key = reach.key,
					name = name,
					colour = { SPELL_R, SPELL_G, SPELL_B },
					icon = Model.SpellTexture(reach.spell),
				}
			end
		end
		local gap = false
		for _, reach in ipairs(reaches) do
			if reach.min > 0 then
				gap = true
			end
		end
		local segments = {
			{ key = MELEE, name = NAMES[MELEE], colour = COLOURS[MELEE], icon = Model.MainHandTexture() },
		}
		if gap then
			segments[#segments + 1] = { key = DEAD_ZONE, name = NAMES[DEAD_ZONE], colour = COLOURS[DEAD_ZONE] }
		end
		for _, segment in ipairs(spellSegments) do
			segments[#segments + 1] = segment
		end
		local band = Model.Band(Model.Melee(class, Model.Known, Model.Check), reaches, Model.Interact)
		return band, segments
	end

	-- The band and its segment lit, with every shown segment named in its own width.
	---@param band string?
	---@param segments TFRangeSegment[]
	local function Paint(band, segments)
		ShowSegments(segments)
		Apply(band, segments)
	end

	-- The segments' keys and icons, and the two shape options, in shown order. The strip lays out again only when
	-- this changes, so a changed key list, icon or option lays it out at once and a tick with none of them does not.
	---@param segments TFRangeSegment[]
	---@return string
	local function Signature(segments)
		local keys = {}
		for index, segment in ipairs(segments) do
			keys[index] = segment.icon and (segment.key .. "=" .. segment.icon) or segment.key
		end
		keys[#keys + 1] = ns.Active(ICONS_KEY) and "icons" or "no icons"
		keys[#keys + 1] = ns.Active(LABEL_KEY) and "label" or "no label"
		return table.concat(keys, "|")
	end

	function Update()
		if not ns.Active(KEY) or not ns.Readable(UnitCanAttack("player", "target")) then
			Hide()
			return
		end
		local timer = LowestTimer()
		if not timer then
			Hide()
			return
		end
		if docked ~= timer then
			docked = timer
			strip:ClearAllPoints()
			strip:SetPoint("TOPLEFT", timer, "BOTTOMLEFT", 0, -DOCK_GAP)
			strip:SetPoint("TOPRIGHT", timer, "BOTTOMRIGHT", 0, -DOCK_GAP)
		end
		-- The timer's own scale, relative to the strip's parent.
		local parentScale = UIParent:GetEffectiveScale()
		if parentScale and parentScale > 0 then
			strip:SetScale(timer:GetEffectiveScale() / parentScale)
		end
		local band, segments = Read()
		if #segments <= 1 then
			Hide()
			return
		end
		Paint(band, segments)
		strip:Show()
		local signature = Signature(segments)
		if signature ~= laidOut then
			laidOut = signature
			Layout()
		end
		-- No event says when melee reach changes now, and walking between two spell bands fires none either, so the
		-- ticker runs while the strip shows, whatever band it names.
		StartTicker()
	end

	strip:SetScript("OnSizeChanged", Layout)

	for _, timer in ipairs(timers) do
		timer:HookScript("OnShow", Update)
		timer:HookScript("OnHide", Update)
		timer:HookScript("OnSizeChanged", Update)
	end

	Refresh()
	Update()
	ns.OnSettingChanged(KEY, Update)
	ns.OnSettingChanged(ICONS_KEY, Update)
	ns.OnSettingChanged(LABEL_KEY, Update)
	ns.On("PLAYER_TARGET_CHANGED", Update)
	-- A learned spell, a talent point, a level or the ranged slot moves a range or adds a reach. The segments are
	-- rebuilt from the client's current ranges, and only a changed list lays the strip out again.
	local function ReachesChanged()
		Refresh()
		Update()
	end
	ns.On("SPELLS_CHANGED", ReachesChanged)
	ns.On("CHARACTER_POINTS_CHANGED", ReachesChanged)
	ns.On("PLAYER_EQUIPMENT_CHANGED", ReachesChanged)
	ns.On("PLAYER_LEVEL_UP", ReachesChanged)
	ns.On("PLAYER_ENTERING_WORLD", ReachesChanged)
	-- PLAYER_TALENT_UPDATE is not an event on every client this addon runs on: registering one the client lacks
	-- raises, so try it and keep the rest when it does not exist.
	pcall(ns.On, "PLAYER_TALENT_UPDATE", ReachesChanged)
end)
