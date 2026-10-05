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
ns.L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})

-- The client reads the module makes, stubbed: a hunter's book, what reaches each unit, the 5 yard melee item,
-- and frames that record what is drawn on them.
local book = { { actionID = 2973 }, { actionID = 75 }, { actionID = 116 }, { actionID = 78 }, { actionID = 403 } }
-- What the spell range check answers; a melee ability (2973) answers nil, which is the bug.
local range = { nameplate1 = { [75] = true, [116] = true }, nameplate2 = { [75] = true, [116] = true } }
local MELEE_IDS = { [2973] = true, [78] = true }
-- What the 5 yard item check answers. IsSpellInRange never can.
local melee = { nameplate1 = false, nameplate2 = true }
local RANGE = { [2973] = 5, [75] = 35, [116] = 30, [78] = 5, [403] = 30, [8042] = 20, [585] = 30 }
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
	function region.SetVertexColorFromBoolean(self, value, onTrue, onFalse)
		self.colorFromBoolean = { value = value, onTrue = onTrue, onFalse = onFalse }
	end
	function region.SetDesaturated(self, desaturated)
		self.desaturated = desaturated
	end
	function region.SetAlpha(self, alpha)
		self.alpha = alpha
	end
	function region.SetAlphaFromBoolean(self, value, alphaIfTrue, alphaIfFalse)
		self.alphaFromBoolean = { value = value, alphaIfTrue = alphaIfTrue, alphaIfFalse = alphaIfFalse }
	end
	function region.SetColorTexture(self, red, green, blue, alpha)
		self.colorTexture = { red, green, blue, alpha }
	end
	function region.SetAllPoints() end
	function region.SetFrameLevel() end
	function region.GetFrameLevel()
		return 1
	end
	function region.SetJustifyH() end
	function region.SetFontObject() end
	function region.SetText(self, text)
		self.text = text
	end
	function region.GetText(self)
		return self.text
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
		self.textures = self.textures or {}
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

-- One frame or texture the module builds, recording its kind, template, scripts and children.
local function Frame(kind, name, _, template)
	local frame = Region()
	frame.kind, frame.name, frame.template, frame.scripts = kind, name, template, {}
	if kind == "CheckButton" then
		frame.Text = Region()
		frame.enabled = true
		function frame.SetChecked(self, checked)
			self.checked = checked
		end
		function frame.GetChecked(self)
			return self.checked
		end
		function frame.SetEnabled(self, enabled)
			self.enabled = enabled
		end
		function frame.SetText(self, text)
			self.Text:SetText(text)
		end
	end
	function frame.SetScript(self, event, callback)
		self.scripts[event] = callback
	end
	function frame.SetScrollChild(self, child)
		self.child = child
	end
	function frame.SetFrameStrata() end
	function frame.SetClampedToScreen() end
	function frame.EnableKeyboard() end
	function frame.SetPropagateKeyboardInput() end
	function frame.CreateFontString(_, _, _, font)
		local string = Region()
		string.font = font
		return string
	end
	if template == "BasicFrameTemplateWithInset" then
		frame.TitleText = Region()
		frame.CloseButton = Region()
	end
	return frame
end

local created = {}
local char = {}
local plateFrames = { nameplate1 = Plate(), nameplate2 = Plate() }
local ticks, cancelled = {}, 0

