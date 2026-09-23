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
local Model = ns.Trainable
assert(features.trainableSpells.default and #initializers == 1)

local spells = {
	[1] = { name = "Purge", level = 12 },
	[2] = { name = "Flame Shock", level = 10 },
	[3] = { name = "Frost Shock", level = 20 },
	[4] = { name = "Lesser Healing Wave", level = 20 },
	[5] = { name = "Earth Shock", rank = "Rank 3", level = 14 },
	[6] = { name = "Earth Shock", rank = "Rank 2", level = 8 },
	[7] = { name = "Water Breathing", level = 22 },
}
local known = { [6] = true }
local ready, later = Model.Plan(spells, 18, function(id)
	return known[id]
end)
assert(#ready == 3, "known spells are left out")
assert(ready[1].name == "Earth Shock" and ready[2].name == "Flame Shock" and ready[3].name == "Purge")
assert(#later == 2 and later[1].level == 20 and later[2].level == 22, "later spells group by level, lowest first")
assert(later[1][1].name == "Frost Shock" and later[1][2].name == "Lesser Healing Wave")
assert(Model.Summary(ready, later) == "<3 spells> ready to train  ·  Next: level 20 (2 spells)")
assert(Model.Summary({}, { later[2] }) == "Next: level 22 (1 spell)")
assert(Model.Summary({}, {}) == "Every trainer spell learned")
assert(Model.Label(spells[5]) == "Earth Shock (Rank 3)" and Model.Label(spells[1]) == "Purge")

ready = Model.Plan(spells, 20, function()
	return false
end)
assert(#ready == 6 and ready[1].rank == "Rank 2" and ready[2].rank == "Rank 3", "ranks of one spell sort in order")
print("spellbook: ok")
