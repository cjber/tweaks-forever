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

-- The client reads the module makes, stubbed: a shaman's book, what reaches each unit, and frames that record
-- what is drawn on them.
local book = { { actionID = 8042 }, { actionID = 403 }, { actionID = 116 } }
local reach = { nameplate1 = { [8042] = false, [403] = true }, nameplate2 = { [8042] = true, [403] = true } }
local hostile = { nameplate1 = true, nameplate2 = true }
local dead = {}

local function Region()
	local region = { shown = false, points = {} }
	function region.SetSize(self, width, height)
		self.width, self.height = width, height
	end
	function region.SetWidth(self, width)
		self.width = width
	end
	function region.SetHeight(self, height)
		self.height = height
	end
	function region.GetHeight(self)
		return self.height
	end
	function region.SetPoint(self, ...)
		self.points[#self.points + 1] = { ... }
	end
	function region.ClearAllPoints(self)
		self.points = {}
	end
	function region.SetTexCoord() end
	function region.SetTexture(self, texture)
		self.texture = texture
	end
	function region.SetVertexColor(self, red, green, blue)
		self.color = { red, green, blue }
	end
	function region.SetDesaturated(self, desaturated)
		self.desaturated = desaturated
	end
	function region.SetAlpha(self, alpha)
		self.alpha = alpha
	end
	function region.SetColorTexture(self, red, green, blue, alpha)
		self.colorTexture = { red, green, blue, alpha }
	end
	function region.SetAllPoints() end
	function region.SetFrameLevel() end
	function region.GetFrameLevel()
		return 1
	end
	function region.Show(self)
		self.shown = true
	end
	function region.Hide(self)
		self.shown = false
	end
	function region.CreateTexture(self, _, layer)
		local texture = Region()
		texture.layer = layer
		self.textures[#self.textures + 1] = texture
		return texture
	end
	region.textures = {}
	return region
end

local function Bar()
	local bar = Region()
	bar.height = 20
	return bar
end

local function Plate()
	local bar = Bar()
	bar.name = "bar"
	local level, raid, cast = Region(), Region(), Region()
	level.name, raid.name, cast.name = "level", "raid", "cast"
	return {
		UnitFrame = {
			HealthBarsContainer = { healthBar = bar },
			PlayerLevelDiffFrame = level,
			RaidTargetFrame = raid,
			CastBarsContainer = cast,
		},
	}
end

local created = {}
local plateFrames = { nameplate1 = Plate(), nameplate2 = Plate() }
local ticks, cancelled = {}, 0

local env = setmetatable({
	Enum = { SpellBookSpellBank = { Player = 0 } },
	UnitClass = function()
		return "Shaman", "SHAMAN"
	end,
	UnitCanAttack = function(_, unit)
		return hostile[unit] == true
	end,
	UnitIsDeadOrGhost = function(unit)
		return dead[unit] == true
	end,
	CreateFrame = function(_, _, parent)
		local frame = Region()
		created[parent] = frame
		return frame
	end,
	C_Spell = {
		IsSpellInRange = function(id, unit)
			return reach[unit][id]
		end,
		GetSpellTexture = function(id)
			return "icon" .. id
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
			return plateFrames[unit]
		end,
	},
	C_Timer = {
		NewTicker = function(_, fn)
			ticks[#ticks + 1] = fn
			return {
				Cancel = function()
					cancelled = cancelled + 1
				end,
			}
		end,
	},
	wipe = function(table_)
		for key in pairs(table_) do
			table_[key] = nil
		end
	end,
}, { __index = _G })
setfenv(assert(loadfile("UI/SpellReach.lua")), env)("TweaksForever", ns)
local Model = ns.SpellReach

-- Features: the switch, and the sub-options indented under it, each with its own default.
assert(features.spellReach.default == false)
assert(features.spellReach.category == "Interface")
assert(not features.spellReach.parent)
assert(features.spellReach.conflicts[1].addon == "RangeLens")
assert(features.spellReachPosition.parent == "spellReach" and features.spellReachPosition.default == "left")
assert(features.spellReachPosition.options[1][1] == "left" and features.spellReachPosition.options[3][1] == "below")
assert(features.spellReachSize.parent == "spellReach" and features.spellReachSize.default == 100)
assert(features.spellReachSize.slider.min == 50 and features.spellReachSize.slider.max == 200)
assert(features.spellReachStyle.default == "red" and features.spellReachStyle.options[3][1] == "hidden")
assert(features.spellReachTargets.default == "all" and features.spellReachTargets.options[2][1] == "target")

-- Icons: the class's spells the character knows, in the class's order, each with whether it reaches.
local function knownSpells(...)
	local known = {}
	for _, id in ipairs({ ... }) do
		known[id] = true
	end
	return function(id)
		return known[id] == true
	end
end
local icons = Model.Icons("SHAMAN", knownSpells(8042, 403), function(id)
	return id == 403
end)
assert(#icons == 2)
assert(icons[1].id == 8042 and icons[1].reaches == false, "the shock is short")
assert(icons[2].id == 403 and icons[2].reaches == true, "the bolt reaches")
icons = Model.Icons("SHAMAN", knownSpells(403), function()
	return true
end)
assert(#icons == 1 and icons[1].id == 403, "only the spells the character knows")
assert(#Model.Icons("SHAMAN", knownSpells(8042, 403), function()
	return nil
end) == 0, "a spell the client cannot answer for is left out")
assert(#Model.Icons("MONK", knownSpells(8042), function()
	return true
end) == 0, "a class with no spells has none")

-- Size: the chosen percentage of the bar's height, clamped to the slider's bounds.
assert(Model.Size(20, 100) == 20 and Model.Size(10, 50) == 5 and Model.Size(20, 200) == 40)
assert(Model.Size(20, nil) == 20, "no setting is the bar's own height")
assert(Model.Size(20, 5) == 10 and Model.Size(20, 900) == 40, "the size stays inside the slider's bounds")

-- Wired up: every enemy plate gets its row, lit by what reaches that enemy.
db.spellReach = true
for _, fn in ipairs(initializers) do
	fn()
end
assert(#ticks == 0, "no plate, no polling")
handlers.NAME_PLATE_UNIT_ADDED("nameplate1")
assert(#ticks == 1, "the first plate starts the polling")
local row1 = created[plateFrames.nameplate1]
assert(row1.shown and row1.width == 20 * 2 + 2, "the default size is the bar height")
local shock, bolt = row1.textures[1], row1.textures[3]
assert(
	shock.texture == "icon8042" and shock.desaturated and shock.color[1] == 1 and shock.color[2] == 0.08,
	"the shock is solid red"
)
assert(
	bolt.texture == "icon403" and bolt.desaturated == false and bolt.color[1] == 1 and bolt.color[2] == 1,
	"the bolt is in full colour"
)

handlers.NAME_PLATE_UNIT_ADDED("nameplate2")
assert(#ticks == 1, "one ticker for every plate")
local row2 = created[plateFrames.nameplate2]
assert(row2.textures[1].color[1] == 1 and row2.textures[3].color[1] == 1, "both reach the second enemy")

-- Walking in: the next poll lights the shock.
reach.nameplate1[8042] = true
ticks[1]()
assert(shock.desaturated == false and shock.color[1] == 1 and shock.color[2] == 1)

-- Position: each choice anchors the row against the stock plate's own neighbour frame, so it clears the raid
-- marker, the level and the cast bar.
local function Points(region)
	local out = {}
	for _, point in ipairs(region.points) do
		out[#out + 1] = string.format("%s:%s:%s:%s:%s", point[1], point[2].name, point[3], point[4], point[5])
	end
	return out
end
assert(Points(row1)[1] == "RIGHT:raid:LEFT:-2:0", "left of the bar sits past the raid marker")
db.spellReachPosition = "right"
changes.spellReachPosition()
assert(Points(row1)[1] == "LEFT:level:RIGHT:2:0", "right of the bar sits past the level")
db.spellReachPosition = "below"
changes.spellReachPosition()
assert(Points(row1)[1] == "TOP:cast:BOTTOM:0:-2", "below the bar sits under the plate, clear of the cast bar")
db.spellReachPosition = "left"
changes.spellReachPosition()
assert(Points(row1)[1] == "RIGHT:raid:LEFT:-2:0")

-- Size: the slider reaches the drawn icon.
db.spellReachSize = 50
changes.spellReachSize()
assert(row1.width == 10 * 2 + 2 and shock.width == 10, "a smaller size redraws the row and its icons")
db.spellReachSize = 100
changes.spellReachSize()

-- Out of range look: red by default, faded dims and desaturates, hidden drops the icon.
reach.nameplate1[8042] = false
ticks[1]()
db.spellReachStyle = "faded"
changes.spellReachStyle()
assert(shock.desaturated and shock.color[1] == 0.6 and shock.alpha == 0.7 and shock.shown)
db.spellReachStyle = "hidden"
changes.spellReachStyle()
assert(not shock.shown and not row1.borders[1].shown, "hidden out of range icons are not drawn")
db.spellReachStyle = "red"
changes.spellReachStyle()
assert(shock.shown and shock.color[1] == 1 and shock.color[2] == 0.08)

-- Which plates: every enemy by default, or only the current target's.
plateFrames.target = plateFrames.nameplate1
db.spellReachTargets = "target"
changes.spellReachTargets()
assert(row1.shown and not row2.shown, "target only keeps the target's plate and drops the rest")
db.spellReachTargets = "all"
changes.spellReachTargets()
assert(row1.shown and row2.shown)
plateFrames.target = nil

-- A friendly or dead unit carries no row.
hostile.nameplate2 = false
ticks[1]()
assert(not row2.shown, "a unit the player cannot attack has no icons")
hostile.nameplate2 = true
dead.nameplate2 = true
ticks[1]()
assert(not row2.shown, "a dead unit has no icons")
dead.nameplate2 = nil
ticks[1]()
assert(row2.shown)

-- A plate handed back to the pool loses its row, and the last plate leaving stops the polling.
handlers.NAME_PLATE_UNIT_REMOVED("nameplate2")
assert(not row2.shown and cancelled == 0)
handlers.NAME_PLATE_UNIT_REMOVED("nameplate1")
assert(not row1.shown and cancelled == 1, "no plate, no polling")

-- Switched off with a plate on screen: its row goes and the polling stops.
handlers.NAME_PLATE_UNIT_ADDED("nameplate1")
assert(row1.shown and #ticks == 2)
db.spellReach = false
changes.spellReach()
assert(not row1.shown and cancelled == 2, "switched off")
db.spellReach = true
changes.spellReach()
assert(row1.shown and #ticks == 3, "and back on")

print("spellreach_spec: ok")