local env = setmetatable({
	Enum = { SpellBookSpellBank = { Player = 0 } },
	UIParent = {},
	TweaksForeverCharDB = char,
	UnitClass = function()
		return "Hunter", "HUNTER"
	end,
	UnitCanAttack = function(_, unit)
		return hostile[unit] == true
	end,
	UnitIsDeadOrGhost = function(unit)
		return dead[unit] == true
	end,
	canaccessvalue = function(value)
		return value ~= "secret"
	end,
	CreateColor = function(red, green, blue)
		return { red, green, blue }
	end,
	CreateFrame = function(kind, name, parent, template)
		local frame = Frame(kind, name, parent, template)
		created[parent] = created[parent] or frame
		return frame
	end,
	C_SpecializationInfo = {
		GetActiveSpecGroup = function()
			return 1
		end,
	},
	GetShapeshiftForm = function()
		return 0
	end,
	C_Spell = {
		IsSpellInRange = function(id, unit)
			if MELEE_IDS[id] then
				return nil
			end
			return range[unit][id]
		end,
		IsSpellHarmful = function()
			return true
		end,
		GetSpellInfo = function(id)
			return { name = "Spell" .. id, iconID = 1000 + id, maxRange = RANGE[id], minRange = 0 }
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
	C_Item = {
		GetItemInfo = function(id)
			return id == 8149 and "Voodoo Charm" or nil
		end,
		RequestLoadItemDataByID = function() end,
		IsItemInRange = function(_, unit)
			return melee[unit]
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

-- Features: the switch, its sub-options and defaults. The icon sits to the right of the bar until the player
-- moves it, and only the target's plate carries it only when the player asks.
assert(features.spellReach.default == false)
assert(features.spellReach.category == "Interface")
assert(not features.spellReach.parent)
assert(features.spellReach.conflicts[1].addon == "RangeLens")
assert(type(features.spellReach.button) == "function", "the settings offer a spell picker")
assert(features.spellReachPosition.parent == "spellReach" and features.spellReachPosition.default == "right")
assert(features.spellReachPosition.options[1][1] == "left" and features.spellReachPosition.options[3][1] == "below")
assert(features.spellReachSize.parent == "spellReach" and features.spellReachSize.default == 100)
assert(features.spellReachSize.slider.min == 50 and features.spellReachSize.slider.max == 200)
assert(features.spellReachStyle.default == "red" and features.spellReachStyle.options[3][1] == "hidden")
assert(features.spellReachTargets.parent == "spellReach")
assert(features.spellReachTargets.default == false, "only on my target is off by default")
assert(not features.spellReachTargets.options, "a plain toggle, not a second which-plates choice")

-- Context: the active specialisation and stance or form, so each remembers its own spells.
assert(Model.Context(1, 0) == "1:0")
assert(Model.Context(nil, nil) == "0:0")
assert(Model.Context(2, 3) == "2:3")

-- Melee: a Combat Range of 5 yards or less, not a longer ranged one.
assert(Model.Melee(5) and Model.Melee(1))
assert(not Model.Melee(10) and not Model.Melee(30) and not Model.Melee(0) and not Model.Melee(nil))

-- Tracked: the player's own picks for this context, only the spells still known, else the class's defaults.
local function knownSpells(...)
	local known = {}
	for _, id in ipairs({ ... }) do
		known[id] = true
	end
	return function(id)
		return known[id] == true
	end
end
local hunter = knownSpells(2973, 75, 116)
assert(#Model.Default("HUNTER", hunter) == 2, "the hunter's Raptor Strike and Auto Shot")
assert(Model.Default("HUNTER", knownSpells(75))[1] == 75, "only the spells the character knows")
assert(#Model.Default("MONK", hunter) == 0, "a class with no attacks has none")
local saved = { ["1:0"] = { 116, 2973 } }
local tracked = Model.Tracked("HUNTER", saved, "1:0", hunter)
assert(#tracked == 2 and tracked[1] == 116 and tracked[2] == 2973, "the picks win")
saved["1:0"] = { 116, 585 }
assert(#Model.Tracked("HUNTER", saved, "1:0", hunter) == 1, "a pick the character no longer knows is dropped")
assert(#Model.Tracked("HUNTER", {}, "1:0", hunter) == 2, "no picks for this context leaves the default")
assert(#Model.Tracked("HUNTER", { ["1:0"] = {} }, "1:0", hunter) == 0, "an empty pick list means none")
local picks = {}
Model.Toggle(picks, 116)
Model.Toggle(picks, 2973)
assert(#picks == 2 and picks[1] == 116 and picks[2] == 2973)
Model.Toggle(picks, 116)
assert(#picks == 1 and picks[1] == 2973, "toggling again takes it out")

-- Choices: the character's harmful spells with a range, melee included, by name.
local facts = {
	[2973] = { name = "Raptor Strike", icon = 1, range = 5, harmful = true },
	[75] = { name = "Auto Shot", icon = 2, range = 35, harmful = true },
	[116] = { name = "Frostbolt", icon = 3, range = 30, harmful = true },
	[585] = { name = "Smite", icon = 4, range = 30, harmful = false },
	[78] = { name = "Heroic Strike", icon = 5, range = 5, harmful = true },
}
local choices = Model.Choices({ 2973, 75, 116, 585, 78 }, function(id)
	return facts[id]
end)
assert(#choices == 4, "a friendly spell is left out")
assert(
	choices[1].name == "Auto Shot"
		and choices[2].name == "Frostbolt"
		and choices[3].name == "Heroic Strike"
		and choices[4].name == "Raptor Strike",
	"by name"
)

-- Icons: each spell the character knows, each with whether it reaches. A nil answer is left out, a secret one
-- is kept for the engine to read.
assert(#Model.Icons({ 2973, 75 }, hunter, function(id)
	return id == 75
end) == 2)
assert(#Model.Icons({ 2973 }, hunter, function()
	return nil
end) == 0, "a spell the client cannot answer for is left out")
local secret = Model.Icons({ 2973 }, hunter, function()
	return "secret"
end)
assert(#secret == 1 and secret[1].reaches == "secret", "a secret answer is kept")

-- Size: the chosen percentage of the bar's height, clamped to the slider's bounds.
assert(Model.Size(20, 100) == 20 and Model.Size(10, 50) == 5 and Model.Size(20, 200) == 40)
assert(Model.Size(20, nil) == 20, "no setting is the bar's own height")
assert(Model.Size(20, 5) == 10 and Model.Size(20, 900) == 40, "the size stays inside the slider's bounds")

-- Wired up: every enemy plate gets its row, lit by what reaches that enemy. The melee ability answers through
-- the 5 yard item check, which the spell range check cannot.
db.spellReach = true
for _, fn in ipairs(initializers) do
	fn()
end
assert(#ticks == 0, "no plate, no polling")
handlers.NAME_PLATE_UNIT_ADDED("nameplate1")
assert(#ticks == 1, "the first plate starts the polling")
local row1 = created[plateFrames.nameplate1]
local pad = 20 * 2 / 36
local gap, offset = 2 + 2 * pad, 2 + pad
assert(row1.shown and row1.width == 20 * 2 + gap, "the default size is the bar height")
assert(row1.textures[2].width == 20 * 64 / 36, "the frame is square, at the stock button's ratio")
local meleeIcon, bolt = row1.textures[1], row1.textures[3]
assert(meleeIcon.texture == "icon2973" and bolt.texture == "icon75", "both tracked spells are drawn")
assert(
	meleeIcon.desaturated and meleeIcon.color[1] == 1 and meleeIcon.color[2] == 0.08,
	"a melee ability out of reach is red, answered by the item check"
)
assert(bolt.desaturated == false and bolt.color[1] == 1, "the shot reaches, so it stays in colour")

-- Walking into melee reach: the item check says yes and the melee icon lights, where its own range check
-- answered nil and nothing could ever light it.
melee.nameplate1 = true
ticks[1]()
assert(
	meleeIcon.desaturated == false and meleeIcon.color[2] == 1,
	"the melee ability lights up on the item check, not the nil spell range check"
)
melee.nameplate1 = false
ticks[1]()

-- The ranged spell's own range check still answers, so it reddens out of range on its own.
range.nameplate1[75] = false
ticks[1]()
assert(bolt.desaturated and bolt.color[2] == 0.08, "a ranged spell out of range is red")
range.nameplate1[75] = true
ticks[1]()
assert(bolt.desaturated == false and bolt.color[1] == 1)

handlers.NAME_PLATE_UNIT_ADDED("nameplate2")
assert(#ticks == 1, "one ticker for every plate")
local row2 = created[plateFrames.nameplate2]
assert(row2.textures[1].color[2] == 1 and row2.textures[3].color[1] == 1, "both reach the second enemy")

-- A secret range answer cannot be read: the engine's own setters take it.
range.nameplate1[75] = "secret"
ticks[1]()
assert(
	bolt.alphaFromBoolean and bolt.alphaFromBoolean.value == "secret" and bolt.colorFromBoolean.value == "secret",
	"a secret answer goes to the engine"
)
db.spellReachStyle = "hidden"
changes.spellReachStyle()
row1.borders[2].alpha = 0 -- the engine resolved the secret answer as out of range
range.nameplate1[75] = true
ticks[1]()
assert(row1.borders[2].shown and row1.borders[2].alpha == 1, "the frame returns with a readable range answer")
db.spellReachStyle = "red"
changes.spellReachStyle()
range.nameplate1[75] = false
ticks[1]()

-- Position: each choice anchors the row against the stock plate's own neighbour frame, so it clears the raid
-- marker, the level and the cast bar. The icon sits on the right of the bar by default.
local function Points(region)
	local out = {}
	for _, point in ipairs(region.points) do
		out[#out + 1] = string.format("%s:%s:%s:%s:%s", point[1], point[2].name, point[3], point[4], point[5])
	end
	return out
end
assert(Points(row1)[1] == string.format("LEFT:level:RIGHT:%s:0", offset), "right of the bar is the default")
db.spellReachPosition = "left"
changes.spellReachPosition()
assert(Points(row1)[1] == string.format("RIGHT:raid:LEFT:%s:0", -offset), "left of the bar sits past the raid marker")
db.spellReachPosition = "below"
changes.spellReachPosition()
assert(
	Points(row1)[1] == string.format("TOP:cast:BOTTOM:0:%s", -offset),
	"below the bar sits under the plate, clear of the cast bar"
)
db.spellReachPosition = "right"
changes.spellReachPosition()

-- Size: the slider reaches the drawn icon.
db.spellReachSize = 50
changes.spellReachSize()
assert(
	row1.width == 10 * 2 + (2 + 2 * 10 * 2 / 36) and meleeIcon.width == 10,
	"a smaller size redraws the row and its icons"
)
db.spellReachSize = 100
changes.spellReachSize()

-- Out of range look: red by default, faded dims and desaturates, hidden drops the icon.
melee.nameplate1 = false
ticks[1]()
db.spellReachStyle = "faded"
changes.spellReachStyle()
assert(meleeIcon.desaturated and meleeIcon.color[1] == 0.6 and meleeIcon.alpha == 0.7 and meleeIcon.shown)
db.spellReachStyle = "hidden"
changes.spellReachStyle()
assert(not meleeIcon.shown and not row1.borders[1].shown, "hidden out of range icons are not drawn")
db.spellReachStyle = "red"
changes.spellReachStyle()
assert(meleeIcon.shown and meleeIcon.color[1] == 1 and meleeIcon.color[2] == 0.08)

-- Only on my target: off shows every enemy, on keeps the target's plate and drops the rest.
plateFrames.target = plateFrames.nameplate1
db.spellReachTargets = true
changes.spellReachTargets()
assert(row1.shown and not row2.shown, "target only keeps the target's plate and drops the rest")
db.spellReachTargets = false
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

-- The picker: the character's spells with a checkbox, icon and name, the class's attacks ticked, and a pick
-- remembered per specialisation, stance or form.
local picker = features.spellReach.button()
assert(picker.TitleText.text == "Spells to track")
local pickerRows = picker.Rows
assert(#pickerRows == 5, "the book's harmful spells with a range")
local bySpell = {}
for _, pickerRow in ipairs(pickerRows) do
	bySpell[pickerRow.spell] = pickerRow
end
assert(bySpell[2973] and bySpell[2973].Text.text == "Spell2973" and bySpell[2973].Icon.texture == 1000 + 2973)
assert(bySpell[2973].checked and bySpell[75].checked, "the hunter's defaults start ticked")
assert(not bySpell[116].checked)
bySpell[116].scripts.OnClick(bySpell[116])
assert(#char.spellReach["1:0"] == 3, "a pick is remembered for this specialisation, stance or form")
assert(bySpell[116].checked, "the picked spell shows ticked")
bySpell[78].scripts.OnClick(bySpell[78])
assert(#char.spellReach["1:0"] == 4)
assert(not bySpell[403].enabled, "a full row stops taking more spells")
bySpell[116].scripts.OnClick(bySpell[116])
assert(#char.spellReach["1:0"] == 3 and not bySpell[116].checked, "and unticking takes it back out")

print("spellreach_spec: ok")
