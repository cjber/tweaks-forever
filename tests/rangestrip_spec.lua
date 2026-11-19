-- Range strip (UI/RangeStrip.lua): each class's reaches from the client's own spell ranges, melee from the game's
-- own main-hand swing range, the band rule from the nearest reach that answers true, the dead zone only when a shown
-- reach has a minimum range, and a ticker while the strip shows. The file is compiled once, and a Load only gives it
-- a fresh environment.
local CHUNK = assert(loadfile("UI/RangeStrip.lua"))

-- C_Spell's name and range answers for the spells these checks use, in yards, before any talent. A check moves one
-- to prove the strip follows the client rather than a table of fixed distances.
local SPELL_NAMES = {
	[75] = "Auto Shot",
	[116] = "Frostbolt",
	[133] = "Fireball",
	[2136] = "Fire Blast",
}
local SPELL_RANGES = {
	[75] = { 8, 35 },
	[100] = { 8, 25 },
	[116] = { 0, 30 },
	[133] = { 0, 35 },
	[585] = { 0, 30 },
	[2136] = { 0, 20 },
	[2480] = { 8, 30 },
	[5176] = { 0, 30 },
	[5782] = { 0, 20 },
	[8042] = { 0, 20 },
	[20271] = { 0, 10 },
}

-- The client's own icon for the spells these checks use, as SpellMisc's SpellIconFileDataID names it. A spell with
-- no icon here is one the client has no tile for.
local SPELL_ICONS = {
	[75] = 132369,
	[116] = 135846,
	[133] = 135812,
	[2136] = 135807,
}

-- The main-hand weapon's icon, the file the game's own Attack button draws: a different one from any spell icon, so
-- a test can tell the weapon's tile from a spell's.
local SWORD, AXE = 135274, 132394

-- The widget stubs' methods, shared by every Load: a widget records its own points and shown state, while the
-- strip keeps the lists of textures and names made for it.
local Widget = {}
function Widget.Show(self)
	self.shown = true
end
function Widget.Hide(self)
	self.shown = false
end
function Widget.SetShown(self, shown)
	self.shown = shown
end
function Widget.ClearAllPoints(self)
	self.points = {}
end
function Widget.SetPoint(self, point, relative, relativePoint, x, y)
	table.insert(self.points, { point, relative, relativePoint, x, y })
end

local Texture = setmetatable({}, { __index = Widget })
function Texture.SetAtlas(self, atlas)
	self.atlas = atlas
end
function Texture.SetVertexColor(self, r, g, b)
	self.colour = { r, g, b }
end
function Texture.SetColorTexture(self, r, g, b, a)
	self.colour = { r, g, b, a }
end
function Texture.SetSize(self, width, height)
	self.width, self.height = width, height
end

local FontString = setmetatable({}, { __index = Widget })
function FontString.SetFontObject(self, object)
	self.fontObject = object
end
function FontString.SetJustifyH() end
function FontString.SetJustifyV(self, just)
	self.justifyV = just
end
function FontString.SetHeight() end
function FontString.SetWidth(self, width)
	self.width = width
end
function FontString.SetWordWrap(self, wrap)
	self.wordWrap = wrap
end
function FontString.SetText(self, value)
	self.string = value
	self.strip.textOrder = self.strip.textOrder + 1
	self.order = self.strip.textOrder
end
function FontString.SetTextColor(self, r, g, b)
	self.colour = { r, g, b }
end

local Strip = setmetatable({}, { __index = Widget })
function Strip.SetFrameStrata() end
function Strip.SetFrameLevel() end
function Strip.SetHeight(self, height)
	self.height = height
end
function Strip.GetWidth(self)
	return self.width
end
function Strip.SetScale(self, scale)
	self.scale = scale
end
function Strip.SetScript(self, script, fn)
	self.scripts[script] = fn
end
function Strip.CreateTexture(self)
	local texture = setmetatable({ shown = false, points = {} }, { __index = Texture })
	table.insert(self.textures, texture)
	return texture
end
function Strip.CreateFontString(self)
	local text = setmetatable({ shown = false, string = "", wordWrap = true, points = {}, strip = self }, {
		__index = FontString,
	})
	table.insert(self.fontStrings, text)
	return text
end

-- The game's swing timer frames, which the strip only reads and hooks.
local Timer = {}
function Timer.IsShown(self)
	return self.shown
end
function Timer.GetBottom(self)
	return self.bottom
end
function Timer.GetEffectiveScale(self)
	return self.scale
end
function Timer.HookScript(self, script, fn)
	self.scripts[script] = fn
end

