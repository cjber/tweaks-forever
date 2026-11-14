-- A player's tooltip lines: the level line is found by the race and the unit's own level, so a guild named after a
-- race is bracketed as a guild and never takes the class. The health bar takes the unit's colour unless the client
-- keeps it secret. The tooltip's frames are stubbed loosely: anything not under test answers with another stub.
local function Stub()
	return setmetatable({}, {
		__index = function(self, key)
			local value = Stub()
			rawset(self, key, value)
			return value
		end,
		__call = function()
			return Stub()
		end,
	})
end

local features, initializers, handlers, onUnit = {}, {}, {}, nil
local active = true
local ns = {
	db = { tooltipStyle = "modern" },
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
	Active = function()
		return active
	end,
	OnTooltip = function(_, _, fn)
		onUnit = fn
	end,
	OnSettingChanged = function(key, fn)
		handlers[key] = fn
	end,
}

-- GameTooltip's left lines, as Blizzard wrote them.
local function Line(text)
	local line = { text = text }
	function line.GetText(self)
		return self.text
	end
	function line.SetText(self, value)
		self.text = value
	end
	function line.SetTextColor(self, r, g, b)
		self.color = { r, g, b }
	end
	return line
end

local lines = {}
local processing
-- A tooltip with no comparison header, which the player lines never touch.
local function Tooltip()
	local tooltip = Stub()
	tooltip.CompareHeader = false
	return tooltip
end
local GameTooltip = Tooltip()
GameTooltip.StatusBar = Stub()
-- The health bar's hooks, art and height, and the tooltip's minimum width and padding, to check the bar keeps its
-- room and its art's own height.
local barShown, barHooks, minWidth = true, {}, nil
local barHeight, fill, padding
local track = {}
local bar = GameTooltip.StatusBar
function bar.IsShown()
	return barShown
end
function bar.HookScript(_, event, fn)
	barHooks[event] = fn
end
function bar.SetHeight(_, height)
	barHeight = height
end
function bar.SetStatusBarTexture(_, texture)
	fill = texture
end
function bar.CreateTexture()
	return track
end
function track.SetAtlas(_, atlas)
	track.atlas = atlas
end
function track.SetAllPoints() end
function track.SetShown(_, shown)
	track.shown = shown
end
function track.SetVertexColor(_, r, g, b)
	track.color = { r, g, b }
end
function GameTooltip.SetMinimumWidth(_, width)
	minWidth = width
end
function GameTooltip.SetPadding(_, right, bottom, left, top)
	padding = { right, bottom, left, top }
end
-- The health bar's own colour, as last set.
local barColor
function bar.SetStatusBarColor(_, r, g, b)
	barColor = { r, g, b }
end
GameTooltip.NineSlice = Stub()
function GameTooltip.GetProcessingTooltipInfo()
	return processing
end
local forbidden = false
function GameTooltip.IsForbidden()
	return forbidden
end
function GameTooltip.NumLines()
	return #lines
end
function GameTooltip.GetPadding()
	return 0, 0, 0, 0
end

-- A secret string as the client hands it to tainted code: type() calls it a string and it may be passed along, but
-- indexing it (text:find) or concatenating it raises.
local secrets = setmetatable({}, { __mode = "k" })
local function SecretString()
	local function Raise()
		error("attempt to use a secret string value", 2)
	end
	local value = setmetatable({}, { __index = Raise, __concat = Raise, __len = Raise, __call = Raise })
	secrets[value] = true
	return value
end

