-- Range strip (UI/RangeStrip.lua): each class's reaches from the client's own spell ranges, the band rule from
-- the nearest reach that answers true, the dead zone only when a shown reach has a minimum range, and a ticker
-- while Melee is not the answer. The file is compiled once, and a Load only gives it a fresh environment.
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

-- The widget stubs' methods, shared by every Load: a widget records its own points and shown state, while the
-- strip keeps the lists of textures and names made for it.
local Widget = {}
function Widget.Show(self)
	self.shown = true
end
function Widget.Hide(self)
	self.shown = false
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

local FontString = setmetatable({}, { __index = Widget })
function FontString.SetFontObject(self, object)
	self.fontObject = object
end
function FontString.SetJustifyH() end
function FontString.SetJustifyV() end
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
function Strip.SetHeight() end
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
function Timer.GetTop(self)
	return self.top
end
function Timer.GetEffectiveScale(self)
	return self.scale
end
function Timer.HookScript(self, script, fn)
	self.scripts[script] = fn
end

local function Load(class, knownSpells)
	local features, initializers, handlers, db = {}, {}, {}, {}
	local changed

	local tickers = {}
	local enableRangeChecks, interactCalls = 0, 0
	local melee, interact, target = true, true, true
	local uiScale = 1
	knownSpells = knownSpells or {}
	local answers = {}
	local ranges = {}
	for spell, range in pairs(SPELL_RANGES) do
		ranges[spell] = { range[1], range[2] }
	end
	local item, itemClass, itemSubclass

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
	local mainHand = setmetatable({ top = 300, shown = true, scale = 1, scripts = {} }, { __index = Timer })
	local ranged = setmetatable({ top = 200, shown = true, scale = 1, scripts = {} }, { __index = Timer })

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
		OnSettingChanged = function(_, fn)
			changed = fn
		end,
		Readable = function(value)
			return value
		end,
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
		Enum = { PlayerSwingType = { MainHand = 0, Ranged = 2 } },
		C_SwingTimer = {
			IsTargetWithinSwingRange = function(swingType)
				assert(swingType == 0, "melee reads the main-hand swing")
				return melee
			end,
			EnableRangeCheck = function()
				enableRangeChecks = enableRangeChecks + 1
			end,
		},
		CheckInteractDistance = interactCheck,
		C_Spell = {
			IsSpellInRange = function(spell)
				return answers[spell] == true
			end,
			GetSpellName = function(spell)
				return SPELL_NAMES[spell]
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
		changed = function()
			changed()
		end,
		strip = strip,
		textures = strip.textures,
		fontStrings = strip.fontStrings,
		mainHand = mainHand,
		ranged = ranged,
		tickers = tickers,
		enableRangeChecks = function()
			return enableRangeChecks
		end,
		interactCalls = function()
			return interactCalls
		end,
		setMelee = function(value)
			melee = value
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
		setAnswer = function(spell, value)
			answers[spell] = value
		end,
		setRanged = function(id, subclass, classID)
			item, itemClass, itemSubclass = id, classID or 2, subclass
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

-- The hunter's harness answers the model's questions directly, before its frame is initialized.
local hunter = Load("HUNTER", { [75] = true })
local M = hunter.model

-- The feature is on by default and lives on the Interface page, for every class.
local feature = hunter.features.rangeStrip
assert(feature.default == true and feature.category == "Interface", "on by default on the Interface page")
assert(feature.name == "Range strip", "named for every class")

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
-- check opens for a reach with a minimum, then Too far. A nil that could change the answer hides the band.
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
	M.Band(false, { reach("fireblast", 0, 20, nil), reach("frostbolt", 0, 30, true) }, noInteract) == nil,
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
assert(M.Band(nil, { reach("charge", 8, 25, false) }, noInteract) == nil, "melee unknown leaves the gap unclaimed")
-- A spell with no minimum could still reach inside 8 yards, so its nil answer decides against the gap.
assert(
	M.Band(false, { reach("feralcharge", 8, 25, false), reach("wrath", 0, 30, nil) }, interact(true)) == nil,
	"a spell with no minimum and no answer could reach inside 8 yards"
)
assert(
	M.Band(false, { reach("charge", 8, 25, nil), reach("ranged", 8, 30, false) }, interact(true)) == "dead",
	"an 8-yard minimum cannot reach inside the gap"
)

-- A hunter's strip: Melee, the Dead zone its Auto Shot minimum leaves, then Auto Shot.
hunter.initializers[1]()
for _, event in ipairs({
	"PLAYER_SWING_RANGE_UPDATE",
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
hunter.changed()
assert(hunter.strip.shown, "on, the strip shows")
assert(hunter.strip.points[1][2] == hunter.mainHand, "docked on the timer higher on screen")
assert(joined(segments(hunter)) == "Melee | Dead zone | Auto Shot", "hunter's three segments")
assert(hunter.fontStrings[1].string == "Melee", "the band label")
-- Segment art is made in segment order: Melee, Dead zone, Auto Shot, three textures each.
assert(hunter.textures[2].shown and not hunter.textures[5].shown and not hunter.textures[8].shown, "only Melee lit")
assert(#hunter.tickers == 0, "no ticker while Melee is lit")
assert(hunter.interactCalls() == 0, "no 8-yard check while a reach answers")

-- The other shown timer is higher now, and the strip follows it.
hunter.mainHand.top, hunter.ranged.top = 100, 400
hunter.changed()
assert(hunter.strip.points[1][2] == hunter.ranged, "the higher timer takes the strip")

-- Auto Shot reaches: its band is named and the ticker follows it until Melee reaches again.
hunter.setMelee(false)
hunter.setAnswer(75, true)
hunter.changed()
assert(hunter.fontStrings[1].string == "Auto Shot", "the reach that answers names the band")
assert(hunter.textures[8].shown and not hunter.textures[2].shown, "only the spell band is lit")
assert(#hunter.tickers == 1 and hunter.tickers[1].interval == 0.2, "a ticker while a spell band is lit")
hunter.setMelee(true)
hunter.changed()
assert(hunter.fontStrings[1].string == "Melee" and hunter.tickers[1].cancelled, "the ticker stops once Melee reaches")

-- Out of reach but inside 8 yards: the Dead zone. Beyond it: Too far. With no 8-yard answer: no label at all.
hunter.setMelee(false)
hunter.setAnswer(75, false)
hunter.setInteract(true)
hunter.changed()
assert(hunter.fontStrings[1].string == "Dead zone" and hunter.textures[5].shown, "a target inside 8 yards")
hunter.setInteract(false)
hunter.changed()
assert(hunter.fontStrings[1].string == "Too far", "a target beyond 8 yards")
assert(not hunter.textures[2].shown and not hunter.textures[5].shown and not hunter.textures[8].shown)
hunter.setInteract(nil)
hunter.changed()
assert(not hunter.fontStrings[1].shown, "no label when the 8-yard check answered nothing")

-- No attackable target hides the strip and stops the ticker.
hunter.setTarget(false)
hunter.changed()
assert(not hunter.strip.shown and hunter.tickers[2].cancelled, "no strip and no ticker without a target")

-- No shown timer hides it too.
hunter.setTarget(true)
hunter.mainHand.shown, hunter.ranged.shown = false, false
hunter.changed()
assert(not hunter.strip.shown, "no strip without a shown timer")

-- With a timer again the strip takes its timer's scale, and with nothing beyond Melee it hides.
hunter.ranged.shown = true
hunter.ranged.scale = 0.7
hunter.setUIScale(0.5)
hunter.setMelee(true)
hunter.changed()
assert(hunter.strip.shown and math.abs(hunter.strip.scale - 1.4) < 1e-9, "the strip takes its timer's scale")
hunter.setKnown(75, false)
hunter.handlers.SPELLS_CHANGED()
assert(not hunter.strip.shown, "no strip with nothing beyond Melee")
assert(hunter.enableRangeChecks() == 0, "never calls the game's EnableRangeCheck")

-- The mage's reaches, near to far, and no gap: the game's own bands name the nearest reach.
local mage = Load("MAGE", { [2136] = true, [116] = true, [133] = true })
mage.initializers[1]()
mage.db.rangeStrip = true
mage.setMelee(false)
mage.setAnswer(2136, true)
mage.changed()
assert(joined(segments(mage)) == "Melee | Fire Blast | Frostbolt | Fireball", "the mage's reaches near to far")
assert(mage.fontStrings[1].string == "Fire Blast", "the nearest reach names the band")

-- Improved Fire Blast (+15 yards) moves Fire Blast past Frostbolt, level with Fireball: the two are one segment,
-- and CHARACTER_POINTS_CHANGED rebuilds the strip from the client's ranges and lays the narrower row out again.
mage.setRange(2136, 0, 35)
mage.handlers.CHARACTER_POINTS_CHANGED()
assert(joined(segments(mage)) == "Melee | Frostbolt | Fire Blast", "a talent reorders and merges the mage strip")
assert(mage.fontStrings[1].string == "Fire Blast", "the talented reach still names the band")
assert(mage.fontStrings[2].width == ((240 - 2 * 3) / 3) - 6, "the narrower row is laid out again")

print("rangestrip: ok")
