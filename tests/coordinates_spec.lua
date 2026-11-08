-- World map coordinates (Map/Coordinates.lua): the player's and the cursor's map position along the bottom of the
-- world map, from engine reads only, on our own frame, and the bar stepping aside for the game's own coordinates
-- (#371). Core's own conflict mechanism and event frame are loaded so the CVars reach the bar as they change.
-- Core/SafeCall.lua installs its error handler and event frame once per addon; this stand-in client already counts
-- this copy as installed, so the journal builds no frame and the frames here keep their order.
ForeverErrorJournal = { installed = { TweaksForever = true } }
local frames, callbacks, errors, cvars = {}, {}, {}, {}
local ns = {
	L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}),
}

local function Region()
	local region = { shown = true }
	for _, method in ipairs({ "SetPoint", "SetSize", "SetFrameLevel", "SetParent", "RegisterEvent", "UnregisterEvent" }) do
		region[method] = function() end
	end
	function region:SetText(text)
		self.text, self.sets = text, (self.sets or 0) + 1
	end
	function region:SetShown(shown)
		self.shown = shown
	end
	function region:SetScript(script, fn)
		self.scripts = self.scripts or {}
		self.scripts[script] = fn
	end
	function region:CreateFontString()
		local text = Region()
		self.texts = self.texts or {}
		self.texts[#self.texts + 1] = text
		return text
	end
	return region
end

local cursorX, cursorY, over, playerPos = 300, 200, true, { 0.452, 0.601 }
local canvas = {
	GetLeft = function()
		return 100
	end,
	GetTop = function()
		return 400
	end,
	GetWidth = function()
		return 400
	end,
	GetHeight = function()
		return 400
	end,
	GetEffectiveScale = function()
		return 1
	end,
}
local env = setmetatable({
	C_AddOns = {
		IsAddOnLoaded = function()
			return false
		end,
	},
	C_CVar = {
		GetCVarBool = function(name)
			return cvars[name] == true
		end,
	},
	Settings = {
		SetOnValueChangedCallback = function(variable, fn)
			callbacks[variable] = fn
		end,
	},
	WorldMapFrame = {
		ScrollContainer = {
			Child = canvas,
			GetFrameLevel = function()
				return 1
			end,
			IsMouseOver = function()
				return over
			end,
		},
		GetMapID = function()
			return 1431
		end,
	},
	CreateFrame = function(_, _, parent)
		assert(parent == nil, "frames are made with no parent, then set on the map (Map/MapCanvas.lua)")
		local frame = Region()
		frames[#frames + 1] = frame
		return frame
	end,
	GetCursorPosition = function()
		return cursorX, cursorY
	end,
	C_Map = {
		GetPlayerMapPosition = function()
			return playerPos and {
				GetXY = function()
					return playerPos[1], playerPos[2]
				end,
			}
		end,
	},
	hooksecurefunc = function(target, name, fn)
		local original = target[name]
		target[name] = function(...)
			local results = { original(...) }
			fn(...)
			return unpack(results)
		end
	end,
	strtrim = function(text)
		return (text:gsub("^%s+", ""):gsub("%s+$", ""))
	end,
	GetTime = function()
		return 0
	end,
	geterrorhandler = function()
		return function(message)
			errors[#errors + 1] = message
		end
	end,
}, { __index = _G })
setfenv(assert(loadfile("Core/SafeCall.lua")), env)("TweaksForever", ns)
setfenv(assert(loadfile("Core/Log.lua")), env)("TweaksForever", ns)
setfenv(assert(loadfile("Core/Core.lua")), env)("TweaksForever", ns)
setfenv(assert(loadfile("Map/MapCanvas.lua")), env)("TweaksForever", ns)
setfenv(assert(loadfile("Map/Coordinates.lua")), env)("TweaksForever", ns)

local feature
for _, declared in ipairs(ns.features) do
	if declared.key == "mapCoords" then
		feature = declared
	end
end
assert(feature and feature.default == true, "a display, not an automation")
local named = {}
for _, conflict in ipairs(feature.conflicts) do
	named[conflict.polestar or conflict.openmap or conflict.addon or conflict.title] = conflict
end
assert(named.Leatrix_Maps and named.Mapster and named.Coordinates and named["maps.coords"], "the coordinate addons")
assert(named.coords and named.coords.openmap == "coords", "OpenMap's own coordinates bar")
assert(named.Leatrix_Maps.when(), "Leatrix Maps shows coordinates by default")
env.LeaMapsDB = { ShowCoords = "Off" }
assert(not named.Leatrix_Maps.when(), "Leatrix Maps with its coordinates off")
env.LeaMapsDB.ShowCoords = "On"
assert(named.Leatrix_Maps.when())
local game = named["The game itself"]
assert(game and game.cvar[1] == "worldMapShowPlayerCoords", "the game's own player coordinates")
assert(game.cvar[2] == "worldMapShowCursorCoords", "and cursor coordinates")

local Model = ns.Coordinates
assert(Model.Format(0.452, 0.601) == "45.2, 60.1")
assert(Model.Format(0, 0) == nil, "no position (an instance) shows nothing")
assert(Model.Format(1.2, 0.5) == nil and Model.Format(nil, nil) == nil, "off the map shows nothing")
local x, y = Model.Cursor(canvas)
assert(x == 0.5 and y == 0.5, "the cursor's place on the canvas")

-- Core's login frame is the second one it makes; the first carries its events.
frames[2].scripts.OnEvent(frames[2])
local bar = frames[#frames]
assert(#errors == 0, "login starts the bar: " .. tostring(errors[1]))
local text = bar.texts[1]
assert(bar.shown, "both of the game's coordinate settings off leaves the bar alone")
bar.scripts.OnShow()
assert(text.text == "Player: 45.2, 60.1    Cursor: 50.0, 50.0", "filled in as the map opens")
over = false
bar.scripts.OnUpdate(bar, 0.05)
assert(text.text == "Player: 45.2, 60.1    Cursor: 50.0, 50.0", "updated a few times a second, not every frame")
bar.scripts.OnUpdate(bar, 0.05)
assert(text.text == "Player: 45.2, 60.1", "no cursor position off the map")
local sets = text.sets
bar.scripts.OnUpdate(bar, 0.2)
assert(text.sets == sets, "an unchanged line isn't set again")
playerPos, over = nil, true
bar.scripts.OnUpdate(bar, 0.2)
assert(text.text == "Cursor: 50.0, 50.0", "no player position where the map has none")
over = false
bar.scripts.OnUpdate(bar, 0.2)
assert(text.text == "", "neither")

cvars.worldMapShowPlayerCoords = true
frames[1].scripts.OnEvent(frames[1], "CVAR_UPDATE", "worldMapShowPlayerCoords")
assert(not bar.shown and ns.ConflictOf("mapCoords") == "The game itself", "the game's player coordinates hide the bar")
cvars.worldMapShowPlayerCoords, cvars.worldMapShowCursorCoords = false, true
frames[1].scripts.OnEvent(frames[1], "CVAR_UPDATE", "worldMapShowCursorCoords")
assert(not bar.shown and ns.ConflictOf("mapCoords") == "The game itself", "its cursor coordinates hide the bar too")
cvars.worldMapShowCursorCoords = false
frames[1].scripts.OnEvent(frames[1], "CVAR_UPDATE", "worldMapShowCursorCoords")
assert(bar.shown and not ns.ConflictOf("mapCoords"), "both off, the bar returns")
cvars.worldMapShowCursorCoords = true
frames[1].scripts.OnEvent(frames[1], "CVAR_UPDATE", "somethingElse")
assert(bar.shown, "another CVar leaves the bar as it was")
frames[1].scripts.OnEvent(frames[1], "CVAR_UPDATE", "worldMapShowCursorCoords")
assert(not bar.shown, "and the game's cursor setting hides it when it turns on")

ns.db.mapCoords = false
callbacks.TweaksForever_mapCoords(nil, nil, false)
assert(not bar.shown, "turned off, the bar hides at once")
cvars.worldMapShowCursorCoords = false
ns.RefreshConflicts()
assert(not bar.shown, "and stays hidden while its setting is off")
ns.db.mapCoords = true
callbacks.TweaksForever_mapCoords(nil, nil, true)
assert(bar.shown, "turned back on, it shows when no conflict is left")
print("coordinates: ok")
