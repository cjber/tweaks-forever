local features, initializers = {}, {}
local ns = {
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
}
assert(loadfile("Gear.lua"))("TweaksForever", ns)
local Model = ns.Gear
assert(features.beforeFishing.parent == "gearGroups")

-- Groups: toggling the last item out removes the group, so the menu never lists empty ones.
local groups = {}
assert(Model.Toggle(groups, "Healing", 10))
assert(Model.Toggle(groups, "Healing", 11))
assert(not Model.Toggle(groups, "Healing", 10) and groups.Healing[11])
assert(not Model.Toggle(groups, "Healing", 11) and groups.Healing == nil)

-- Every list an item is in, sorted by name, each knowing where it came from.
local found = Model.GroupsOf(5, {
	group = { DPS = { [5] = true }, Tank = { [6] = true } },
	set = { Arena = { [5] = true }, DPS = { [5] = true } },
	fishing = {},
})
local listed = {}
for index, mark in ipairs(found) do
	listed[index] = mark.kind .. ":" .. mark.name
end
assert(table.concat(listed, " ") == "set:Arena group:DPS set:DPS", table.concat(listed, " "))

-- Colours: each new list takes a palette colour nobody has, a freed one is reused, and a stored one sticks.
local colours = {}
local first = Model.Colour(colours, "group", "DPS")
local second = Model.Colour(colours, "set", "Arena")
assert(first ~= second and table.concat(first, ",") ~= table.concat(second, ","))
assert(Model.Colour(colours, "group", "DPS") == first)
local firstValue = table.concat(first, ",")
colours.group.DPS = nil
assert(table.concat(Model.Colour(colours, "fishing", "Before fishing"), ",") == firstValue)

-- A colour from the retired palette moves to the current one at the same place; a hand-picked one stays.
colours = { group = { Old = { 1, 0.55, 0.15 }, Picked = { 0.12, 0.34, 0.56 } } }
Model.Recolour(colours)
assert(table.concat(colours.group.Old, ",") == "0.45,1,0.86", table.concat(colours.group.Old, ","))
assert(table.concat(colours.group.Picked, ",") == "0.12,0.34,0.56")

-- Slots: the second ring and the second one-hander take the second slot; a spare has nowhere to go.
local types = {
	[1] = "INVTYPE_FINGER",
	[2] = "INVTYPE_FINGER",
	[3] = "INVTYPE_FINGER",
	[4] = "INVTYPE_WEAPON",
	[5] = "INVTYPE_WEAPON",
	[6] = "INVTYPE_HEAD",
}
local plan = Model.Plan({ 4, 1, 2, 3, 5, 6 }, function(item)
	return types[item]
end)
local slots = {}
for _, step in ipairs(plan) do
	slots[#slots + 1] = step.item .. "@" .. step.slot
end
assert(table.concat(slots, " ") == "6@1 1@11 2@12 4@16 5@17", table.concat(slots, " "))

types[7] = "INVTYPE_WEAPONMAINHAND"
plan = Model.Plan({ 4, 7 }, function(item)
	return types[item]
end)
assert(plan[1].item == 7 and plan[1].slot == 16 and plan[2].item == 4 and plan[2].slot == 17)
-- A two-hander leaves no room for a shield, whichever is listed first.
types[8], types[9] = "INVTYPE_2HWEAPON", "INVTYPE_SHIELD"
plan = Model.Plan({ 9, 8 }, function(item)
	return types[item]
end)
assert(#plan == 1 and plan[1].item == 8 and plan[1].slot == 16)
print("gear: ok")
