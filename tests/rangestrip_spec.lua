-- Range strip (UI/RangeStrip.lua): each class's reaches from the client's own spell ranges, the band rule from
-- the nearest reach that answers true, the dead zone only when a shown reach has an 8-yard minimum, and a ticker
-- while Melee is not the answer.
local NIL_ANSWER = {}

local SPELL_NAMES = {
	[75] = "Auto Shot",
	[100] = "Charge",
	[20252] = "Intercept",
	[2480] = "Shoot Bow",
	[7918] = "Shoot Gun",
	[7919] = "Shoot Crossbow",
	[2764] = "Throw",
	[16979] = "Feral Charge",
	[5176] = "Wrath",
	[20271] = "Judgement",
	[2136] = "Fire Blast",
	[116] = "Frostbolt",
	[133] = "Fireball",
	[585] = "Smite",
	[8092] = "Mind Blast",
	[5782] = "Fear",
	[686] = "Shadow Bolt",
	[8042] = "Earth Shock",
	[403] = "Lightning Bolt",
}

-- C_Spell.GetSpellInfo's minRange and maxRange for each spell, in yards, as the client answers them before any
-- talent. A spec moves one to prove the strip follows the client rather than a table of fixed distances.
local SPELL_RANGES = {
	[75] = { 8, 35 },
	[100] = { 8, 25 },
	[20252] = { 8, 25 },
	[2480] = { 8, 30 },
	[7918] = { 8, 30 },
	[7919] = { 8, 30 },
	[2764] = { 8, 30 },
	[16979] = { 8, 25 },
	[5176] = { 0, 30 },
	[20271] = { 0, 10 },
	[2136] = { 0, 20 },
	[116] = { 0, 30 },
	[133] = { 0, 35 },
	[585] = { 0, 30 },
	[8092] = { 0, 30 },
	[5782] = { 0, 20 },
	[686] = { 0, 30 },
	[8042] = { 0, 20 },
	[403] = { 0, 30 },
}

