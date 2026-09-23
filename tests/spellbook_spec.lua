local features, initializers = {}, {}
local ns = {
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
}
local env = setmetatable({
	GREEN_FONT_COLOR = {
		WrapTextInColorCode = function(_, text)
			return "<" .. text .. ">"
		end,
	},
}, { __index = _G })
setfenv(assert(loadfile("Spellbook.lua")), env)("TweaksForever", ns)
local Model = ns.FutureSpells
assert(features.trainableSpells.default and #initializers == 1)

local spells = {
	[1] = { name = "Purge", level = 12, line = "Enhancement" },
	[2] = { name = "Flame Shock", level = 10, line = "Elemental Combat" },
	[3] = { name = "Frost Shock", level = 20, line = "Elemental Combat" },
	[4] = { name = "Earth Shock", rank = "Rank 3", level = 14, line = "Elemental Combat" },
	[5] = { name = "Earth Shock", rank = "Rank 2", level = 8, line = "Elemental Combat" },
	[6] = { name = "Earth Shock", rank = "Rank 4", level = 24, line = "Elemental Combat" },
	[7] = { name = "Lightning Bolt", level = 20, line = "Elemental Combat" },
	[8] = { name = "Old Save", level = 4 },
}
local known = { [5] = true }
local chosen = Model.Choose(spells, "Elemental Combat", 18, function(id)
	return known[id]
end)
local names = {}
for i, entry in ipairs(chosen) do
	names[i] = entry.spell.name .. ":" .. entry.id .. ":" .. tostring(entry.ready)
end
assert(
	table.concat(names, ",") == "Flame Shock:2:true,Earth Shock:4:true,Frost Shock:3:false,Lightning Bolt:7:false",
	"one lowest unlearned rank per spell, other tabs and unlined saves left out, trainable first: "
		.. table.concat(names, ",")
)

-- The baked trainer list, for a level 18 Dwarf Shaman who has never visited a trainer.
env.tContains = function(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end
setfenv(assert(loadfile("Data/ClassSpells.lua")), env)("TweaksForever", ns)
local DWARF, ORC = 3, 2
local NAMES = {
	[403] = "Lightning Bolt",
	[529] = "Lightning Bolt",
	[548] = "Lightning Bolt",
	[915] = "Lightning Bolt",
	[8056] = "Frost Shock",
	[8058] = "Frost Shock",
	[3599] = "Searing Totem",
	[6363] = "Searing Totem",
}
local unknownToClient = { [2645] = true } -- Ghost Wolf
local function Describe(id)
	if not unknownToClient[id] then
		return { name = NAMES[id] or tostring(id), icon = id }
	end
end
known = { [403] = true, [529] = true, [8042] = true }
local function Known(id)
	return known[id] == true
end
local shaman = Model.Spells(ns.ClassSpells.SHAMAN, nil, DWARF, Describe, Known)
local function Pick(name, list)
	for _, entry in ipairs(Model.Choose(list or shaman, "Elemental Combat", 18, Known)) do
		if entry.spell.name == name then
			return entry
		end
	end
end
local frost = Pick("Frost Shock")
assert(frost and frost.id == 8056 and not frost.ready, "Frost Shock rank 1 comes at 20")
assert(frost.spell.level == 20 and frost.spell.cost == 2200 and frost.spell.line == "Elemental Combat")
assert(Pick("Lightning Bolt").id == 548, "the rank after the known ones")
assert(Pick("Lightning Bolt").ready, "level 14 is ready at 18")
assert(not Pick("8042") and shaman[8042], "a known spell is left out")
assert(not shaman[2645], "a spell the client can't describe is left out")
assert(not shaman[6363], "Searing Totem rank 2 waits for the quest's rank 1")
known[3599] = true
assert(Model.Spells(ns.ClassSpells.SHAMAN, nil, DWARF, Describe, Known)[6363], "and shows once it is known")
local live = { [8056] = { name = "Frost Shock", level = 20, cost = 2000, icon = 1, line = "Elemental Combat" } }
frost = Pick("Frost Shock", Model.Spells(ns.ClassSpells.SHAMAN, live, DWARF, Describe, Known))
assert(frost.spell.cost == 2000, "a trainer visit's own fee wins")
local mage = ns.ClassSpells.MAGE
assert(Model.Spells(mage, nil, DWARF, Describe, Known)[3561], "Teleport: Stormwind for a Dwarf")
assert(not Model.Spells(mage, nil, ORC, Describe, Known)[3561], "but not for an Orc")
for token, class in pairs(ns.ClassSpells) do
	assert(#class.spells > 50, token .. " has a full list")
	for _, row in ipairs(class.spells) do
		assert(class.lines[row[4]] and row[2] >= 1 and row[3] >= 0, token .. " " .. row[1])
	end
end

-- Blizzard's grid: two 680x590 views, three 220-wide columns, 60-tall items with 10 padding, 51-tall headers.
local grid =
	{ views = 2, width = 680, height = 590, columns = 3, gap = 15, pad = 10, spacer = 20, header = 51, item = 60 }
local header, slots = Model.Layout(4, 1, 140, grid)
assert(header.page == 0 and header.view == 1 and header.y == 170, "a spacer separates us from the spellbook's group")
assert(#slots == 4 and slots[1].y == 231 and slots[2].y == 301, "rows fill down a column first")
assert(slots[3].x == 650 / 3 + 15 and slots[3].y == 231 and slots[4].x == slots[3].x, "rows balance over the columns")

header, slots = Model.Layout(1, 1, 500, grid)
assert(header.page == 0 and header.view == 2 and header.y == 0, "a header without room for a row moves on")
assert(slots[1].view == 2 and slots[1].y == 61)

header, slots = Model.Layout(30, 2, 400, grid)
assert(header.view == 2 and header.page == 0)
local last = slots[#slots]
assert(#slots == 30 and last.page == 1, "overflow continues onto our own pages")
for _, slot in ipairs(slots) do
	assert(slot.y + grid.item <= grid.height, "every entry fits on its view")
end
print("spellbook: ok")
