local ns = {}
assert(loadfile("Data/DungeonEntrances.lua"))("TweaksForever", ns)

local shown = {}
for mapID, entries in pairs(ns.DungeonEntrances) do
	for _, entry in ipairs(entries) do
		assert(entry.x >= 0 and entry.x <= 1 and entry.y >= 0 and entry.y <= 1, mapID)
		for _, instance in ipairs(entry.instances) do
			shown[instance] = (shown[instance] or 0) + 1
		end
	end
end
for _, instance in ipairs({ 33, 36, 43, 189, 229, 249, 309, 389, 409, 469, 509, 531 }) do
	assert((shown[instance] or 0) >= 2, instance)
end
print("dungeonentrances data: ok")
