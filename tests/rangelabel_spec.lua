local features, initializers, handlers, changes = {}, {}, {}, {}
local db = {}
local ns = {
	db = db,
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
	Active = function(key)
		return db[key]
	end,
	On = function(event, fn)
		handlers[event] = fn
	end,
	OnSettingChanged = function(key, fn)
		changes[key] = fn
	end,
}
assert(loadfile("Locales/enUS.lua"))("TweaksForever", ns)

-- The client reads the module makes, stubbed: a hunter's book, ranges and target, and frames that record what
-- is drawn on them.
local book = {
	{ actionID = 2973 },
	{ actionID = 75 },
	{ actionID = 116 },
	{ actionID = 133 },
}
local info = {
	[75] = { minRange = 8, maxRange = 35 },
	[116] = { minRange = 0, maxRange = 30 },
	[133] = { minRange = 0, maxRange = 35 },
	[2973] = { minRange = 0, maxRange = 5 },
}
local ranges = {}
local target, dead = true, false
local enabled = {}

local function Bar()
	local bar = {}
	function bar.CreateFontString(owner)
		local font = { shown = false }
		function font.SetPoint() end
		function font.SetJustifyH() end
		function font.SetTextColor() end
		function font.SetText(label, text)
			label.text = text
		end
		function font.Show(label)
			label.shown = true
		end
		function font.Hide(label)
			label.shown = false
		end
		owner.label = font
		return font
	end
	return bar
end

local targetBar, plateBar = Bar(), Bar()
local env = setmetatable({
	Enum = { SpellBookSpellBank = { Player = 0 } },
	UnitClass = function()
		return "Hunter", "HUNTER"
	end,
	UnitExists = function(unit)
		return unit == "target" and target or false
	end,
	UnitIsDeadOrGhost = function()
		return dead
	end,
	C_Spell = {
		GetSpellInfo = function(id)
			return info[id]
		end,
		IsSpellInRange = function(id)
			return ranges[id]
		end,
		SpellHasRange = function()
			return true
		end,
		EnableSpellRangeCheck = function(id)
			enabled[#enabled + 1] = id
		end,
	},
	C_SpellBook = {
		IsSpellKnown = function()
			return false
		end,
		GetNumSpellBookSkillLines = function()
			return 1
		end,
		GetSpellBookSkillLineInfo = function()
			return { itemIndexOffset = 0, numSpellBookItems = #book }
		end,
		GetSpellBookItemInfo = function(slot)
			return book[slot]
		end,
		FindBaseSpellByID = function(id)
			return id
		end,
	},
	C_NamePlate = {
		GetNamePlateForUnit = function(unit)
			return unit == "target" and { UnitFrame = { HealthBarsContainer = { healthBar = plateBar } } } or nil
		end,
	},
	TargetFrame = {
		TargetFrameContent = { TargetFrameContentMain = { HealthBarsContainer = { HealthBar = targetBar } } },
	},
	wipe = function(table_)
		for key in pairs(table_) do
			table_[key] = nil
		end
	end,
}, { __index = _G })
setfenv(assert(loadfile("UI/RangeLabel.lua")), env)("TweaksForever", ns)
local Model = ns.TargetRange

assert(features.targetRange.default == false)
assert(features.targetRange.category == "Interface")
assert(not features.targetRange.parent)
assert(features.targetRange.conflicts[1].addon == "Plater")

-- Bands: only the spells of the class the character knows, ascending by reach, each with its own range.
local function knownSpells(...)
	local known = {}
	for _, id in ipairs({ ... }) do
		known[id] = true
	end
	return function(id)
		return known[id] == true
	end
end
local function facts(id)
	return info[id]
end
local bands = Model.Bands("MAGE", knownSpells(116, 133), facts, function(id)
	return id == 116
end)
assert(#bands == 2)
assert(bands[1].min == 0 and bands[1].max == 30 and bands[1].inRange and not bands[1].melee)
assert(bands[2].min == 0 and bands[2].max == 35 and not bands[2].inRange)
assert(#Model.Bands("MAGE", knownSpells(116, 133), function()
	return nil
end, function()
	return false
end) == 0, "a spell with no client facts is left out")
assert(#Model.Bands("MONK", knownSpells(116), facts, function()
	return true
end) == 0, "a class with no bands has none")
assert(#Model.Bands("MAGE", knownSpells(), facts, function()
	return true
end) == 0, "only the spells the character knows count")

-- Labels: the closest reach the target is inside, and how far past the longest when it is inside none.
local function band(min, max, inRange, melee)
	return { min = min, max = max, inRange = inRange, melee = melee }
end
local melee = band(0, 5, true, true)
local auto = band(8, 35, false)
assert(Model.Label({ melee, auto }).kind == "close", "a hunter in melee is too close to shoot")
auto.inRange = true
melee.inRange = false
local label = Model.Label({ melee, auto })
assert(label.kind == "span" and label.min == 8 and label.max == 35)
auto.inRange = false
assert(Model.Label({ melee, auto }).kind == "beyond" and Model.Label({ melee, auto }).max == 35)
melee.inRange = true
assert(Model.Label({ melee }).kind == "melee")
melee.inRange = false
assert(Model.Label({ melee }).kind == "beyond" and Model.Label({ melee }).max == 5)
local nuke = band(0, 30, true)
label = Model.Label({ nuke })
assert(label.kind == "span" and label.min == 0 and label.max == 30)

-- Wired up: the label is drawn on the target frame and the target's nameplate, and hidden when it can't apply.
target = true
db.targetRange = true
for _, fn in ipairs(initializers) do
	fn()
end
assert(#enabled == 2 and enabled[1] == 2973 and enabled[2] == 75, "only the hunter spells the character knows")
ranges[2973], ranges[75] = true, false
handlers.PLAYER_TARGET_CHANGED()
assert(targetBar.label.shown and targetBar.label.text == "Too close")
assert(plateBar.label.shown and plateBar.label.text == "Too close", "the same band on the target's plate")
ranges[2973], ranges[75] = false, true
handlers.SPELL_RANGE_CHECK_UPDATE(75)
assert(targetBar.label.text == "8-35")
handlers.SPELL_RANGE_CHECK_UPDATE(99999)
assert(targetBar.label.text == "8-35", "another spell's range does not move ours")
ranges[2973], ranges[75] = false, false
handlers.PLAYER_TARGET_CHANGED()
assert(targetBar.label.text == "35+")

dead = true
handlers.UNIT_HEALTH("target")
assert(not targetBar.label.shown and not plateBar.label.shown, "a dead target shows nothing")
dead = false
handlers.UNIT_HEALTH("target")
assert(targetBar.label.shown)
target = false
handlers.PLAYER_TARGET_CHANGED()
assert(not targetBar.label.shown, "no target, nothing shown")
target = true
handlers.PLAYER_TARGET_CHANGED()
assert(targetBar.label.shown)
db.targetRange = false
changes.targetRange()
assert(not targetBar.label.shown and not plateBar.label.shown, "switched off")

print("rangelabel_spec: ok")
