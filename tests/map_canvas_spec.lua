-- Run from the repository root: luajit tests/map_canvas_spec.lua
-- Map/MapCanvas.lua, Map/DungeonEntrances.lua and Map/Exploration.lua on a world map and a zone map that fail on any
-- write (tests/strict_map.lua): Tweaks draws its entrances and its unexplored tint on frames of its own, adds no data
-- provider, acquires no pin and writes nothing of the maps' (#168), and keeps each pin's placing, scaling, tooltip,
-- click, step-aside and combat behaviour.
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

local Kit = dofile("tests/strict_map.lua")
Kit.Install(_G)

-- Westfall (1436) has the Deadmines entrance and art 1194's overlays; Stormwind's flight master sits beside it.
local world = { mapID = 1436, pins = { FlightPointPinTemplate = {} } }
WorldMapFrame = Kit.NewMap(world)
local zone = { mapID = 1436, visible = false }

local tooltip = { lines = {} }
local Tooltip = {
	SetOwner = function(_, owner)
		tooltip.owner, tooltip.lines = owner, {}
	end,
	GetOwner = function()
		return tooltip.owner
	end,
	Show = function() end,
	Hide = function()
		tooltip.owner = nil
	end,
}
GetAppropriateTooltip = function()
	return Tooltip
end
local function Line(_, text)
	tooltip.lines[#tooltip.lines + 1] = text
end
GameTooltip_SetTitle, GameTooltip_AddNormalLine, GameTooltip_AddInstructionLine = Line, Line, Line
GameTooltip_AddDisabledLine = Line
GetRealZoneText = function()
	return "The Deadmines"
end
local cvar = true
GetCVarBool = function(name)
	assert(name == "showDungeonEntrancesOnMap")
	return cvar
end
Enum = { UIMapType = { Zone = 3 } }
C_Map = {
	GetAreaInfo = function()
		return "Area"
	end,
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

local initializers, events, settings, travelled = {}, {}, {}, {}
local active = { dungeonEntrances = true, exploration = true }
local ns = {
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
	Art = {
		Markup = function()
			return ""
		end,
	},
	Navigate = function(uiMapID, x, y, title)
		travelled[#travelled + 1] = { uiMapID, x, y, title }
	end,
	NavigateHint = function()
		return "Click to travel there."
	end,
	EntranceHint = function()
		return nil
	end,
	SafeCall = function(_, fn, ...)
		return true, fn(...)
	end,
}
assert(loadfile("Map/MapCanvas.lua"))("TweaksForever", ns)
assert(loadfile("Data/DungeonEntrances.lua"))("TweaksForever", ns)
assert(loadfile("Data/Overlays.lua"))("TweaksForever", ns)
assert(loadfile("Map/Exploration.lua"))("TweaksForever", ns)
assert(loadfile("Map/DungeonEntrances.lua"))("TweaksForever", ns)
for _, init in ipairs(initializers) do
	init()
end

local function Entrances()
	local shown = {}
	for _, frame in ipairs(Kit.Made("TweaksForeverDungeonEntrancePinTemplate")) do
		if frame.shown and frame:IsVisible() then
			shown[#shown + 1] = frame
		end
	end
	return shown
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
local pins = Entrances()
check(#pins == #ns.DungeonEntrances[1436], "opening Westfall draws its entrance")
local pin = pins[1]
check(pin.Texture.atlas == "Dungeon" and pin.level == 30, "the retail dungeon icon, at the map's entrance level")
local entry = ns.DungeonEntrances[1436][1]
check(pin.point[2] == world.canvas and pin.point[4] == 1000 * entry.x, "the entrance sits at its map fraction")
check(pin.passThrough[1] == "RightButton" and #pin.passThrough == 1, "a right click goes through to zoom out")
world.zoom, world.scale = 1, 2
Kit.Tick()
check(math.abs(pin.scale - 0.6) < 1e-9, "zoomed in, the entrance keeps its size on screen")
world.zoom, world.scale = 0, 1
Kit.Tick()

-- Pointing at it shows the game's POI tooltip; a left click travels there.
pin:Run("OnEnter")
check(tooltip.owner == pin and tooltip.lines[1] == "The Deadmines", "pointing at an entrance names it")
check(tooltip.lines[#tooltip.lines] == "Click to travel there.", "and says what a click does")
Kit.mouseOver = pin
Kit.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Kit.Fire("GLOBAL_MOUSE_UP", "LeftButton")
check(#travelled == 1 and travelled[1][1] == 1436 and travelled[1][4] == "The Deadmines", "a click travels there")
Kit.Fire("GLOBAL_MOUSE_DOWN", "RightButton")
Kit.Fire("GLOBAL_MOUSE_UP", "RightButton")
check(#travelled == 1, "a right click is the map's")
Kit.mouseOver = nil
pin:Run("OnLeave")
check(tooltip.owner == nil, "leaving the entrance hides its tooltip")

-- An entrance steps aside for a Blizzard flight master or another Forever addon's marker on it.
world.pins.FlightPointPinTemplate[1] = { x = entry.x, y = entry.y }
for _ = 1, 20 do
	Kit.Tick()
end
check(#Entrances() == 0, "a flight master on the entrance hides it")
world.pins.FlightPointPinTemplate[1] = nil
-- Another addon publishes its own copy of the registry, as each does.
local function Publish(fn)
	local copy = {}
	for name, markers in pairs(ForeverMapMarkers) do
		copy[name] = markers
	end
	copy.ShortestPathForever = fn
	ForeverMapMarkers = copy
end
Publish(function()
	return { { x = entry.x + 0.001, y = entry.y, kind = "portal" } }
end)
for _ = 1, 20 do
	Kit.Tick()
end
check(#Entrances() == 0, "another Forever addon's marker on it hides it too")
Publish(function()
	error("a broken addon")
end)
for _ = 1, 20 do
	Kit.Tick()
end
check(#Entrances() == 1, "an addon's failing list is left out, never raised")
Publish(nil)
local listed = ForeverMapMarkers.TweaksForever(WorldMapFrame)
check(#listed == 1 and listed[1].kind == "entrance", "the entrances are listed for the other Forever addons")

-- The map's own filter and the setting redraw at once; another cvar leaves the entrances alone.
cvar = false
Kit.Fire("CVAR_UPDATE", "questPOI")
check(#Entrances() == 1, "another cvar redrew the entrances")
Kit.Fire("CVAR_UPDATE", "showDungeonEntrancesOnMap")
check(#Entrances() == 0, "the map's Show instance entrances filter hides them")
cvar = true
Kit.Fire("CVAR_UPDATE", "showDungeonEntrancesOnMap")
active.dungeonEntrances = false
settings.dungeonEntrances()
check(#Entrances() == 0, "turning the setting off hides them")
active.dungeonEntrances = true
settings.dungeonEntrances()
check(#Entrances() == 1, "and on again draws them")

-- Combat: a redraw hides our pins and acquires none; its end draws once and shows them.
Kit.combat = true
settings.dungeonEntrances()
check(#Entrances() == 0, "a redraw in combat hides the entrances")
settings.dungeonEntrances()
Kit.Fire("CVAR_UPDATE", "showDungeonEntrancesOnMap")
check(#ForeverMapMarkers.TweaksForever(WorldMapFrame) == 0, "hidden entrances are not listed")
Kit.combat = false
Kit.Fire("PLAYER_REGEN_ENABLED")
check(#Entrances() == 1, "the end of combat draws them again")

-- The unexplored tint: textures of ours, masked as the map is, on a frame on the canvas at the exploration level.
local tint = Tint(world)
check(tint and tint.mouse == false, "the tint is a frame of ours that never takes the mouse")
active.exploration = true
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
check(#Entrances() == 1, "and the world map keeps its entrances")

-- Nothing of ours is made inside an open window, each canvas holds one frame of ours, and no pin has a click script
-- or a field the map reads off its mouse focus.
for _, state in ipairs({ world, zone }) do
	local onCanvas = 0
	for _, frame in ipairs(Kit.frames) do
		onCanvas = onCanvas + (frame.parent == state.canvas and 1 or 0)
	end
	check(onCanvas == 1, "a canvas holds exactly one frame of ours, its view's host")
end
for _, frame in ipairs(Kit.frames) do
	check(frame.madeUnder == nil, "every frame of ours is made with no parent")
	if frame.template then
		for _, script in ipairs({ "OnClick", "OnMouseDown", "OnMouseUp", "OnDoubleClick" }) do
			check(frame.scripts[script] == nil, "a pin has no " .. script .. " script")
		end
		check(frame.owningMap == nil and frame.pinTemplate == nil, "a pin carries no field the map reads")
	end
end

-- Closing the world map leaves the hovered pin; the gamepad's map cursor points at the nearest one.
pins = Entrances()
pins[1]:Run("OnEnter")
Kit.Close(WorldMapFrame)
check(tooltip.owner == nil, "closing the map hides an entrance's tooltip")
Enum.InputDeviceInterfaceType = { Gamepad = 2 }
C_InputInterfaceStyle = {
	GetCurrentStyle = function()
		return 2
	end,
}
world.visible = true
Kit.Tick()
pins = Entrances()
pins[1].centerX, pins[1].centerY = 100, 100
SoftCursor = {
	IsShown = function()
		return true
	end,
	GetRect = function()
		return 95, 95, 10, 10
	end,
	GetEffectiveScale = function()
		return 1
	end,
}
Kit.Tick()
check(tooltip.owner == pins[1], "the gamepad's map cursor points at the entrance under it")
SoftCursor.GetRect = function()
	return 400, 400, 10, 10
end
Kit.Tick()
check(tooltip.owner == nil, "moving the cursor away leaves it")
Kit.mouseOver = pins[1]
pins[1]:Run("OnEnter")
Kit.Tick()
check(tooltip.owner == pins[1], "the map cursor never takes away an entrance the mouse is on")
Kit.mouseOver = nil
pins[1]:Run("OnLeave")
-- Leaving the gamepad interface lets go of the entrance the map cursor pointed at.
SoftCursor.GetRect = function()
	return 95, 95, 10, 10
end
Kit.Tick()
check(tooltip.owner == pins[1], "the cursor points at it again")
C_InputInterfaceStyle.GetCurrentStyle = function()
	return 0
end
Kit.Tick()
check(tooltip.owner == nil, "turning the gamepad interface off lets go of the cursor's entrance")
world.mapID = 1429
check(#ForeverMapMarkers.TweaksForever(WorldMapFrame) == 0, "a map just turned to lists nothing until it is drawn")

print(("map_canvas: %d checks passed"):format(checks))
