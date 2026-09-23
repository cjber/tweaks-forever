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
