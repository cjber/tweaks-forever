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
	section = "Bars and alerts",
	name = "Range strip",
	tooltip = "A strip under the game's swing timers naming which of your attacks reach your target, from "
		.. "melee out to your longest reach, with a dead zone where a minimum range leaves a gap. It shows with any "
		.. "attackable target, in combat or not, where the swing timers sit, even while they are hidden.",
	default = true,
})

ns.Feature({
	key = ICONS_KEY,
	category = "Interface",
	section = "Bars and alerts",
	name = "Show icons",
	tooltip = "Each segment starts with its attack's icon: your weapon for Melee, the spell for the rest.",
	default = true,
	parent = KEY,
})

ns.Feature({
	key = LABEL_KEY,
	category = "Interface",
	section = "Bars and alerts",
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

-- Melee reach in yards, measured as the spell ranges are, from the player's edge to the target's: a spell whose own
-- maximum is no further is not worth a segment beyond Melee. The client measures spell ranges between the two
-- creatures' edges and the swing between their centres against both combat reaches plus 4/3 (at least 5), so in edge
-- terms the swing never reaches past 5 yards whatever the target's size; that is what lets a spell's answer rule
-- melee out while the swing check is silent out of combat.
local MELEE_REACH = 5

-- What the game's interact check (Model.Interact) says about distance: true puts the target nearer than 10 yards
-- (the duel distance, 9.9). The check's yards are server constants the API does not describe, and a false answer
-- puts nothing under the target's distance: it can stand inside any reach's minimum range as well as beyond.
local INTERACT_FAR = 10
-- The follow distance check (Model.Follow, CheckInteractDistance index 4), the client's 28 yards: true puts the target
-- within 28 and false beyond it. It is the same family of server constants as the duel distance (the shortest-path-
-- forever Routing/Band.lua header calls them server constants, and LibRangeCheck-3.0 lists index 4 as 28 yd), so
-- the API does not describe how it measures.
local FOLLOW = 28

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

-- Whether the target is in melee reach: the game's own answer for the main-hand auto attack, the one its Main Hand
-- swing timer dims by. Nil when the client made no check (no weapon, or no check enabled for the swing), which decides
-- nothing. The client checks a swing's range only while a check is enabled for it (C_SwingTimer.EnableRangeCheck): the
-- game's own timer enables it for itself, and the strip enables its own while it shows (SwingCheck).
---@return boolean?
function Model.Melee()
	if not (C_SwingTimer and C_SwingTimer.IsTargetWithinSwingRange and Enum and Enum.PlayerSwingType) then
		return nil
	end
	local ok, within = pcall(C_SwingTimer.IsTargetWithinSwingRange, Enum.PlayerSwingType.MainHand)
	if not ok then
		return nil
	end
	return ns.Readable(within)
end

-- Whether the game's follow distance check reaches the target: true within 28 yards, false beyond. Nil when the game
-- cannot answer, and a call that raises answers nothing either.
---@return boolean?
function Model.Follow()
	if type(CheckInteractDistance) ~= "function" then
		return nil
	end
	local ok, within = pcall(CheckInteractDistance, "target", 4)
	if not ok then
		return nil
	end
	return ns.Readable(within)
end

-- Whether the game's interact check (the duel distance) reaches the target: true puts it within 10 yards, false says
-- nothing about how near it is. Nil when the game cannot answer, and a call that raises answers nothing either.
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

-- The band a target at `distance` yards stands in: Melee inside melee reach; otherwise the nearest reach that
-- reaches it (smallest maximum range); otherwise the dead zone, inside a shown reach's minimum range; otherwise Too
-- far.
---@param distance number
---@param reaches TFRangeReach[]
---@return string
local function BandAt(distance, reaches)
	if distance <= MELEE_REACH then
		return MELEE
	end
	local nearest
	local inside = false
	for _, reach in ipairs(reaches) do
		if distance >= reach.min and distance <= reach.max and (not nearest or reach.max < nearest.max) then
			nearest = reach
		end
		inside = inside or distance < reach.min
	end
	if nearest then
		return nearest.key
	end
	if inside then
		return DEAD_ZONE
	end
	return TOO_FAR
end

-- The one band every distance agreeing with the answers puts the target in, or nil when they leave more than one.
-- False when no distance agrees: the answers break the yard model.
-- The bands change only at the range edges, so each edge, a point between two edges and one past the last stand for
-- every distance.
---@param melee boolean?
---@param interact boolean?
---@param follow boolean?
---@param reaches TFRangeReach[]
---@return string|false|nil
local function Solve(melee, interact, follow, reaches)
	local edges = { 0, MELEE_REACH, INTERACT_FAR, FOLLOW }
	for _, reach in ipairs(reaches) do
		edges[#edges + 1] = reach.min
		edges[#edges + 1] = reach.max
	end
	table.sort(edges)
	local samples = {}
	for i, edge in ipairs(edges) do
		samples[#samples + 1] = edge
		samples[#samples + 1] = edges[i + 1] and (edge + edges[i + 1]) / 2 or edge + 1
	end
	---@type string|false
	local band = false
	for _, distance in ipairs(samples) do
		local agrees = (melee == nil or melee == (distance <= MELEE_REACH))
			and (interact ~= true or distance < INTERACT_FAR)
			and (follow == nil or follow == (distance <= FOLLOW))
		for _, reach in ipairs(reaches) do
			if reach.check ~= nil and reach.check ~= (distance >= reach.min and distance <= reach.max) then
				agrees = false
			end
		end
		if agrees then
			local here = BandAt(distance, reaches)
			if band and band ~= here then
				return nil
			end
			band = here
		end
	end
	return band
end

-- The band key, or nil when the answers cannot say. Each answer narrows where the target can stand: melee from the
-- game's swing range, each reach from its spell, and the game's interact check. A band is named only when every
-- distance left gives that band, so a missing answer hides only the bands it could change and never names a wrong
-- one. `interact` and `follow` are called only when the other answers leave more than one band.
---@param melee boolean?
---@param reaches TFRangeReach[]
---@param interact fun(): boolean?
---@param follow? fun(): boolean?
---@return string?
function Model.Band(melee, reaches, interact, follow)
	-- The game's own swing answer wins outright.
	if melee == true then
		return MELEE
	end
	local band = Solve(melee, nil, nil, reaches)
	if band == nil then
		band = Solve(melee, interact(), nil, reaches)
	end
	if band == nil and follow then
		band = Solve(melee, interact(), follow(), reaches)
	end
	-- No distance fits every answer: something the yard model does not hold for, so no band can be named safely.
	return band or nil
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

	-- The timer lowest on screen, which the strip docks under: the lowest shown one, or while none shows, the lowest
	-- where they would, so the strip sits in the same place with the swing timers hidden.
	local function LowestTimer()
		local lowest
		for _, timer in ipairs(timers) do
			if not lowest then
				lowest = timer
			elseif timer:IsShown() ~= lowest:IsShown() then
				lowest = timer:IsShown() and timer or lowest
			elseif (timer:GetBottom() or 0) < (lowest:GetBottom() or 0) then
				lowest = timer
			end
		end
		return lowest
	end

	-- Whether the strip enabled the main-hand swing range check, so it gives back only its own: the game's timer
	-- enables the same check for itself, and a check it holds is left alone.
	local ownSwingCheck = false

	-- The client answers the swing range only while a check is enabled for it, and the game's own timer enables it
	-- only while it shows. While the strip shows with that timer's check off (swing timers hidden), it enables its own;
	-- the game may switch the check off again when its timer changes, so the strip asks again on every update.
	local function SwingCheck(wanted)
		local main = SwingTimerMainHandFrame
		if not (C_SwingTimer and C_SwingTimer.EnableRangeCheck and Enum and Enum.PlayerSwingType and main) then
			return
		end
		-- The mixin method is not in the client annotations.
		---@cast main table
		local native = type(main.IsRangeCheckEnabled) == "function" and main:IsRangeCheckEnabled() or false
		if wanted and not native then
			pcall(C_SwingTimer.EnableRangeCheck, Enum.PlayerSwingType.MainHand, true)
			ownSwingCheck = true
		elseif not wanted and ownSwingCheck then
			ownSwingCheck = false
			if not native then
				pcall(C_SwingTimer.EnableRangeCheck, Enum.PlayerSwingType.MainHand, false)
			end
		end
	end

	local docked
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
		SwingCheck(false)
		strip:Hide()
		docked = nil
		StopTicker()
	end

	-- The class's known reaches and their segments, rebuilt when a spell is learned, a talent moves it or the
	-- ranged weapon changes. Segment names and icons are read only then, not on every tick: the tick refreshes
	-- each reach's range answer and re-derives the band from the cached segments.
	---@type TFRangeReach[]
	local cachedReaches = {}
	---@type TFRangeSegment[]
	local cachedSegments = {}
	-- The segments and shape options last laid out, so a tick with none of them changed only re-lights the band.
	---@type TFRangeSegment[]?
	local shownSegments
	local shownIcons, shownLabel
	local SPELL_COLOUR = { SPELL_R, SPELL_G, SPELL_B }
	-- The client can answer a known spell's name late, before its data has loaded: a build that missed one is read
	-- again on the next update, so the reach joins the strip without waiting for the next spell event. An icon may
	-- be missing for good (Model.SpellTexture allows it), so a missing icon waits for the client's data-loaded events.
	local incomplete, iconMissing = false, false
	local OnDataLoaded ---@type fun()
	-- One callback for the weapon wait, so repeated builds while the icon is missing queue it once.
	local function WeaponLoaded()
		OnDataLoaded()
	end
	-- Whether two segment lists show the same keys, names and icons in the same order.
	---@param a TFRangeSegment[]
	---@param b TFRangeSegment[]
	---@return boolean
	local function SameSegments(a, b)
		if #a ~= #b then
			return false
		end
		for index, segment in ipairs(a) do
			local other = b[index]
			if segment.key ~= other.key or segment.name ~= other.name or segment.icon ~= other.icon then
				return false
			end
		end
		return true
	end
	local function Refresh()
		local previous = cachedSegments
		cachedReaches, cachedSegments = {}, {}
		incomplete, iconMissing = false, false
		local gap = false
		for _, reach in ipairs(Model.Reaches(class, Model.Known, Model.EquippedRanged())) do
			local name = Model.SpellName(reach.spell)
			local icon = name and Model.SpellTexture(reach.spell)
			incomplete = incomplete or not name
			iconMissing = iconMissing or (name ~= nil and not icon)
			if name then
				cachedReaches[#cachedReaches + 1] = reach
				gap = gap or reach.min > 0
				cachedSegments[#cachedSegments + 1] = {
					key = reach.key,
					name = name,
					colour = SPELL_COLOUR,
					icon = icon,
				}
			end
		end
		-- Melee first, then Dead zone when a shown reach has a minimum range, then the reaches near to far.
		local mainHand = Model.MainHandTexture()
		-- A weapon whose icon has not loaded yet is awaited through the shared item wait.
		if mainHand == nil and type(GetInventoryItemID) == "function" then
			local weapon = GetInventoryItemID("player", INVSLOT_MAINHAND)
			if weapon then
				iconMissing = true
				ns.AwaitItem(weapon, WeaponLoaded)
			end
		end
		table.insert(cachedSegments, 1, {
			key = MELEE,
			name = NAMES[MELEE],
			colour = COLOURS[MELEE],
			icon = mainHand,
		})
		if gap then
			table.insert(cachedSegments, 2, {
				key = DEAD_ZONE,
				name = NAMES[DEAD_ZONE],
				colour = COLOURS[DEAD_ZONE],
			})
		end
		-- An unchanged list keeps its table, so a rebuild that read nothing new (a name still loading) does not lay
		-- the strip out again.
		if SameSegments(previous, cachedSegments) then
			cachedSegments = previous
		end
	end

	-- The current band from the cached reaches: each reach's range answer is refreshed, then the band is derived.
	---@return string?
	local function Band()
		for _, reach in ipairs(cachedReaches) do
			reach.check = Model.Check(reach.spell)
		end
		return Model.Band(Model.Melee(), cachedReaches, Model.Interact, Model.Follow)
	end

	function Update()
		if incomplete then
			Refresh()
		end
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
		if #cachedSegments <= 1 then
			Hide()
			return
		end
		SwingCheck(true)
		local icons, labelOn = ns.Active(ICONS_KEY), ns.Active(LABEL_KEY)
		local changed = shownSegments ~= cachedSegments or shownIcons ~= icons or shownLabel ~= labelOn
		if changed then
			shownSegments, shownIcons, shownLabel = cachedSegments, icons, labelOn
			ShowSegments(cachedSegments)
		end
		Apply(Band(), cachedSegments)
		strip:Show()
		if changed then
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
	-- A spell's data loading late brings its icon; the event does not exist on every client either. The weapon's icon
	-- arrives through the shared item wait. Only a build still missing an icon reads it again.
	function OnDataLoaded()
		if iconMissing then
			ReachesChanged()
		end
	end
	pcall(ns.On, "SPELL_DATA_LOAD_RESULT", OnDataLoaded)
end)
