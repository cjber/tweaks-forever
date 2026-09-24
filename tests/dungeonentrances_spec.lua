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
	GetRealZoneText = function(instance)
		return "instance " .. instance
	end,
	C_Map = {
		GetAreaInfo = function(area)
			return "area " .. area
		end,
	},
	CreateAtlasMarkup = function(atlas)
		return "|A:" .. atlas .. "|a"
	end,
	tInvert = function(list)
		local inverted = {}
		for i, value in ipairs(list) do
			inverted[value] = i
		end
		return inverted
	end,
}, { __index = _G })
assert(loadfile("Data/DungeonEntrances.lua"))("TweaksForever", ns)
setfenv(assert(loadfile("DungeonEntrances.lua")), env)("TweaksForever", ns)
local Model = ns.Entrances
assert(#initializers == 1 and features.dungeonEntrances.default == true)

-- Leatrix Maps draws entrances with its points of interest unless that option is explicitly off.
local leatrix = features.dungeonEntrances.conflicts[1]
assert(leatrix.addon == "Leatrix_Maps" and leatrix.when())
env.LeaMapsDB = { ShowPointsOfInterest = "Off" }
assert(not leatrix.when())

-- Every pin sits on its map, and every instance has a zone-map pin as well as a continent one.
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

-- A raid-only pin takes the raid icon; anything with a dungeon in it, the dungeon icon.
assert(Model.Atlas({ x = 0, y = 0, instances = { 509, 531 } }) == "Raid")
assert(Model.Atlas({ x = 0, y = 0, instances = { 229, 409 } }) == "Dungeon")
assert(Model.Atlas({ x = 0, y = 0, instances = { 36 } }) == "Dungeon")

-- A lone instance is its own title; a complex is named by its area and lists its instances, iconned when mixed.
assert(Model.Describe({ x = 0, y = 0, instances = { 36 } }) == "instance 36")
local title, lines = Model.Describe({ x = 0, y = 0, instances = { 229, 409 }, area = 25 })
assert(title == "area 25" and lines == "|A:Dungeon|a instance 229\n|A:Raid|a instance 409", lines)
title, lines = Model.Describe({ x = 0, y = 0, instances = { 509, 531 }, area = 3478 })
assert(title == "area 3478" and lines == "instance 509\ninstance 531", lines)
title, lines = Model.Describe({ x = 0, y = 0, instances = { 47, 129 } })
assert(title == "instance 47" and lines == "instance 129")

-- A marker covers an entrance only within the half extents on both axes.
assert(Model.Covers(0.5, 0.5, 0.505, 0.49, 0.01, 0.02))
assert(not Model.Covers(0.5, 0.5, 0.52, 0.5, 0.01, 0.02))
assert(not Model.Covers(0.5, 0.5, 0.5, 0.53, 0.01, 0.02))

-- A click travels to the entrance's own coordinates on the map it is drawn on, named as its tooltip names it.
local travelled
function ns.Navigate(uiMapID, x, y, name)
	travelled = { uiMapID, x, y, name }
end
Model.Travel(1415, { x = 0.47, y = 0.61, instances = { 229, 409 }, area = 25 })
assert(travelled[1] == 1415 and travelled[2] == 0.47 and travelled[3] == 0.61 and travelled[4] == "area 25")
Model.Travel(1427, { x = 0.35, y = 0.84, instances = { 36 } })
assert(travelled[1] == 1427 and travelled[4] == "instance 36")
print("dungeonentrances: ok")
