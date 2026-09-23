local features, initializers = {}, {}
local ns = {
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
}
local env = setmetatable({}, { __index = _G })
assert(loadfile("Data/Overlays.lua"))("TweaksForever", ns)
setfenv(assert(loadfile("Exploration.lua")), env)("TweaksForever", ns)
local Model = ns.Exploration
assert(#initializers == 1 and features.exploration.default == false)

local predicates = {}
for _, conflict in ipairs(features.exploration.conflicts) do
	predicates[conflict.addon] = conflict.when
	assert(conflict.addon ~= "Magnify", "zoom alone is not an exploration conflict")
end
assert(predicates.LegacyForever())
env.LegacyForeverDB = { showAreas = false }
assert(not predicates.LegacyForever())
env.LegacyForeverDB.showAreas = true
assert(predicates.LegacyForever())
env.LeaMapsDB = { RevealMap = "Off" }
assert(not predicates.Leatrix_Maps())
env.LeaMapsDB.RevealMap = "On"
assert(predicates.Leatrix_Maps())
assert(not predicates.Mapster())
local fogEnabled = true
env.LibStub = function()
	return {
		GetAddon = function(_, name)
			assert(name == "Mapster")
			return {
				GetModule = function(_, module)
					assert(module == "FogClear")
					return {
						IsEnabled = function()
							return fogEnabled
						end,
					}
				end,
			}
		end,
	}
end
assert(predicates.Mapster())
fogEnabled = false
assert(not predicates.Mapster())

local layers = Model.Decode("1,10,20,257,256,123,456;2,10,20,16,17,789;")
assert(#layers[1] == 1 and #layers[2] == 1)
assert(layers[1][1].key == "10:20:257:256")
assert(layers[1][1].files[2] == 456 and layers[2][1].files[1] == 789)
local tiles = Model.OverlayTiles(257, 256, 256, 256)
assert(#tiles == 2)
assert(tiles[1].x == 0 and tiles[1].width == 256 and tiles[1].u == 1)
assert(tiles[2].x == 256 and tiles[2].width == 1 and tiles[2].u == 1 / 16)
assert(tiles[2].height == 256 and tiles[2].v == 1)
tiles = Model.OverlayTiles(512, 273, 256, 256)
assert(#tiles == 4 and tiles[4].x == 256 and tiles[4].y == 256)
assert(tiles[4].height == 17 and tiles[4].v == 17 / 32)
tiles = Model.OverlayTiles(512, 512, 512, 512)
assert(#tiles == 1 and tiles[1].u == 1 and tiles[1].v == 1)
assert(#Model.Unexplored(layers[1], nil) == 1)
local explored = { { offsetX = 10, offsetY = 20, textureWidth = 257, textureHeight = 256 } }
assert(#Model.Unexplored(layers[1], explored) == 0)
explored[1].offsetX = 11
assert(#Model.Unexplored(layers[1], explored) == 1, "geometry, not a partial key, identifies explored areas")

local arts, areas, files = 0, 0, 0
for art, encoded in pairs(ns.Overlays) do
	assert(type(art) == "number" and type(encoded) == "string", "source must remain lazy")
	arts = arts + 1
	for _, decoded in pairs(Model.Decode(encoded)) do
		local seen = {}
		for _, area in ipairs(decoded) do
			assert(not seen[area.key] and area.width > 0 and area.height > 0)
			seen[area.key] = true
			assert(#area.files > 0)
			for _, file in ipairs(area.files) do
				assert(file > 0 and file == math.floor(file))
				files = files + 1
			end
			areas = areas + 1
		end
	end
end
assert(arts == 84 and areas == 1073 and files == 1739, "pinned build coverage changed")
print("exploration_spec: ok")
