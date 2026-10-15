-- A player's tooltip lines: the level line is found by the race and the unit's own level, so a guild named after a
-- race is bracketed as a guild and never takes the class. The tooltip's frames are stubbed loosely: anything not
-- under test answers with another stub.
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

local features, initializers = {}, {}
local ns = {
	db = { tooltipStyle = "modern" },
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
	Active = function()
		return true
	end,
	OnTooltip = function() end,
	OnSettingChanged = function() end,
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

local pre, linePre, post = {}, {}, {}
local levels = { mouseover = 60, target = -1 }
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
		return "Warrior", "WARRIOR", "Night Elf", "NightElf", 2, "Sellene", ""
	end,
	UnitExists = function(unit)
		return levels[unit] ~= nil
	end,
	UnitLevel = function(unit)
		return levels[unit]
	end,
	canaccessvalue = function()
		return true
	end,
	C_ClassColor = {
		GetClassColor = function()
			return { r = 0.78, g = 0.61, b = 0.43 }
		end,
	},
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

-- A forbidden tooltip, or a player whose GUID is secret, is left exactly as the client wrote it.
forbidden = true
built = Build("GetWorldCursor", nil, { "Sellene", "Level 60 Night Elf (Player)", "Warrior", "Alliance" })
assert(#built == 4 and built[2].text == "Level 60 Night Elf (Player)", "a forbidden tooltip is not touched")
forbidden = false
local canaccessvalue = env.canaccessvalue
env.canaccessvalue = function()
	return false
end
built = Build("GetWorldCursor", nil, { "Sellene", "Level 60 Night Elf (Player)", "Warrior", "Alliance" })
assert(#built == 4 and built[2].text == "Level 60 Night Elf (Player)", "a secret GUID leaves the lines alone")
env.canaccessvalue = canaccessvalue

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