local function Load(class, knownSpells)
	local features, initializers, handlers, db = {}, {}, {}, {}
	local settingChanged = {}

	local tickers = {}
	local interactCalls = 0
	local interact, target = true, true
	local uiScale = 1
	knownSpells = knownSpells or {}
	-- The client says its melee attacks reach at every distance (#574), so their answers are always true here and
	-- the strip must take melee from the swing range instead.
	local answers = { [78] = true, [1752] = true, [2973] = true, [2974] = true, [1495] = true, [6603] = true }
	local swing = false
	local ranges = {}
	for spell, range in pairs(SPELL_RANGES) do
		ranges[spell] = { range[1], range[2] }
	end
	local item, itemClass, itemSubclass
	local mainHandTexture = SWORD

	local strip = setmetatable({
		shown = false,
		scripts = {},
		scale = 1,
		width = 240,
		points = {},
		textures = {},
		fontStrings = {},
		textOrder = 0,
	}, { __index = Strip })
	local mainHand = setmetatable({ bottom = 300, shown = true, scale = 1, scripts = {} }, { __index = Timer })
	local ranged = setmetatable({ bottom = 200, shown = true, scale = 1, scripts = {} }, { __index = Timer })

	local function interactCheck()
		interactCalls = interactCalls + 1
		return interact
	end

	local ns = {
		L = setmetatable({}, {
			__index = function(_, key)
				return key
			end,
		}),
		Feature = function(feature)
			features[feature.key] = feature
		end,
		Init = function(fn)
			initializers[#initializers + 1] = fn
		end,
		On = function(event, fn)
			handlers[event] = fn
		end,
		Active = function(key)
			return db[key]
		end,
		OnSettingChanged = function(key, fn)
			settingChanged[key] = fn
		end,
		Readable = function(value)
			return value
		end,
		-- UI/Art.lua is checked by tests/art_spec.lua: here a spell icon's file and square size are all that's read.
		Art = {
			Icon = function(texture, file, size)
				texture.file = file
				texture.width, texture.height = size, size
			end,
		},
		core = {
			SafeCall = function(_, fn, ...)
				return fn(...)
			end,
		},
	}

	local env = setmetatable({
		UnitClassBase = function()
			return class
		end,
		UnitCanAttack = function()
			return target
		end,
		CheckInteractDistance = interactCheck,
		Enum = { PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 } },
		C_SwingTimer = {
			IsTargetWithinSwingRange = function(swingType)
				assert(swingType == 0, "melee reads the main-hand swing")
				return swing
			end,
		},
		C_Spell = {
			IsSpellInRange = function(spell)
				return answers[spell] == true
			end,
			GetSpellName = function(spell)
				return SPELL_NAMES[spell]
			end,
			GetSpellTexture = function(spell)
				return SPELL_ICONS[spell]
			end,
			GetSpellInfo = function(spell)
				local range = ranges[spell]
				if range then
					return { minRange = range[1], maxRange = range[2] }
				end
				return nil
			end,
		},
		IsPlayerSpell = function(spell)
			return knownSpells[spell] == true
		end,
		GetInventoryItemID = function()
			return item
		end,
		-- The main-hand slot's texture, which the game's Attack button draws: nil while the slot is empty.
		GetInventoryItemTexture = function(unit, slot)
			assert(unit == "player" and slot == 16, "Melee reads the player's main-hand slot")
			return mainHandTexture
		end,
		INVSLOT_MAINHAND = 16,
		INVSLOT_RANGED = 18,
		C_Item = {
			GetItemInfoInstant = function(id)
				if not id or not item then
					return nil
				end
				return id, "Weapon", "Ranged", "INVTYPE_RANGED", 0, itemClass, itemSubclass
			end,
		},
		C_Timer = {
			NewTicker = function(interval)
				local ticker = { interval = interval, cancelled = false }
				function ticker.Cancel()
					ticker.cancelled = true
				end
				table.insert(tickers, ticker)
				return ticker
			end,
		},
		SwingTimerMainHandFrame = mainHand,
		SwingTimerRangedFrame = ranged,
		GameFontNormal = "GameFontNormal",
		GameFontHighlightSmall = "GameFontHighlightSmall",
		UIParent = {
			GetEffectiveScale = function()
				return uiScale
			end,
		},
		CreateFrame = function()
			return strip
		end,
	}, { __index = _G })
	setfenv(CHUNK, env)("TweaksForever", ns)

	return {
		model = ns.RangeStrip,
		features = features,
		initializers = initializers,
		handlers = handlers,
		db = db,
		changed = function(key)
			settingChanged[key or "rangeStrip"]()
		end,
		strip = strip,
		textures = strip.textures,
		fontStrings = strip.fontStrings,
		mainHand = mainHand,
		ranged = ranged,
		tickers = tickers,
		interactCalls = function()
			return interactCalls
		end,
		setInteract = function(value)
			interact = value
		end,
		setTarget = function(value)
			target = value
		end,
		setKnown = function(spell, value)
			knownSpells[spell] = value
		end,
		setRange = function(spell, minRange, maxRange)
			if minRange == nil or maxRange == nil then
				ranges[spell] = nil
			else
				ranges[spell] = { minRange, maxRange }
			end
		end,
		setSwing = function(value)
			swing = value
		end,
		setAnswer = function(spell, value)
			answers[spell] = value
		end,
		setRanged = function(id, subclass, classID)
			item, itemClass, itemSubclass = id, classID or 2, subclass
		end,
		setMainHand = function(texture)
			mainHandTexture = texture
		end,
		setUIScale = function(value)
			uiScale = value
		end,
	}
end

local function known(set)
	return function(spell)
		return set[spell] == true
	end
end

local function ids(reaches)
	local out = {}
	for _, reach in ipairs(reaches) do
		out[#out + 1] = table.concat(reach.spells, "+")
	end
	return table.concat(out, ",")
end

local function segments(harness)
	local out = {}
	for index = 2, #harness.fontStrings do
		local text = harness.fontStrings[index]
		if text.shown then
			out[#out + 1] = text
		end
	end
	table.sort(out, function(a, b)
		return (a.order or 0) < (b.order or 0)
	end)
	for index, text in ipairs(out) do
		out[index] = text.string
	end
	return out
end

local function joined(list)
	return table.concat(list, " | ")
end

-- The strip's shape: its width, the gap between segments, and an icon tile's own size and clear before the bar.
local WIDTH, SEGMENT_GAP, TILE, ICON_GAP = 240, 3, 17, 1
-- The segments without icons are 15 high, and the band label row under them is 20.
local PLAIN_SEGMENT, LABEL = 15, 20
-- The hunter's three segments, equal across the strip.
local SEGMENT_WIDTH = (WIDTH - 2 * SEGMENT_GAP) / 3

-- The nth shown segment's art, in the order the strip made it: background, fill, border, icon, its dimming and
-- the icon's frame.
local function art(harness, index)
	local first = (index - 1) * 6 + 1
	return {
		background = harness.textures[first],
		fill = harness.textures[first + 1],
		border = harness.textures[first + 2],
		icon = harness.textures[first + 3],
		dim = harness.textures[first + 4],
		iconFrame = harness.textures[first + 5],
	}
end

-- The hunter's harness answers the model's questions directly, before its frame is initialized: Auto Shot is a
-- reach and Raptor Strike a known melee spell.
local hunter = Load("HUNTER", { [75] = true, [2973] = true })
local M = hunter.model

-- The feature is on by default and lives on the Interface page, for every class.
local feature = hunter.features.rangeStrip
assert(feature.default == true and feature.category == "Interface", "on by default on the Interface page")
assert(feature.name == "Range strip", "named for every class")

-- Two options under it, both on by default: each segment's own icon, and the band's name under the strip.
local icons, label = hunter.features.rangeStripIcons, hunter.features.rangeStripLabel
assert(icons and icons.parent == "rangeStrip" and icons.default == true, "icons on by default, under the strip")
assert(
	label and label.parent == "rangeStrip" and label.default == true,
	"the band label on by default, under the strip"
)

-- Every class that fights at range has a reach of its own, from its reach spells or a shot in the ranged slot.
local CLASS_REACHES = {
	{ "WARRIOR", 100 },
	{ "ROGUE", 2480, true },
	{ "HUNTER", 75 },
	{ "DRUID", 5176 },
	{ "PALADIN", 20271 },
	{ "MAGE", 2136 },
	{ "PRIEST", 585 },
	{ "WARLOCK", 5782 },
	{ "SHAMAN", 8042 },
}
for _, shape in ipairs(CLASS_REACHES) do
	local class, spell, shot = shape[1], shape[2], shape[3]
	local reaches = M.Reaches(class, known({ [spell] = true }), shot and spell or nil)
	assert(ids(reaches) == tostring(spell), class .. " reaches with its spell")
end

-- Only spells the player has learned are reaches.
assert(ids(M.Reaches("MAGE", known({ [2136] = true }), nil)) == "2136", "only the known spell is a reach")

-- The ranged slot's item subclass names its shot; an armour item or an empty slot has none.
local SHOTS = { [2] = 2480, [3] = 7918, [18] = 7919, [16] = 2764 }
for subclass, shot in pairs(SHOTS) do
	assert(M.RangedWeapon(subclass) == shot, "subclass " .. subclass .. " names its shot")
end
assert(M.RangedWeapon(1) == nil and M.RangedWeapon(nil) == nil, "no shot for anything else")
hunter.setRanged(1000, 18, 2)
assert(M.EquippedRanged() == 7919, "a crossbow in the ranged slot")
hunter.setRanged(1000, 4, 4)
assert(M.EquippedRanged() == nil, "an armour item is no shot")
hunter.setRanged(nil)
assert(M.EquippedRanged() == nil, "an empty slot")

-- SpellRange reads the client's table and answers nothing for a spell it cannot describe.
local autoMin, autoMax = M.SpellRange(75)
assert(autoMin == 8 and autoMax == 35, "the client's Auto Shot range")
assert(M.SpellRange(999999) == nil, "no range for an unknown spell")

-- SpellTexture reads the client's icon for the segment it heads, and answers nothing for a spell it has no icon
-- for, so that segment keeps its whole width.
assert(M.SpellTexture(75) == SPELL_ICONS[75], "Auto Shot's own icon")
assert(M.SpellTexture(999999) == nil, "no icon for a spell the client does not know")

-- MainHandTexture reads the weapon in the main-hand slot, which heads Melee as the game's Attack button draws it.
-- An empty slot has no tile.
assert(M.MainHandTexture() == SWORD, "the main-hand weapon's icon heads Melee")
hunter.setMainHand(nil)
assert(M.MainHandTexture() == nil, "an empty main hand has no icon")
hunter.setMainHand(SWORD)

-- Melee reach is the game's own main-hand swing range, as its Main Hand timer reads it: true, false, or nil when the
-- client made no check. Raptor Strike and Attack answer true at every distance (#574) and decide nothing.
hunter.setSwing(true)
assert(M.Melee() == true, "in swing range is melee")
hunter.setSwing(false)
assert(M.Melee() == false, "out of swing range is not melee, whatever Raptor Strike says")
hunter.setSwing(nil)
assert(M.Melee() == nil, "no swing check decides nothing")
hunter.setSwing(true)

-- The client's own ranges decide order and merging: equal maxima are one segment named by the first spell in table
-- order, and a talent that extends one splits them.
local function maxima(map)
	return function(spell)
		local max = map[spell]
		if max then
			return 0, max
		end
	end
end

local priestKnown = known({ [585] = true, [8092] = true })
local mageKnown = known({ [2136] = true, [116] = true })
local merged = M.Reaches("PRIEST", priestKnown, nil, maxima({ [585] = 30, [8092] = 30 }))
assert(ids(merged) == "585+8092" and merged[1].spell == 585, "equal ranges are one segment, named by the first")
local split = M.Reaches("PRIEST", priestKnown, nil, maxima({ [585] = 30, [8092] = 36 }))
assert(ids(split) == "585,8092", "a talent that extends Mind Blast splits them")
assert(ids(M.Reaches("MAGE", mageKnown, nil, maxima({ [2136] = 20 }))) == "2136", "a spell with no range is left out")
assert(
	ids(M.Reaches("MAGE", mageKnown, nil, maxima({ [2136] = 20, [116] = 5 }))) == "2136",
	"a spell no further than melee is left out"
)

-- The band rule, by hand: melee wins, then the nearest reach that answers true, then the dead zone the 8-yard
-- check opens for a reach with a minimum, then Too far. A nil that could change the answer hides the band, and the
-- 8-yard check runs only when the other answers leave more than one band.
local function reach(key, min, max, check)
	return { key = key, min = min, max = max, check = check }
end

local function noInteract()
	error("the 8-yard check must not run")
end

local function interact(answer)
	return function()
		return answer
	end
end

assert(M.Band(true, { reach("autoshot", 8, 35, false) }, noInteract) == "melee", "melee wins")
assert(
	M.Band(
		false,
		{ reach("fireblast", 0, 20, false), reach("frostbolt", 0, 30, true), reach("fireball", 0, 35, true) },
		noInteract
	) == "frostbolt",
	"the nearest reach that answers true"
)
assert(
	M.Band(false, { reach("fireblast", 0, 20, nil), reach("frostbolt", 0, 30, true) }, interact(false)) == nil,
	"a nearer reach with no answer hides the band"
)
assert(
	M.Band(
		false,
		{ reach("fireblast", 0, 20, true), reach("frostbolt", 0, 30, nil), reach("fireball", 0, 35, true) },
		noInteract
	) == "fireblast",
	"a farther nil does not decide"
)

-- The dead zone needs a shown reach with a minimum range and the game's own 8-yard answer.
local warriorReaches = { reach("charge", 8, 25, false), reach("ranged", 8, 30, false) }
assert(M.Band(false, warriorReaches, interact(true)) == "dead", "a minimum range and a target inside 8 yards")
assert(M.Band(false, warriorReaches, interact(false)) == "far", "every reach too short, beyond 8 yards")
assert(M.Band(false, { reach("judgement", 0, 10, false) }, noInteract) == "far", "no minimum range, so no dead zone")
assert(M.Band(false, warriorReaches, interact(nil)) == nil, "the 8-yard check answered nothing")
assert(M.Band(nil, { reach("charge", 8, 25, false) }, interact(true)) == nil, "melee unknown leaves the gap unclaimed")
-- Out of combat the swing range has no answer; the ranged bands still light, and a reach the target is beyond rules
-- melee out.
assert(M.Band(nil, { reach("autoshot", 8, 35, true) }, noInteract) == "autoshot", "Auto Shot lights with melee unknown")
assert(M.Band(nil, { reach("autoshot", 8, 35, false) }, interact(false)) == "far", "beyond Auto Shot is Too far")
assert(M.Band(nil, { reach("autoshot", 8, 35, false) }, interact(nil)) == nil, "no 8-yard answer, melee undecided")
assert(M.Band(nil, { reach("frostbolt", 0, 30, false) }, noInteract) == "far", "beyond a reach with no minimum")
assert(
	M.Band(nil, { reach("frostbolt", 0, 30, nil) }, interact(true)) == nil,
	"no reach answered false, so melee stays undecided"
)
-- The interact check reaches past 8 yards, so it alone cannot say an unanswered 8-yard minimum is out of reach.
assert(
	M.Band(false, { reach("feralcharge", 8, 25, false), reach("wrath", 0, 30, nil) }, interact(true)) == "wrath",
	"inside the interact check and out of melee, a spell reaching from 0 to 30 yards reaches"
)
assert(
	M.Band(false, { reach("charge", 8, 25, nil), reach("ranged", 8, 30, false) }, interact(true)) == "dead",
	"a false 8 to 30 reach inside the interact check puts the target inside 8 yards, inside Charge's minimum too"
)

assert(
	M.Band(false, { reach("autoshot", 8, 35, nil) }, interact(true)) == nil,
	"a single unanswered positive-minimum reach leaves the band unknown"
)
assert(
	M.Band(false, { reach("charge", 8, 25, nil), reach("autoshot", 8, 35, nil) }, interact(true)) == nil,
	"multiple unanswered positive-minimum reaches leave the band unknown"
)
assert(
	M.Band(false, { reach("charge", 8, 25, nil), reach("autoshot", 10, 35, nil) }, interact(true)) == nil,
	"different positive minima do not resolve unanswered reaches"
)
assert(
	M.Band(false, { reach("charge", 8, 25, false), reach("autoshot", 8, 35, nil) }, interact(true)) == "dead",
	"a false reach sharing the unanswered one's minimum puts the target inside both"
)

-- Answers no distance fits (Fire Blast in range, Frostbolt with the longer reach not) break the yard model, so the
-- band is hidden rather than guessed.
assert(
	M.Band(false, { reach("fireblast", 0, 20, true), reach("frostbolt", 0, 30, false) }, interact(nil)) == nil,
	"contradicting answers name no band"
)

-- The band rule over every reach set, every distance and every pattern of unanswered checks. The target stands at a
-- distance; melee reaches 5 yards, the interact check answers inside the client's radius (8 or 9.9 here, the two ends
-- the strip allows for), and each reach answers inside its own range. Any answer may be missing (melee is out of
-- combat, a spell or the interact check may say nothing). The rule must never name a wrong band, and must name the
-- band whenever the answers leave only one band possible: a missing answer hides only the bands it could change.
local function TrueBand(distance, reaches)
	if distance <= 5 then
		return "melee"
	end
	local nearest, inside
	for _, r in ipairs(reaches) do
		if distance >= r.min and distance <= r.max and (not nearest or r.max < nearest.max) then
			nearest = r
		end
		inside = inside or distance < r.min
	end
	if nearest then
		return nearest.key
	end
	return inside and "dead" or "far"
end

local function Within(distance, r)
	return distance >= r.min and distance <= r.max
end

-- Shapes the client gives a reach: no minimum, an 8-yard minimum, short and long maxima, and two sharing a minimum.
local SHAPES = { { 0, 10 }, { 0, 20 }, { 0, 30 }, { 8, 25 }, { 8, 35 }, { 8, 41 }, { 10, 35 } }
local reachSets = { {} }
for a = 1, #SHAPES do
	reachSets[#reachSets + 1] = { a }
	for b = a + 1, #SHAPES do
		reachSets[#reachSets + 1] = { a, b }
		for c = b + 1, #SHAPES do
			reachSets[#reachSets + 1] = { a, b, c }
		end
	end
end

for _, set in ipairs(reachSets) do
	local reaches = {}
	for i, shape in ipairs(set) do
		reaches[i] = reach("r" .. shape, SHAPES[shape][1], SHAPES[shape][2], nil)
	end
	local n = #reaches
	-- This samples only each edge, the point between two edges and one past the last. That stands for every distance
	-- because nothing here changes between edges: each answer and TrueBand compare the distance only against 5, the
	-- interact radius and the reach edges, all of them in `edges`. A 0.01-yard walk from 0 to 60 yards gives the same
	-- 769 distinct answer sets with the same bands (PR #613).
	local edges = { 0, 5, 8, 9.9, 10 }
	for _, r in ipairs(reaches) do
		edges[#edges + 1] = r.min
		edges[#edges + 1] = r.max
	end
	table.sort(edges)
	local samples = {}
	for i, edge in ipairs(edges) do
		samples[#samples + 1] = edge
		samples[#samples + 1] = edges[i + 1] and (edge + edges[i + 1]) / 2 or edge + 1
	end
	-- Each distinct set of answers once, with every band a target giving those answers can stand in.
	local cases, order = {}, {}
	for _, radius in ipairs({ 8, 9.9 }) do
		for _, distance in ipairs(samples) do
			-- Bit 0 drops melee, bit 1 the interact check, bit i + 1 reach i.
			for mask = 0, 2 ^ (n + 2) - 1 do
				local function Kept(bit, value)
					if math.floor(mask / 2 ^ bit) % 2 == 1 then
						return nil
					end
					return value
				end
				local melee, near, checks = Kept(0, distance <= 5), Kept(1, distance < radius), {}
				local key = tostring(melee) .. tostring(near)
				for i, r in ipairs(reaches) do
					checks[i] = Kept(i + 1, Within(distance, r))
					key = key .. tostring(checks[i])
				end
				local case = cases[key]
				if not case then
					case = { melee = melee, near = near, checks = checks, bands = {}, at = distance }
					cases[key] = case
					order[#order + 1] = key
				end
				case.bands[TrueBand(distance, reaches)] = true
			end
		end
	end
	for _, key in ipairs(order) do
		local case = cases[key]
		for i = 1, n do
			reaches[i].check = case.checks[i]
		end
		local got = M.Band(case.melee, reaches, function()
			return case.near
		end)
		local failure =
			string.format("reaches %s near %.1f yd (%s): got %s", table.concat(set, ","), case.at, key, tostring(got))
		-- Never wrong: a named band is the band at every distance giving these answers.
		if got ~= nil then
			for band in pairs(case.bands) do
				assert(band == got, failure .. ", but " .. band .. " gives the same answers")
			end
		end
		-- Never hidden needlessly: the strip knows the interact radius only to lie from 8 to 10 yards, so the bands
		-- possible are those at every distance some radius there would give these answers.
		local only, count = nil, 0
		local possible = {}
		for _, distance in ipairs(samples) do
			local agrees = (case.melee == nil or case.melee == (distance <= 5))
				and (case.near == nil or (case.near and distance < 10) or (not case.near and distance >= 8))
			for i, r in ipairs(reaches) do
				agrees = agrees and (case.checks[i] == nil or case.checks[i] == Within(distance, r))
			end
			if agrees then
				local band = TrueBand(distance, reaches)
				if not possible[band] then
					possible[band], count, only = true, count + 1, band
				end
			end
		end
		if count == 1 then
			assert(got == only, failure .. ", the answers leave only " .. only)
		end
	end
end

-- A hunter's strip: Melee, the Dead zone its Auto Shot minimum leaves, then Auto Shot.
hunter.initializers[1]()
for _, event in ipairs({
	"PLAYER_TARGET_CHANGED",
	"PLAYER_EQUIPMENT_CHANGED",
	"SPELLS_CHANGED",
	"CHARACTER_POINTS_CHANGED",
	"PLAYER_LEVEL_UP",
	"PLAYER_TALENT_UPDATE",
}) do
	assert(hunter.handlers[event], event .. " is handled")
end
assert(not hunter.strip.shown, "off at login")
assert(hunter.mainHand.scripts.OnShow and hunter.mainHand.scripts.OnHide and hunter.mainHand.scripts.OnSizeChanged)
assert(hunter.ranged.scripts.OnShow and hunter.ranged.scripts.OnHide and hunter.ranged.scripts.OnSizeChanged)

hunter.db.rangeStrip = true
hunter.db.rangeStripIcons, hunter.db.rangeStripLabel = true, true
hunter.setSwing(true)
hunter.changed()
assert(hunter.strip.shown, "on, the strip shows")
-- The game stacks its timers, so the strip docks under the lowest one: the Ranged timer, whose bottom is lower.
assert(hunter.strip.points[1][2] == hunter.ranged, "docked under the timer lowest on screen")
assert(hunter.strip.points[1][3] == "BOTTOMLEFT" and hunter.strip.points[1][5] == -6, "6 below the timer")
assert(hunter.strip.points[2][3] == "BOTTOMRIGHT", "the strip takes the timer's width")
assert(joined(segments(hunter)) == "Melee | Dead zone | Auto Shot", "hunter's three segments")
assert(hunter.fontStrings[1].string == "Melee", "the band label")
-- The band label is its own row under the segments, so it stays clear of the timers above.
assert(
	hunter.fontStrings[1].points[1][1] == "BOTTOMLEFT" and hunter.fontStrings[1].points[1][2] == hunter.strip,
	"the band label sits under the segments"
)
-- Segment art is made in segment order: Melee, Dead zone, Auto Shot, six textures each.
assert(art(hunter, 1).fill.shown and not art(hunter, 2).fill.shown and not art(hunter, 3).fill.shown, "only Melee lit")
assert(
	#hunter.tickers == 1 and hunter.tickers[1].interval == 0.2,
	"a ticker runs while the strip shows, Melee included"
)
assert(hunter.interactCalls() == 0, "no 8-yard check while a reach answers")

-- Icons on: a spell segment leads with its spell's icon, a square tile of the segment's height, and its bar
-- starts 1 after the tile. Melee heads with the equipped weapon's icon, Auto Shot with its own, and Dead zone has
-- no attack, so it keeps its whole width.
assert(hunter.strip.height == LABEL + TILE, "the label row under the 17-high segments")
local meleeArt, deadArt, shotArt = art(hunter, 1), art(hunter, 2), art(hunter, 3)
assert(meleeArt.icon.shown and meleeArt.icon.file == SWORD, "Melee leads with the main-hand weapon's icon")
assert(
	meleeArt.icon.width == TILE and meleeArt.icon.height == TILE and meleeArt.icon.points[1][4] == 0,
	"a square tile at the segment's left"
)
assert(meleeArt.background.points[1][4] == TILE + ICON_GAP, "Melee's bar starts after its tile")
assert(shotArt.icon.shown and shotArt.icon.file == SPELL_ICONS[75], "Auto Shot leads with its own icon")
assert(
	not deadArt.icon.shown and deadArt.background.points[1][4] == SEGMENT_WIDTH + SEGMENT_GAP,
	"Dead zone keeps its width"
)
assert(not meleeArt.dim.shown and shotArt.dim.shown, "only the unlit segment's icon is dimmed")
assert(
	shotArt.background.points[2][4] - shotArt.background.points[1][4] == SEGMENT_WIDTH - TILE - ICON_GAP,
	"the bar takes the rest of the segment"
)
-- The segments sit at the strip's top, one tile high; the name is given the bar's height and both anchors, so the
-- glyphs centre on the bar.
assert(
	meleeArt.background.points[1][5] == 0 and meleeArt.background.points[2][5] == LABEL,
	"the segments take the strip's top, above the label row"
)
local meleeName = hunter.fontStrings[2]
assert(
	meleeName.points[1][1] == "TOPLEFT"
		and meleeName.points[1][2] == meleeArt.background
		and meleeName.points[1][4] == 3
		and meleeName.points[2][1] == "BOTTOMRIGHT"
		and meleeName.points[2][2] == meleeArt.background
		and meleeName.points[2][4] == -3,
	"the name spans its bar's height, 3 clear on either side"
)
assert(meleeName.justifyV == "MIDDLE", "the name is centred vertically on the bar")

-- The other shown timer is lowest now, and the strip follows it.
hunter.mainHand.bottom, hunter.ranged.bottom = 100, 400
hunter.changed()
assert(hunter.strip.points[1][2] == hunter.mainHand, "the lower timer takes the strip")

-- Auto Shot reaches: its band is named by the spell while the ticker keeps running.
hunter.setSwing(false)
hunter.setAnswer(75, true)
hunter.changed()
assert(hunter.fontStrings[1].string == "Auto Shot", "the reach that answers names the band")
assert(art(hunter, 3).fill.shown and not art(hunter, 1).fill.shown, "only the spell band is lit")
assert(#hunter.tickers == 1 and not hunter.tickers[1].cancelled, "the ticker keeps running in a spell band")
hunter.setSwing(true)
hunter.changed()
assert(
	hunter.fontStrings[1].string == "Melee" and not hunter.tickers[1].cancelled,
	"the ticker runs in Melee too, which no event reports"
)

-- Out of reach but inside 8 yards: the Dead zone. Beyond it: Too far. With no 8-yard answer: no label at all.
hunter.setSwing(false)
hunter.setAnswer(75, false)
hunter.setInteract(true)
hunter.changed()
assert(hunter.fontStrings[1].string == "Dead zone" and art(hunter, 2).fill.shown, "a target inside 8 yards")
hunter.setInteract(false)
hunter.changed()
assert(hunter.fontStrings[1].string == "Too far", "a target beyond 8 yards")
assert(not art(hunter, 1).fill.shown and not art(hunter, 2).fill.shown and not art(hunter, 3).fill.shown)
hunter.setInteract(nil)
hunter.changed()
assert(not hunter.fontStrings[1].shown, "no label when the 8-yard check answered nothing")

-- No attackable target hides the strip and stops the ticker.
hunter.setTarget(false)
hunter.changed()
assert(not hunter.strip.shown and hunter.tickers[1].cancelled, "no strip and no ticker without a target")

-- No shown timer hides it too.
hunter.setTarget(true)
hunter.mainHand.shown, hunter.ranged.shown = false, false
hunter.changed()
assert(not hunter.strip.shown, "no strip without a shown timer")

-- With a timer again the strip takes its timer's scale and starts a fresh ticker.
hunter.ranged.shown = true
hunter.ranged.scale = 0.7
hunter.setUIScale(0.5)
hunter.setSwing(true)
hunter.changed()
assert(hunter.strip.shown and math.abs(hunter.strip.scale - 1.4) < 1e-9, "the strip takes its timer's scale")
assert(#hunter.tickers == 2 and not hunter.tickers[2].cancelled, "shown again, a new ticker starts")

-- The band label off: no label and no 20-unit row, so the segments fill the strip and it still docks 6 below the
-- timer, while the tiles keep their height.
hunter.db.rangeStripLabel = false
hunter.changed("rangeStripLabel")
assert(not hunter.fontStrings[1].shown, "no band label")
assert(hunter.strip.height == TILE, "the label row is gone")
assert(art(hunter, 1).background.points[1][5] == 0, "the segments take the strip's top")
assert(hunter.strip.points[1][5] == -6, "still 6 below the timer")
hunter.db.rangeStripLabel = true
hunter.changed("rangeStripLabel")
assert(hunter.fontStrings[1].shown and hunter.strip.height == LABEL + TILE, "the label row comes back")

-- Icons off: 15-high segments with no tile, so each bar takes its whole segment, and changing the option lays the
-- strip out at once.
hunter.db.rangeStripIcons = false
hunter.changed("rangeStripIcons")
assert(not art(hunter, 1).icon.shown and not art(hunter, 3).icon.shown, "no tiles with icons off")
assert(hunter.strip.height == LABEL + PLAIN_SEGMENT, "15-high segments without icons")
assert(
	art(hunter, 1).background.points[1][4] == 0
		and art(hunter, 3).background.points[1][4] == 2 * (SEGMENT_WIDTH + SEGMENT_GAP),
	"each bar takes its whole segment"
)
hunter.db.rangeStripIcons = true
hunter.changed("rangeStripIcons")
assert(art(hunter, 1).icon.shown and art(hunter, 1).background.points[1][4] == TILE + ICON_GAP, "the tiles come back")

-- A new main-hand weapon: PLAYER_EQUIPMENT_CHANGED re-reads the slot and lays the strip out again, so Melee's tile
-- carries the new weapon at once. An empty slot leaves Melee without a tile, taking its whole width as any segment
-- with no icon does.
hunter.setMainHand(AXE)
hunter.handlers.PLAYER_EQUIPMENT_CHANGED()
assert(art(hunter, 1).icon.shown and art(hunter, 1).icon.file == AXE, "the swapped weapon's icon heads Melee")
assert(art(hunter, 1).background.points[1][4] == TILE + ICON_GAP, "Melee's bar still starts after its tile")
hunter.setMainHand(nil)
hunter.handlers.PLAYER_EQUIPMENT_CHANGED()
assert(not art(hunter, 1).icon.shown, "unarmed, Melee has no tile")
assert(art(hunter, 1).background.points[1][4] == 0, "unarmed, Melee's bar takes its whole segment")
assert(art(hunter, 3).icon.shown, "Auto Shot keeps its own tile")
hunter.setMainHand(SWORD)
hunter.handlers.PLAYER_EQUIPMENT_CHANGED()
assert(art(hunter, 1).icon.file == SWORD, "the weapon is back")

hunter.setKnown(75, false)
hunter.handlers.SPELLS_CHANGED()
assert(not hunter.strip.shown, "no strip with nothing beyond Melee")
assert(hunter.tickers[2].cancelled, "hiding the strip stops the ticker")

-- The mage's reaches, near to far, and no gap: the game's own bands name the nearest reach.
local mage = Load("MAGE", { [2136] = true, [116] = true, [133] = true })
mage.initializers[1]()
mage.db.rangeStrip = true
mage.db.rangeStripIcons, mage.db.rangeStripLabel = true, true
-- Within 20 yards every reach answers true, as the client does.
mage.setAnswer(2136, true)
mage.setAnswer(116, true)
mage.setAnswer(133, true)
mage.changed()
assert(joined(segments(mage)) == "Melee | Fire Blast | Frostbolt | Fireball", "the mage's reaches near to far")
assert(mage.fontStrings[1].string == "Fire Blast", "the nearest reach names the band")

-- Improved Fire Blast (+15 yards) moves Fire Blast past Frostbolt, level with Fireball: the two are one segment,
-- and CHARACTER_POINTS_CHANGED rebuilds the strip from the client's ranges and lays the narrower row out again.
mage.setRange(2136, 0, 35)
-- Between 30 and 35 yards: Frostbolt falls short, the talented Fire Blast and Fireball reach.
mage.setAnswer(116, false)
mage.handlers.CHARACTER_POINTS_CHANGED()
assert(joined(segments(mage)) == "Melee | Frostbolt | Fire Blast", "a talent reorders and merges the mage strip")
assert(mage.fontStrings[1].string == "Fire Blast", "the talented reach still names the band")
assert(
	mage.fontStrings[2].points[1][4] == 3 and mage.fontStrings[2].points[2][4] == -3,
	"the narrower row is laid out again, each name 3 clear inside its bar"
)

-- A spell the client has not loaded yet answers no name: the strip leaves that reach out, then reads it again on the
-- next update, so it comes back without waiting for another spell or talent event.
local fireBlast = SPELL_NAMES[2136]
SPELL_NAMES[2136] = nil
mage.handlers.SPELLS_CHANGED()
assert(not joined(segments(mage)):find("Fire Blast", 1, true), "an unloaded spell has no segment yet")
SPELL_NAMES[2136] = fireBlast
mage.handlers.PLAYER_TARGET_CHANGED()
assert(joined(segments(mage)):find("Fire Blast", 1, true), "the next update reads the loaded spell again")

print("rangestrip: ok")
