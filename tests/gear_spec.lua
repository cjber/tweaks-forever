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

-- Every list an item is in, sorted, across our groups, Equipment Manager sets and Before fishing.
local names = Model.GroupsOf(5, { DPS = { [5] = true }, Tank = { [6] = true } }, { Arena = { [5] = true } }, {})
assert(#names == 2 and names[1] == "Arena" and names[2] == "DPS")

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
print("gear: ok")
