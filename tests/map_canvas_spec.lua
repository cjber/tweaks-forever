-- Run from the repository root: luajit tests/map_canvas_spec.lua
-- Map/MapDraw.lua and Map/Exploration.lua on a world map and a zone map that fail on any write
-- (tests/strict_map.lua): Tweaks draws its unexplored tint on frames of its own, adds no data provider,
-- acquires no pin and writes nothing of the maps' (#168).
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

local Kit = dofile("tests/strict_map.lua")
Kit.Install(_G)

-- Westfall (1436) has art 1194's overlays.
local world = { mapID = 1436 }
WorldMapFrame = Kit.NewMap(world)
local zone = { mapID = 1436, visible = false }

Enum = { UIMapType = { Zone = 3 } }
C_Map = {
	GetMapInfo = function()
		return { mapType = 3 }
	end,
	GetMapArtID = function()
		return 1194
	end,
	GetMapArtLayers = function()
		return { { tileWidth = 256, tileHeight = 256 } }
	end,
}
C_MapExplorationInfo = {
	GetExploredMapTextures = function()
		return {}
	end,
}
local loaded = false
C_AddOns = {
	IsAddOnLoaded = function()
		return loaded
	end,
}
hooksecurefunc = function(target, name, fn)
	local original = target[name]
	target[name] = function(...)
		original(...)
		fn(...)
	end
end

local initializers, events, settings = {}, {}, {}
local active = { exploration = true }
local ns = {
	-- Core/API.lua's change signal, which this spec does not load.
	APIChanged = function() end,
	Feature = function() end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
	Active = function(key)
		return active[key]
	end,
	On = function(event, fn)
		events[event] = fn
	end,
	OnSettingChanged = function(key, fn)
		settings[key] = fn
	end,
	RefreshConflicts = function() end,
	core = {
		SafeCall = function(_, fn, ...)
			return true, fn(...)
		end,
	},
}
assert(loadfile("Map/MapDraw.lua"))("TweaksForever", ns)
assert(loadfile("Data/Overlays.lua"))("TweaksForever", ns)
assert(loadfile("Map/Exploration.lua"))("TweaksForever", ns)
for _, init in ipairs(initializers) do
	init()
end

-- The tint's textures: the frame of ours on the canvas host that is no pin layer.
local function Tint(state)
	for _, frame in ipairs(Kit.frames) do
		local host = frame.parent and frame.parent.parent == state.canvas
		if host and frame.scripts.OnUpdate == nil and frame.level == 19 then
			return frame
		end
	end
end

-- Opening the map draws on the next frame of its view, on frames of ours.
Kit.Tick()

-- The unexplored tint: textures of ours, masked as the map is, on a frame on the canvas at the exploration level.
local tint = Tint(world)
check(tint and tint.mouse == false, "the tint is a frame of ours that never takes the mouse")
active.exploration = true
settings.exploration()
events.MAP_EXPLORATION_UPDATED()
check(tint.level == 19, "the tint sits just under the map's exploration pin")

-- A zoom redraws the tint only when it changes the art layer: the tiles are in canvas units.
local mapInfos = 0
local GetMapInfo = C_Map.GetMapInfo
C_Map.GetMapInfo = function(...)
	mapInfos = mapInfos + 1
	return GetMapInfo(...)
end
world.zoom = 0.5
Kit.Tick()
check(mapInfos == 0, "a zoom within the art layer leaves the tint alone")
world.layer = 2
world.zoom = 1
Kit.Tick()
check(mapInfos == 1, "a zoom onto another art layer redraws it")
world.zoom, world.layer = 0, 1
Kit.Tick()
C_Map.GetMapInfo = GetMapInfo

-- The zone map loads later and gets a view of its own.
BattlefieldMapFrame = Kit.NewMap(zone)
events.ADDON_LOADED("Blizzard_BattlefieldMap")
zone.visible = true
Kit.Tick()
check(Tint(zone) ~= nil, "the zone map gets its own tint")

-- Nothing of ours is made inside an open window, and each canvas holds one frame of ours.
for _, state in ipairs({ world, zone }) do
	local onCanvas = 0
	for _, frame in ipairs(Kit.frames) do
		onCanvas = onCanvas + (frame.parent == state.canvas and 1 or 0)
	end
	check(onCanvas == 1, "a canvas holds exactly one frame of ours, its view's host")
end
for _, frame in ipairs(Kit.frames) do
	check(frame.madeUnder == nil, "every frame of ours is made with no parent")
end

print(("map_canvas: %d checks passed"):format(checks))