local function Load(class, options)
	options = options or {}
	local features, initializers, handlers, db = {}, {}, {}, {}
	local changed

	local textures, fontStrings = {}, {}
	local textOrder = 0
	local strip = { shown = false, scripts = {}, scale = 1, width = 240, points = {} }
	function strip.SetFrameStrata() end
	function strip.SetFrameLevel() end
	function strip.SetHeight() end
	function strip.SetScale(_, scale)
		strip.scale = scale
	end
	function strip.Show()
		strip.shown = true
	end
	function strip.Hide()
		strip.shown = false
	end
	function strip.ClearAllPoints()
		strip.points = {}
	end
	function strip.SetPoint(_, point, relative, relativePoint, x, y)
		table.insert(strip.points, { point, relative, relativePoint, x, y })
	end
	function strip.GetWidth()
		return strip.width
	end
	function strip.SetScript(_, script, fn)
		strip.scripts[script] = fn
	end
	function strip.CreateTexture()
		local texture = { shown = false }
		function texture.SetAtlas(_, atlas)
			texture.atlas = atlas
		end
		function texture.SetVertexColor(_, r, g, b)
			texture.colour = { r, g, b }
		end
		function texture.SetPoint(_, point, relative, relativePoint, x, y)
			table.insert(strip.points, { point, relative, relativePoint, x, y })
		end
		function texture.ClearAllPoints() end
		function texture.SetAllPoints() end
		function texture.Show()
			texture.shown = true
		end
		function texture.Hide()
			texture.shown = false
		end
		table.insert(textures, texture)
		return texture
	end
	function strip.CreateFontString()
		local text = { shown = false, string = "", wordWrap = true }
		function text.SetFontObject(_, object)
			text.fontObject = object
		end
		function text.SetJustifyH() end
		function text.SetJustifyV() end
		function text.SetHeight() end
		function text.SetWidth(_, width)
			text.width = width
		end
		function text.SetWordWrap(_, wrap)
			text.wordWrap = wrap
		end
		function text.SetMaxLines() end
		function text.SetPoint(_, point, relative, relativePoint, x, y)
			table.insert(strip.points, { point, relative, relativePoint, x, y })
		end
		function text.ClearAllPoints() end
		function text.SetAllPoints() end
		function text.SetText(_, value)
			text.string = value
			textOrder = textOrder + 1
			text.order = textOrder
		end
		function text.SetTextColor(_, r, g, b)
			text.colour = { r, g, b }
		end
		function text.Show()
			text.shown = true
		end
		function text.Hide()
			text.shown = false
		end
		table.insert(fontStrings, text)
		return text
	end

	local function Timer(top, shown, scale)
		local timer = { top = top, shown = shown, scale = scale or 1, scripts = {} }
		function timer.IsShown()
			return timer.shown
		end
		function timer.GetTop()
			return timer.top
		end
		function timer.GetWidth()
			return 240
		end
		function timer.GetEffectiveScale()
			return timer.scale
		end
		function timer.HookScript(_, script, fn)
			timer.scripts[script] = fn
		end
		return timer
	end

	local mainHand, ranged = Timer(300, true), Timer(200, true)
	local tickers = {}
	local enableRangeChecks, interactCalls = 0, 0
	local melee, interact, target = true, true, true
	local uiScale = 1
	local knownSpells = options.known or {}
	local answers = options.answers or {}
	local ranges = {}
	for spell, range in pairs(SPELL_RANGES) do
		ranges[spell] = { range[1], range[2] }
	end
	local names = SPELL_NAMES
	local item, itemClass, itemSubclass = options.item, options.classID, options.subclass

	local function swingReach(swingType)
		assert(swingType == 0, "melee reads the main-hand swing")
		return melee
	end

	local function interactCheck()
		interactCalls = interactCalls + 1
		return interact
	end

	local function spellInRange(spell)
		local answer = answers[spell]
		if answer == NIL_ANSWER then
			return nil
		end
		if answer == nil then
			return false
		end
		return answer
	end

	local function itemInfo(id)
		if not id or not item then
			return nil
		end
		return id, "Weapon", "Ranged", "INVTYPE_RANGED", 0, itemClass, itemSubclass
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
			IsTargetWithinSwingRange = swingReach,
			EnableRangeCheck = function()
				enableRangeChecks = enableRangeChecks + 1
			end,
		},
		CheckInteractDistance = interactCheck,
		C_Spell = {
			IsSpellInRange = spellInRange,
			GetSpellName = function(spell)
				return names[spell]
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
			GetItemInfoInstant = itemInfo,
		},
		C_Timer = {
			NewTicker = function(interval, fn)
				local ticker = { interval = interval, cancelled = false }
				function ticker.Cancel()
					ticker.cancelled = true
				end
				function ticker.Fire()
					fn()
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
	setfenv(assert(loadfile("UI/RangeStrip.lua")), env)("TweaksForever", ns)

	return {
		env = env,
		ns = ns,
		model = ns.RangeStrip,
		features = features,
		initializers = initializers,
		handlers = handlers,
		db = db,
		changed = function()
			changed()
		end,
		strip = strip,
		textures = textures,
		fontStrings = fontStrings,
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
		setNil = function(spell)
			answers[spell] = NIL_ANSWER
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

-- The class tables, as the client's spell ranges show them.
local Model = Load("HUNTER").model

local hunter = Model.Reaches("HUNTER", known({ [75] = true }), nil)
assert(ids(hunter) == "75", "hunter: Auto Shot alone")
assert(hunter[1].min == 8 and hunter[1].max == 35, "hunter: Auto Shot's 8-35")

local warrior = Model.Reaches("WARRIOR", known({ [100] = true, [2480] = true }), 2480)
assert(ids(warrior) == "100,2480", "warrior: Charge and the ranged weapon")
assert(warrior[1].min == 8 and warrior[1].max == 25, "warrior: Charge at 8-25")
assert(warrior[1].spell == 100, "warrior: Charge")
assert(warrior[2].spell == 2480, "warrior: the bow's Shoot Bow")

local intercept = Model.Reaches("WARRIOR", known({ [20252] = true, [7918] = true }), 7918)
assert(ids(intercept) == "20252,7918" and intercept[1].spell == 20252, "warrior: Intercept when Charge is unknown")
assert(intercept[2].spell == 7918, "warrior: the gun's Shoot Gun")

local mage = Model.Reaches("MAGE", known({ [2136] = true, [116] = true, [133] = true }), nil)
assert(ids(mage) == "2136,116,133", "mage: three reaches, near to far")
assert(mage[1].max == 20 and mage[2].max == 30 and mage[3].max == 35, "mage: 20, 30 and 35 yards")
for _, reach in ipairs(mage) do
	assert(reach.min == 0, "mage: every reach has no minimum")
end

local paladin = Model.Reaches("PALADIN", known({ [20271] = true }), nil)
assert(ids(paladin) == "20271", "paladin: Judgement alone")
assert(paladin[1].min == 0 and paladin[1].max == 10, "paladin: Judgement at 0-10")

local priest = Model.Reaches("PRIEST", known({ [585] = true, [8092] = true }), nil)
assert(ids(priest) == "585+8092" and priest[1].spell == 585, "priest: Smite and Mind Blast are one segment")
local priestAlt = Model.Reaches("PRIEST", known({ [8092] = true }), nil)
assert(ids(priestAlt) == "8092" and priestAlt[1].spell == 8092, "priest: Mind Blast when Smite is unknown")

local rogue = Model.Reaches("ROGUE", known({}), nil)
assert(#rogue == 0, "rogue: no ranged weapon, no reach")
local rogueBow = Model.Reaches("ROGUE", known({ [2480] = true }), 2480)
assert(ids(rogueBow) == "2480", "rogue: the bow's Shoot Bow")

local druid = Model.Reaches("DRUID", known({ [16979] = true, [5176] = true }), nil)
assert(ids(druid) == "16979,5176", "druid: Feral Charge then Wrath")
assert(druid[1].min == 8 and druid[2].min == 0, "druid: only Feral Charge has a minimum")

local warlock = Model.Reaches("WARLOCK", known({ [5782] = true, [686] = true }), nil)
assert(ids(warlock) == "5782,686", "warlock: Fear then Shadow Bolt")
local shaman = Model.Reaches("SHAMAN", known({ [8042] = true, [403] = true }), nil)
assert(ids(shaman) == "8042,403", "shaman: Earth Shock then Lightning Bolt")

-- A spell the player has not learned is not a segment, and neither is one the client cannot name.
local mageOne = Model.Reaches("MAGE", known({ [2136] = true }), nil)
assert(ids(mageOne) == "2136", "only the known spell is shown")
local unknown = Load("HUNTER", { known = { [75] = true } })
unknown.env.C_Spell.GetSpellName = function()
	return nil
end
assert(#unknown.model.Reaches("HUNTER", unknown.model.Known, nil) == 1, "the spell is known")
unknown.initializers[1]()
unknown.db.rangeStrip = true
unknown.changed()
assert(not unknown.strip.shown, "a reach with no readable name is not shown")

-- The client's own range decides the order: Improved Fire Blast (+15 yards) pushes Fire Blast to 35, past
-- Frostbolt's 30 and level with Fireball's 35, so Fire Blast and Fireball are one segment.
local talented = Load("MAGE", { known = { [2136] = true, [116] = true, [133] = true } })
talented.setRange(2136, 0, 35)
local mageTalent = talented.model.Reaches("MAGE", talented.model.Known, nil)
assert(ids(mageTalent) == "116,2136+133", "a talent reorders the mage reaches")
assert(mageTalent[2].spell == 2136 and mageTalent[2].spells[2] == 133, "Fireball joins Fire Blast's range")

-- A spell the client gives no range is left out, and one whose maximum is no further than melee is dropped.
talented.setRange(116, nil)
local mageNoRange = talented.model.Reaches("MAGE", talented.model.Known, nil)
assert(ids(mageNoRange) == "2136+133", "a spell the client gives no range is left out")
local meleeReach = Load("MAGE", { known = { [2136] = true, [133] = true } })
meleeReach.setRange(133, 0, 5)
assert(ids(meleeReach.model.Reaches("MAGE", meleeReach.model.Known, nil)) == "2136", "a melee-range spell is dropped")

-- SpellRange reads the client's table and answers nothing for a spell it cannot describe.
local autoMin, autoMax = Model.SpellRange(75)
assert(autoMin == 8 and autoMax == 35, "the client's Auto Shot range")
assert(Model.SpellRange(999999) == nil, "no range for an unknown spell")

-- The ranged slot's item subclass names its shot, and an empty or other slot has none.
assert(Model.RangedWeapon(2) == 2480, "bow")
assert(Model.RangedWeapon(3) == 7918, "gun")
assert(Model.RangedWeapon(18) == 7919, "crossbow")
assert(Model.RangedWeapon(16) == 2764, "thrown")
assert(Model.RangedWeapon(1) == nil and Model.RangedWeapon(nil) == nil, "no shot for anything else")

local equipment = Load("ROGUE", { item = 1000, classID = 2, subclass = 18 })
assert(equipment.model.EquippedRanged() == 7919, "a crossbow in the ranged slot")
equipment.setRanged(1000, 2, 4)
assert(equipment.model.EquippedRanged() == nil, "an armour item is no shot")
equipment.setRanged(nil)
assert(equipment.model.EquippedRanged() == nil, "an empty ranged slot")

-- The band rule, by hand, with the reaches' answers filled in.
local function reach(key, min, max, check)
	return { key = key, min = min, max = max, check = check }
end

local function noInteract()
	error("the 8-yard check must not run")
end

assert(Model.Band(true, { reach("autoshot", 8, 35, false) }, noInteract) == "melee", "melee wins")
assert(Model.Band(false, { reach("autoshot", 8, 35, true) }, noInteract) == "autoshot", "the reach answers")
assert(Model.Band(false, { reach("autoshot", 8, 35, false) }, function()
	return true
end) == "dead", "out of reach inside 8 yards")
assert(Model.Band(false, { reach("autoshot", 8, 35, false) }, function()
	return false
end) == "far", "out of reach beyond 8 yards")
assert(Model.Band(false, { reach("autoshot", 8, 35, false) }, function()
	return nil
end) == nil, "the 8-yard check answered nothing")
assert(Model.Band(false, { reach("wrath", 0, 30, nil) }, noInteract) == nil, "the reach answered nothing")
assert(Model.Band(nil, { reach("autoshot", 8, 35, false) }, noInteract) == nil, "melee unknown, no claim")
assert(Model.Band(nil, { reach("autoshot", 8, 35, true) }, noInteract) == "autoshot", "a reach decides alone")

-- Melee wins; otherwise the nearest reach (smallest maximum) that answers true.
local mageReaches = {
	reach("fireblast", 0, 20, true),
	reach("frostbolt", 0, 30, true),
	reach("fireball", 0, 35, true),
}
assert(Model.Band(false, mageReaches, noInteract) == "fireblast", "the nearest of three reaches")
mageReaches = {
	reach("fireblast", 0, 20, false),
	reach("frostbolt", 0, 30, true),
	reach("fireball", 0, 35, true),
}
assert(Model.Band(false, mageReaches, noInteract) == "frostbolt", "the nearest of the two that reach")
mageReaches = {
	reach("fireblast", 0, 20, false),
	reach("frostbolt", 0, 30, false),
	reach("fireball", 0, 35, true),
}
assert(Model.Band(false, mageReaches, noInteract) == "fireball", "only the longest reach answers")

-- A nil that could be nearer decides nothing; a nil farther out does not.
local nilNear = {
	reach("fireblast", 0, 20, nil),
	reach("frostbolt", 0, 30, true),
	reach("fireball", 0, 35, true),
}
assert(Model.Band(false, nilNear, noInteract) == nil, "a nearer reach with no answer hides the band")
local nilFar = {
	reach("fireblast", 0, 20, true),
	reach("frostbolt", 0, 30, nil),
	reach("fireball", 0, 35, true),
}
assert(Model.Band(false, nilFar, noInteract) == "fireblast", "a farther nil does not decide")

-- The dead zone needs a shown reach with an 8-yard minimum, and the 8-yard answer.
local warriorReaches = {
	reach("charge", 8, 25, false),
	reach("ranged", 8, 30, false),
}
assert(Model.Band(false, warriorReaches, function()
	return true
end) == "dead", "two reaches with an 8-yard minimum leave a gap")
assert(Model.Band(false, { reach("fireblast", 3, 20, false) }, function()
	return true
end) == "dead", "any minimum range opens the gap")
local paladinReaches = { reach("judgement", 0, 10, false) }
assert(Model.Band(false, paladinReaches, noInteract) == "far", "no minimum, so no dead zone and no 8-yard check")
assert(Model.Band(false, paladinReaches, noInteract) == "far", "every check answered false")
assert(Model.Band(false, { reach("autoshot", 8, 35, false) }, function()
	return true
end) == "dead", "a target inside 8 yards")

-- A nil below 8 yards could reach inside the gap; a nil with an 8-yard minimum cannot.
assert(Model.Band(false, {
	reach("feralcharge", 8, 25, false),
	reach("wrath", 0, 30, nil),
}, function()
	return true
end) == nil, "a spell with no minimum and no answer could reach inside 8 yards")
assert(Model.Band(false, {
	reach("charge", 8, 25, nil),
	reach("ranged", 8, 30, false),
}, function()
	return true
end) == "dead", "an 8-yard minimum cannot reach inside the gap")
assert(Model.Band(false, warriorReaches, function()
	return false
end) == "far", "every check false beyond 8 yards")
assert(Model.Band(false, {
	reach("charge", 8, 25, nil),
	reach("ranged", 8, 30, false),
}, function()
	return false
end) == nil, "undecided beyond 8 yards")

-- The feature is on by default and lives on the Interface page, for every class.
local feature = Load("HUNTER").features.rangeStrip
assert(feature.default == true, "on by default")
assert(feature.category == "Interface")
assert(feature.name == "Range strip", "named for every class")
assert(feature.tooltip:find("which of your attacks reach your target", 1, true), "the tooltip names attacks")

-- A hunter's strip: Melee, the Dead zone its Auto Shot minimum leaves, then Auto Shot.
local hunterUI = Load("HUNTER", { known = { [75] = true } })
hunterUI.initializers[1]()
for _, event in ipairs({
	"PLAYER_SWING_RANGE_UPDATE",
	"PLAYER_TARGET_CHANGED",
	"PLAYER_EQUIPMENT_CHANGED",
	"SPELLS_CHANGED",
	"CHARACTER_POINTS_CHANGED",
	"PLAYER_LEVEL_UP",
	"PLAYER_TALENT_UPDATE",
}) do
	assert(hunterUI.handlers[event], event .. " is handled")
end
assert(not hunterUI.strip.shown, "off at login")
assert(
	hunterUI.mainHand.scripts.OnShow and hunterUI.mainHand.scripts.OnHide and hunterUI.mainHand.scripts.OnSizeChanged
)
assert(hunterUI.ranged.scripts.OnShow and hunterUI.ranged.scripts.OnHide and hunterUI.ranged.scripts.OnSizeChanged)

hunterUI.db.rangeStrip = true
hunterUI.changed()
assert(hunterUI.strip.shown, "on, the strip shows")
assert(hunterUI.strip.points[1][2] == hunterUI.mainHand, "docked on the timer higher on screen")
assert(joined(segments(hunterUI)) == "Melee | Dead zone | Auto Shot", "hunter's three segments")
assert(hunterUI.fontStrings[1].string == "Melee", "the band label")
assert(hunterUI.fontStrings[1].fontObject == "GameFontNormal", "the band label in the game's normal font")
for index = 2, 4 do
	assert(hunterUI.fontStrings[index].fontObject == "GameFontHighlightSmall", "segment names in the game's small font")
	assert(hunterUI.fontStrings[index].wordWrap == false, "a segment name does not wrap")
end
local segmentWidth = (240 - 2 * 3) / 3
for index = 2, 4 do
	assert(hunterUI.fontStrings[index].width == segmentWidth - 6, "each name is clipped 6 inside its segment")
end
assert(hunterUI.textures[2].shown, "the Melee segment is lit")
assert(not hunterUI.textures[5].shown and not hunterUI.textures[8].shown, "only the Melee segment")
assert(#hunterUI.tickers == 0, "no ticker while Melee is lit")
assert(hunterUI.interactCalls() == 0, "no 8-yard check while a reach answers")

-- The other shown timer is higher now.
hunterUI.mainHand.top, hunterUI.ranged.top = 100, 400
hunterUI.changed()
assert(hunterUI.strip.points[1][2] == hunterUI.ranged, "the higher timer takes the strip")

-- Auto Shot reaches: the green segment, and the ticker follows the spell band.
hunterUI.mainHand.top = 400
hunterUI.setMelee(false)
hunterUI.setAnswer(75, true)
hunterUI.changed()
assert(hunterUI.fontStrings[1].string == "Auto Shot")
assert(hunterUI.textures[8].shown and not hunterUI.textures[2].shown and not hunterUI.textures[5].shown)
assert(hunterUI.textures[8].colour[1] == 0.25, "every spell band is green")
assert(#hunterUI.tickers == 1 and not hunterUI.tickers[1].cancelled, "a ticker while a spell band is lit")
assert(hunterUI.tickers[1].interval == 0.2, "every 0.2 s")

-- Auto Shot out of reach but inside 8 yards: the Dead zone, the red segment, and the same ticker.
hunterUI.setAnswer(75, false)
hunterUI.setInteract(true)
hunterUI.changed()
assert(hunterUI.fontStrings[1].string == "Dead zone")
assert(hunterUI.textures[5].shown and not hunterUI.textures[2].shown and not hunterUI.textures[8].shown)
assert(hunterUI.textures[5].colour[1] == 1 and hunterUI.textures[5].colour[2] == 0.13, "the Dead zone is red")
assert(#hunterUI.tickers == 1 and not hunterUI.tickers[1].cancelled, "the ticker keeps watching the gap")

-- Beyond 8 yards: Too far, with no segment lit, still on the same ticker.
hunterUI.setInteract(false)
hunterUI.tickers[1].Fire()
assert(hunterUI.fontStrings[1].string == "Too far")
assert(not hunterUI.textures[2].shown and not hunterUI.textures[5].shown and not hunterUI.textures[8].shown)
assert(hunterUI.fontStrings[1].colour[1] == 0.55, "Too far in grey")
assert(#hunterUI.tickers == 1, "the same ticker keeps running")

-- A nil answer from the 8-yard check hides the label and every segment rather than claiming Too far.
hunterUI.setInteract(nil)
hunterUI.changed()
assert(not hunterUI.fontStrings[1].shown, "no label when the check answered nothing")
assert(not hunterUI.textures[2].shown and not hunterUI.textures[5].shown and not hunterUI.textures[8].shown)

-- We are inside 8 yards and Auto Shot's minimum is 8: its nil answer cannot reach here, so the gap stands.
hunterUI.setInteract(true)
hunterUI.setNil(75)
hunterUI.changed()
assert(hunterUI.fontStrings[1].string == "Dead zone", "an 8-yard minimum cannot reach inside the gap")

-- Melee reaches again: the ticker stops.
hunterUI.setMelee(true)
hunterUI.changed()
assert(hunterUI.fontStrings[1].string == "Melee")
assert(hunterUI.tickers[1].cancelled, "the ticker stops once Melee reaches")

-- A nil melee answer does not decide a true reach; a nil melee does decide against the dead zone.
hunterUI.setMelee(nil)
hunterUI.setAnswer(75, true)
hunterUI.changed()
assert(hunterUI.fontStrings[1].string == "Auto Shot", "a reach decides alone")
hunterUI.setAnswer(75, false)
hunterUI.setInteract(true)
hunterUI.changed()
assert(not hunterUI.fontStrings[1].shown, "melee unknown leaves the dead zone unclaimed")

-- No attackable target hides the strip and stops the ticker.
hunterUI.setMelee(false)
hunterUI.changed()
assert(#hunterUI.tickers == 2 and not hunterUI.tickers[2].cancelled, "a fresh ticker")
hunterUI.setTarget(false)
hunterUI.changed()
assert(not hunterUI.strip.shown, "no strip without a target")
assert(hunterUI.tickers[2].cancelled, "no ticker without a target")

-- No shown timer hides it too.
hunterUI.setTarget(true)
hunterUI.mainHand.shown, hunterUI.ranged.shown = false, false
hunterUI.changed()
assert(not hunterUI.strip.shown, "no strip without a shown timer")
assert(hunterUI.tickers[2].cancelled, "still no ticker")

-- The strip takes its timer's scale, relative to its own parent.
hunterUI.ranged.shown, hunterUI.ranged.scale = true, 0.7
hunterUI.setUIScale(0.5)
hunterUI.changed()
assert(math.abs(hunterUI.strip.scale - 1.4) < 1e-9, "effective scale matched")

-- Blizzard's own timer keeps ownership of its range check.
assert(hunterUI.enableRangeChecks() == 0, "never calls EnableRangeCheck")

-- Warrior: a gap, Charge and the equipped shot, and the shot follows the ranged slot.
local warriorUI = Load("WARRIOR", { known = { [100] = true, [2480] = true }, item = 1000, classID = 2, subclass = 2 })
warriorUI.initializers[1]()
warriorUI.db.rangeStrip = true
warriorUI.setMelee(false)
warriorUI.setAnswer(100, true)
warriorUI.setAnswer(2480, true)
warriorUI.changed()
assert(joined(segments(warriorUI)) == "Melee | Dead zone | Charge | Shoot Bow", "warrior's four segments")
assert(warriorUI.fontStrings[1].string == "Charge", "the nearest of the two reaches")
assert(warriorUI.textures[8].shown, "the Charge fill")
warriorUI.setKnown(7918, true)
warriorUI.setRanged(1000, 3, 2)
warriorUI.handlers.PLAYER_EQUIPMENT_CHANGED()
assert(joined(segments(warriorUI)) == "Melee | Dead zone | Charge | Shoot Gun", "equipping a gun renames the shot")

warriorUI.setKnown(100, false)
warriorUI.setAnswer(7918, true)
warriorUI.handlers.SPELLS_CHANGED()
assert(joined(segments(warriorUI)) == "Melee | Dead zone | Shoot Gun", "a forgotten Charge leaves the shot")
assert(warriorUI.fontStrings[1].string == "Shoot Gun", "the remaining reach names the band")

-- Mage: three reaches and no gap.
local mageUI = Load("MAGE", { known = { [2136] = true, [116] = true, [133] = true } })
mageUI.initializers[1]()
mageUI.db.rangeStrip = true
mageUI.setMelee(false)
mageUI.setAnswer(2136, true)
mageUI.changed()
assert(joined(segments(mageUI)) == "Melee | Fire Blast | Frostbolt | Fireball", "mage's four segments")
assert(not joined(segments(mageUI)):find("Dead zone", 1, true), "no Dead zone")
assert(mageUI.fontStrings[1].string == "Fire Blast", "the nearest reach names the band")

-- Improved Fire Blast (+15 yards) puts Fire Blast at 35; a talent point rebuilds the segments and Fire Blast moves
-- past Frostbolt, level with Fireball. The list changed, so the strip lays itself out again.
mageUI.setRange(2136, 0, 35)
mageUI.handlers.CHARACTER_POINTS_CHANGED()
assert(joined(segments(mageUI)) == "Melee | Frostbolt | Fire Blast", "a talent reorders the mage strip")
assert(mageUI.fontStrings[1].string == "Fire Blast", "the talented reach still names the band")
assert(mageUI.fontStrings[2].width == ((240 - 2 * 3) / 3) - 6, "the narrower row is laid out again")

-- Equal ranges are one segment, named by the first spell in table order: Fireball at Fire Blast's 20.
local mergeUI = Load("MAGE", { known = { [2136] = true, [116] = true, [133] = true } })
mergeUI.setRange(133, 0, 20)
mergeUI.initializers[1]()
mergeUI.db.rangeStrip = true
mergeUI.setMelee(false)
mergeUI.setAnswer(2136, true)
mergeUI.changed()
assert(
	joined(segments(mergeUI)) == "Melee | Fire Blast | Frostbolt",
	"equal ranges merge under the first in table order"
)

-- A minimum the client reports at 3 yards still opens the Dead zone, not only Auto Shot's 8.
local gapUI = Load("MAGE", { known = { [2136] = true } })
gapUI.setRange(2136, 3, 20)
gapUI.initializers[1]()
gapUI.db.rangeStrip = true
gapUI.setMelee(false)
gapUI.changed()
assert(joined(segments(gapUI)) == "Melee | Dead zone | Fire Blast", "any minimum range opens the Dead zone")

-- Paladin: Melee and Judgement alone.
local paladinUI = Load("PALADIN", { known = { [20271] = true } })
paladinUI.initializers[1]()
paladinUI.db.rangeStrip = true
paladinUI.setMelee(false)
paladinUI.setAnswer(20271, true)
paladinUI.changed()
assert(joined(segments(paladinUI)) == "Melee | Judgement", "paladin's one reach, no gap")
assert(paladinUI.fontStrings[1].string == "Judgement")

-- Priest: Smite and Mind Blast are one segment.
local priestUI = Load("PRIEST", { known = { [585] = true, [8092] = true } })
priestUI.initializers[1]()
priestUI.db.rangeStrip = true
priestUI.setMelee(false)
priestUI.setAnswer(585, true)
priestUI.changed()
assert(joined(segments(priestUI)) == "Melee | Smite", "priest's duplicate reaches are one segment")
assert(priestUI.fontStrings[1].string == "Smite")

-- One Reach talent stops them sharing a range: Shadow Reach takes Mind Blast past Smite, so they are two segments.
priestUI.setRange(8092, 0, 36)
priestUI.handlers.CHARACTER_POINTS_CHANGED()
assert(joined(segments(priestUI)) == "Melee | Smite | Mind Blast", "different ranges split Smite and Mind Blast")
-- A talent the other way reorders them again; the client's ranges decide, never the table.
priestUI.setRange(585, 0, 40)
priestUI.handlers.PLAYER_TALENT_UPDATE()
assert(joined(segments(priestUI)) == "Melee | Mind Blast | Smite", "the further reach moves last")

-- Druid: Feral Charge's minimum leaves a gap, and Wrath names the band beyond it.
local druidUI = Load("DRUID", { known = { [16979] = true, [5176] = true } })
druidUI.initializers[1]()
druidUI.db.rangeStrip = true
druidUI.setMelee(false)
druidUI.setAnswer(5176, true)
druidUI.changed()
assert(joined(segments(druidUI)) == "Melee | Dead zone | Feral Charge | Wrath", "druid's gap and two reaches")
assert(druidUI.fontStrings[1].string == "Wrath")

-- Rogue: no ranged weapon means nothing beyond Melee, so no strip; equipping one brings it back.
local rogueUI = Load("ROGUE", { known = {} })
rogueUI.initializers[1]()
rogueUI.db.rangeStrip = true
rogueUI.changed()
assert(not rogueUI.strip.shown, "no strip with nothing beyond Melee")

rogueUI.setKnown(2480, true)
rogueUI.setRanged(1000, 2, 2)
rogueUI.handlers.PLAYER_EQUIPMENT_CHANGED()
assert(rogueUI.strip.shown, "a bow brings the strip back")
assert(joined(segments(rogueUI)) == "Melee | Dead zone | Shoot Bow", "the rogue's bow")
rogueUI.setMelee(false)
rogueUI.setAnswer(2480, true)
rogueUI.changed()
assert(rogueUI.fontStrings[1].string == "Shoot Bow")

rogueUI.setRanged(nil)
rogueUI.handlers.PLAYER_EQUIPMENT_CHANGED()
assert(not rogueUI.strip.shown, "an empty ranged slot hides the strip again")

-- Every class that has a reach shows the strip with it.
local everyClass = {
	{ "WARRIOR", 100 },
	{ "ROGUE", 2480 },
	{ "HUNTER", 75 },
	{ "DRUID", 5176 },
	{ "PALADIN", 20271 },
	{ "MAGE", 2136 },
	{ "PRIEST", 585 },
	{ "WARLOCK", 5782 },
	{ "SHAMAN", 8042 },
}
for _, shape in ipairs(everyClass) do
	local class, spell = shape[1], shape[2]
	local ui = Load(class, {
		known = { [spell] = true },
		item = class == "ROGUE" and 1000 or nil,
		classID = 2,
		subclass = 2,
	})
	ui.initializers[1]()
	ui.db.rangeStrip = true
	ui.setMelee(false)
	ui.setAnswer(spell, true)
	ui.changed()
	assert(ui.strip.shown, class .. " shows its strip")
	assert(#segments(ui) >= 2, class .. " shows a reach beyond Melee")
end

print("rangestrip: ok")
