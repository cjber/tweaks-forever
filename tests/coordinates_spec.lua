-- World map coordinates (Map/Coordinates.lua): the player's and the cursor's map position along the bottom of the
-- world map, from engine reads only, on our own frame.
local features, db, initializers, settingCallbacks, hooks = {}, {}, {}, {}, {}
local ns = {
	L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}),
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
	Active = function(key)
		return db[key]
	end,
	OnSettingChanged = function(key, fn)
		settingCallbacks[key] = fn
	end,
}

local function Region()
	local region = { shown = true }
	for _, method in ipairs({ "SetPoint", "SetSize", "SetFrameLevel", "SetParent" }) do
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
local bar
local env = setmetatable({
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
		assert(parent == nil, "the bar is made with no parent, then set on the map (Map/MapCanvas.lua)")
		bar = Region()
		return bar
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
	hooksecurefunc = function(_, name, fn)
		hooks[name] = fn
	end,
}, { __index = _G })
setfenv(assert(loadfile("Map/MapCanvas.lua")), env)("TweaksForever", ns)
setfenv(assert(loadfile("Map/Coordinates.lua")), env)("TweaksForever", ns)
local feature = features.mapCoords
assert(feature.default == true, "a display, not an automation")
local named = {}
for _, conflict in ipairs(feature.conflicts) do
	named[conflict.addon or conflict.polestar or conflict.openmap] = conflict
end
assert(named.Leatrix_Maps and named.Mapster and named.Coordinates and named["maps.coords"], "the coordinate addons")
assert(named.coords and named.coords.openmap == "coords", "OpenMap's own coordinates bar")
assert(named.Leatrix_Maps.when(), "Leatrix Maps shows coordinates by default")
env.LeaMapsDB = { ShowCoords = "Off" }
assert(not named.Leatrix_Maps.when(), "Leatrix Maps with its coordinates off")
env.LeaMapsDB.ShowCoords = "On"
assert(named.Leatrix_Maps.when())

local Model = ns.Coordinates
assert(Model.Format(0.452, 0.601) == "45.2, 60.1")
assert(Model.Format(0, 0) == nil, "no position (an instance) shows nothing")
assert(Model.Format(1.2, 0.5) == nil and Model.Format(nil, nil) == nil, "off the map shows nothing")
local x, y = Model.Cursor(canvas)
assert(x == 0.5 and y == 0.5, "the cursor's place on the canvas")

db.mapCoords = true
initializers[1]()
local text = bar.texts[1]
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
db.mapCoords = false
settingCallbacks.mapCoords()
assert(not bar.shown, "turned off, the bar hides at once")
db.mapCoords = true
hooks.RefreshConflicts()
assert(bar.shown, "and follows conflicts")
print("coordinates: ok")
