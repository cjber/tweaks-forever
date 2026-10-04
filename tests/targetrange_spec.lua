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
local ranges = {}
local target, dead = true, false
local enabled = {}

local function Bar()
	local bar = {}
	function bar.CreateTexture(owner)
		local shade = { shown = false }
		function shade.SetAllPoints() end
		function shade.SetColorTexture() end
		function shade.Show(self)
			self.shown = true
		end
		function shade.Hide(self)
			self.shown = false
		end
		owner.shade = shade
		return shade
	end
	return bar
end

local targetBar, plateBar = Bar(), Bar()

-- One nameplate, as the token it currently carries and the unit it displays: the client pools the plate and hands it
-- to whatever unit next comes into nameplate range.
local plateFrame = { UnitFrame = { HealthBarsContainer = { healthBar = plateBar } } }
local plateToken, plateUnit = "nameplate1", "target"
local function GetNamePlateForUnit(unit)
	if unit == plateToken or (unit == "target" and plateUnit == "target") then
		return plateFrame
	end
	return nil
end

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
		GetNamePlateForUnit = GetNamePlateForUnit,
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
setfenv(assert(loadfile("UI/TargetRange.lua")), env)("TweaksForever", ns)
local Model = ns.TargetRange

assert(features.targetRange.default == false)
assert(features.targetRange.category == "Interface")
assert(not features.targetRange.parent)
assert(features.targetRange.conflicts[1].addon == "Plater")

-- Bands: only the spells of the class the character knows, each with whether the target is inside it.
local function knownSpells(...)
	local known = {}
	for _, id in ipairs({ ... }) do
		known[id] = true
	end
	return function(id)
		return known[id] == true
	end
end
local bands = Model.Bands("MAGE", knownSpells(116, 133), function(id)
	return id == 116
end)
assert(#bands == 2)
assert(bands[1].inRange and not bands[1].melee and not bands[2].inRange)
assert(#Model.Bands("MONK", knownSpells(116), function()
	return true
end) == 0, "a class with no bands has none")
assert(#Model.Bands("MAGE", knownSpells(), function()
	return true
end) == 0, "only the spells the character knows count")

-- Out of reach: outside every ranged attack, or outside melee for a character with no ranged one.
local function band(inRange, melee)
	return { inRange = inRange, melee = melee }
end
assert(Model.OutOfReach({ band(true, true), band(false) }), "a hunter in melee is too close to shoot")
assert(not Model.OutOfReach({ band(false, true), band(true) }), "inside the shot")
assert(Model.OutOfReach({ band(false, true), band(false) }), "past the shot")
assert(not Model.OutOfReach({ band(true, true) }), "a warrior in melee")
assert(Model.OutOfReach({ band(false, true) }), "a warrior out of melee")
assert(not Model.OutOfReach({ band(false), band(true) }), "one ranged attack reaching is enough")
assert(not Model.OutOfReach({}), "a character with no bands is never shaded")

-- Wired up: the shade covers the target frame's bar and the target's nameplate bar, and clears when it can't apply.
target = true
db.targetRange = true
for _, fn in ipairs(initializers) do
	fn()
end
assert(#enabled == 2 and enabled[1] == 2973 and enabled[2] == 75, "only the hunter spells the character knows")
ranges[2973], ranges[75] = true, false
handlers.PLAYER_TARGET_CHANGED()
assert(targetBar.shade.shown and plateBar.shade.shown, "too close to shoot shades both bars")
ranges[2973], ranges[75] = false, true
handlers.SPELL_RANGE_CHECK_UPDATE(75)
assert(not targetBar.shade.shown and not plateBar.shade.shown, "inside the shot, no shade")
ranges[75] = false
handlers.SPELL_RANGE_CHECK_UPDATE(99999)
assert(not targetBar.shade.shown, "another spell's range does not move ours")
handlers.PLAYER_TARGET_CHANGED()
assert(targetBar.shade.shown, "past the shot")

dead = true
handlers.UNIT_HEALTH("target")
assert(not targetBar.shade.shown and not plateBar.shade.shown, "a dead target has no shade")
dead = false
handlers.UNIT_HEALTH("target")
assert(targetBar.shade.shown)
target = false
handlers.PLAYER_TARGET_CHANGED()
assert(not targetBar.shade.shown, "no target, no shade")
target = true
handlers.PLAYER_TARGET_CHANGED()
assert(targetBar.shade.shown)
db.targetRange = false
changes.targetRange()
assert(not targetBar.shade.shown and not plateBar.shade.shown, "switched off")

-- The target's plate is pooled: the shade follows its plate on and clears when the plate is handed to another unit,
-- and survives the plate leaving nameplate range and coming back.
db.targetRange, target = true, true
ranges[2973], ranges[75] = true, false

-- The target is chosen while its plate is out of nameplate range, then the plate appears.
plateToken, plateUnit = nil, nil
handlers.PLAYER_TARGET_CHANGED()
assert(targetBar.shade.shown and not plateBar.shade.shown, "a target with no plate shades only the frame")
plateToken, plateUnit = "nameplate1", "target"
handlers.NAME_PLATE_UNIT_ADDED("nameplate1")
assert(plateBar.shade.shown, "the plate that appears is shaded")

-- The plate leaves and is pooled for another unit: the shade must not stay on it.
plateUnit = nil
handlers.NAME_PLATE_UNIT_REMOVED("nameplate1")
plateToken, plateUnit = "nameplate1", "mob2"
assert(not plateBar.shade.shown, "a plate reused for another unit carries no shade")

-- Walking out of and back into nameplate range clears the shade with the plate and restores it with the plate.
plateToken, plateUnit = "nameplate1", "target"
handlers.NAME_PLATE_UNIT_ADDED("nameplate1")
assert(plateBar.shade.shown)
plateUnit = nil
handlers.NAME_PLATE_UNIT_REMOVED("nameplate1")
plateToken = nil
assert(not plateBar.shade.shown, "walking out of nameplate range clears the plate's shade")
plateToken, plateUnit = "nameplate1", "target"
handlers.NAME_PLATE_UNIT_ADDED("nameplate1")
assert(plateBar.shade.shown, "walking back in restores it")

print("targetrange_spec: ok")