local pre, linePre, post = {}, {}, {}
local levels = { mouseover = 60, target = -1 }
local playerInfo = { "Warrior", "WARRIOR", "Night Elf", "NightElf", 2, "Sellene", "" }
local isPlayer, classColor = true, { r = 0.78, g = 0.61, b = 0.43 }
local reactionColors = { [2] = { r = 1, g = 0, b = 0 } }
local env = setmetatable({
	GameTooltip = GameTooltip,
	ItemRefTooltip = Tooltip(),
	ShoppingTooltip1 = Tooltip(),
	ShoppingTooltip2 = Tooltip(),
	ItemRefShoppingTooltip1 = Tooltip(),
	ItemRefShoppingTooltip2 = Tooltip(),
	Enum = { TooltipDataType = { Unit = 2 } },
	TooltipDataProcessor = {
		AllTypes = "all",
		AddTooltipPreCall = function(_, fn)
			pre[#pre + 1] = fn
		end,
		AddLinePreCall = function(_, fn)
			linePre[#linePre + 1] = fn
		end,
		AddTooltipPostCall = function(_, fn)
			post[#post + 1] = fn
		end,
	},
	hooksecurefunc = function() end,
	GetPlayerInfoByGUID = function()
		return unpack(playerInfo)
	end,
	type = function(value)
		return secrets[value] and "string" or type(value)
	end,
	UnitExists = function(unit)
		return levels[unit] ~= nil
	end,
	UnitLevel = function(unit)
		return levels[unit]
	end,
	canaccessvalue = function(value)
		return value ~= "secret" and not secrets[value]
	end,
	C_ClassColor = {
		GetClassColor = function()
			return classColor
		end,
	},
	UnitIsPlayer = function()
		return isPlayer
	end,
	UnitClass = function()
		return "Warrior", "WARRIOR", 1
	end,
	UnitReaction = function()
		return 2
	end,
	FACTION_BAR_COLORS = reactionColors,
	UnitHealth = function()
		return 1200
	end,
	UnitHealthMax = function()
		return 1500
	end,
	UnitHealthPercent = function()
		return 80
	end,
	BreakUpLargeNumbers = tostring,
	CurveConstants = { ScaleTo100 = 1 },
	FACTION_ALLIANCE = "Alliance",
	FACTION_HORDE = "Horde",
	PLAYER_FACTION_COLORS = { [0] = { r = 1, g = 0, b = 0 }, [1] = { r = 0, g = 0, b = 1 } },
}, { __index = _G })
env._G = env
setfenv(assert(loadfile("Core/Secret.lua")), env)("TweaksForever", ns)
setfenv(assert(loadfile("UI/Tooltips.lua")), env)("TweaksForever", ns)
local Model = ns.Tooltips
assert(features.retailTooltips.default == true)

-- The matcher on its own.
assert(Model.IsLevelLine("Level 60 Night Elf Warrior (Player)", "Night Elf", "60"))
assert(not Model.IsLevelLine("Night Elf Lovers", "Night Elf", "60"), "a guild named after a race is not the level")
assert(not Model.IsLevelLine("Night Elf 600", "Night Elf", "60"), "the level is a word of its own")
assert(Model.IsLevelLine("Level ?? Night Elf (Player)", "Night Elf", "??"))
assert(Model.IsLevelLine("Level 60 Night Elf", "Night Elf", nil), "with no level the race alone decides")
assert(not Model.IsLevelLine("Level 60 Human", "Night Elf", "60"))

for _, fn in ipairs(initializers) do
	fn()
end
assert(#pre == 1 and #linePre == 1 and #post == 1, "the player lines hook the tooltip data processor")

-- The health bar is the game's cooldown bar at its own 10 units tall: the fill in the bar's colour, the track the
-- same art at TRACK_SHADE, and room under the tooltip's last line for both.
assert(barHeight == 10, "the health bar is 10 tall: " .. tostring(barHeight))
assert(fill == "UI-HUD-CoolDownManager-Bar", "the health bar is filled with the cooldown bar: " .. tostring(fill))
assert(track.atlas == "UI-HUD-CoolDownManager-Bar", "the track is the cooldown bar: " .. tostring(track.atlas))
assert(
	track.color[1] == 0 and track.color[2] == 0.6 * 0.3 and track.color[3] == 0.1 * 0.3,
	"the track is the bar's colour at TRACK_SHADE"
)
assert(padding and padding[2] == 21, "the tooltip makes room for the bar: " .. tostring(padding and padding[2]))
print("tooltips: the health bar is the cooldown bar at its own height: ok")

-- Forever's style keeps Blizzard's placement under the tooltip, the same art and the same 10 units tall.
active = false
handlers.retailTooltips()
assert(barHeight == 10 and fill == "UI-HUD-CoolDownManager-Bar", "the game's own style keeps the height and art")
active = true
handlers.retailTooltips()

-- Build one tooltip: the pre-call, then each line through the line pre-call (true drops it), then the post-call.
local function Build(getter, args, texts)
	local data = { guid = "Player-1" }
	processing = { getterName = getter, getterArgs = args, tooltipData = data }
	lines = {}
	pre[1](GameTooltip, data)
	for index, text in ipairs(texts) do
		if index == 1 or not linePre[1](GameTooltip, { leftText = text }) then
			lines[#lines + 1] = Line(text)
		end
	end
	for index, line in ipairs(lines) do
		env["GameTooltipTextLeft" .. index] = line
	end
	post[1](GameTooltip, data)
	return lines
end

-- A guild whose name holds the race: bracketed as the guild, and the class joins the real level line.
local built = Build("GetWorldCursor", nil, {
	"Sellene",
	"Night Elf Lovers",
	"Level 60 Night Elf (Player)",
	"Warrior",
	"Alliance",
})
assert(#built == 4, "the class line is dropped")
assert(built[2].text == "<Night Elf Lovers>", "the guild named after a race is the guild: " .. built[2].text)
assert(built[3].text == "Level 60 Night Elf Warrior (Player)", built[3].text)
assert(built[4].color and built[4].color[3] == 1, "the faction takes its colour")

-- A forbidden tooltip is left exactly as the client wrote it.
forbidden = true
built = Build("GetWorldCursor", nil, { "Sellene", "Level 60 Night Elf (Player)", "Warrior", "Alliance" })
assert(#built == 4 and built[2].text == "Level 60 Night Elf (Player)", "a forbidden tooltip is not touched")
forbidden = false

-- A unit far above you shows ??, and its level is read from the token the tooltip was given.
built = Build("GetUnit", { "target", n = 1 }, {
	"Sellene",
	"Level ?? Night Elf (Player)",
	"Warrior",
	"Alliance",
})
assert(#built == 3 and built[2].text == "Level ?? Night Elf Warrior (Player)", built[2].text)

-- No readable unit: the race alone finds the level line, as before.
built = Build("GetHyperlink", { "unit:Player-1", n = 1 }, {
	"Sellene",
	"Level 42 Night Elf (Player)",
	"Warrior",
})
assert(built[2].text == "Level 42 Night Elf Warrior (Player)", built[2].text)
print("tooltips: the level line is found by race and level, never in a guild name: ok")

-- A player whose identity is restricted: GetPlayerInfoByGUID hands back a secret class and race, and the lines are
-- secret too. The tooltip is left exactly as Blizzard wrote it, and none of it is read.
local secretLevel = SecretString()
playerInfo = { SecretString(), SecretString(), SecretString(), SecretString(), 2, SecretString(), "" }
built = Build("GetWorldCursor", nil, { "Sellene", secretLevel, "Warrior", "Alliance" })
assert(#built == 4 and built[2].text == secretLevel and built[3].text == "Warrior", "a secret player keeps every line")
assert(not built[1].color, "a secret player's name keeps Blizzard's colour")

-- A readable player with a secret line: that line is neither the level line nor the class line, and the post-call
-- reads nothing past it.
playerInfo = { "Warrior", "WARRIOR", "Night Elf", "NightElf", 2, "Sellene", "" }
built = Build("GetWorldCursor", nil, { "Sellene", SecretString(), "Warrior", "Alliance" })
assert(#built == 4 and built[3].text == "Warrior", "a secret line never lets the class line go")
assert(not built[4].color, "nothing past a secret line is read")
print("tooltips: a secret player or line is left as Blizzard wrote it: ok")

-- A short name like "Deer" never squeezes the health bar: the tooltip keeps Blizzard's status bar width while the
-- bar shows, and lets it go once the bar hides.
barShown = true
barHooks.OnShow()
assert(minWidth == 140, "the bar widens the tooltip: " .. tostring(minWidth))
barShown = false
barHooks.OnHide()
assert(minWidth == 0, "the width is released with the bar")
minWidth = nil
barHooks.OnHide()
assert(minWidth == nil, "a width this file did not set is left alone")
print("tooltips: the health bar keeps a minimum width: ok")

-- The health bar of the unit under the cursor: its colour on the bar, and the track a shade of it.
local function BarColor(r, g, b)
	onUnit(GameTooltip, "GetWorldCursor")
	return barColor[1] == r
		and barColor[2] == g
		and barColor[3] == b
		and track.color[1] == r * 0.3
		and track.color[2] == g * 0.3
		and track.color[3] == b * 0.3
end
assert(BarColor(0.78, 0.61, 0.43), "a player's bar takes the class colour")
isPlayer = false
assert(BarColor(1, 0, 0), "another unit's bar takes its reaction's colour")

-- A colour the client keeps secret, whole or in part, leaves the bar the object's colour: its shade would be arithmetic
-- on a secret, and the bar is Blizzard's, so it must never be handed one. UnitClass is secret for a player whose
-- identity is restricted, and GetClassColor takes that secret from addon code, so its colour comes back secret.
reactionColors[2] = { r = 1, g = 0, b = "secret" }
assert(BarColor(0, 0.6, 0.1), "a reaction colour with a secret channel is not used")
isPlayer, classColor = true, { r = "secret", g = "secret", b = "secret" }
assert(BarColor(0, 0.6, 0.1), "a secret class colour is not used")
print("tooltips: a secret bar colour is never used: ok")
