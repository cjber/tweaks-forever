local features, initializers, events, handlers = {}, {}, {}, {}
local active = true
local ns = {
	FitButton = function(button, width)
		button.fitted = width
	end,
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
	Active = function()
		return active
	end,
	On = function(event, fn)
		events[event] = fn
	end,
	OnSettingChanged = function(key, fn)
		handlers[key] = fn
	end,
}

-- A frame that remembers what the feature did to it. Unlisted methods do nothing and return the frame.
local created = 0
local textures, fontStrings = {}, {}
local function Frame(kind)
	local frame = { kind = kind, shown = true, scripts = {}, hooks = {}, registered = {}, text = nil, enabled = true }
	local methods
	-- The client fires OnShow and OnHide when the shown state changes, and not otherwise.
	local function SetShown(self, value)
		value = not not value
		if self.shown == value then
			return
		end
		self.shown = value
		local fn = self.scripts[value and "OnShow" or "OnHide"]
		if fn then
			fn(self)
		end
		for _, hook in ipairs(self.hooks[value and "OnShow" or "OnHide"] or {}) do
			hook(self)
		end
	end
	methods = {
		Show = function(self)
			SetShown(self, true)
		end,
		Hide = function(self)
			SetShown(self, false)
		end,
		IsShown = function(self)
			return self.shown
		end,
		SetShown = SetShown,
		SetEnabled = function(self, value)
			self.enabled = value
		end,
		RegisterEvent = function(self, event)
			self.registered[event] = true
		end,
		UnregisterEvent = function(self, event)
			self.registered[event] = nil
		end,
		IsMouseOver = function(self)
			return self.mouseOver == true
		end,
		SetPropagateKeyboardInput = function(self, value)
			self.propagate = value
		end,
		GetPropagateKeyboardInput = function(self)
			return self.propagate
		end,
		EnableKeyboard = function(self, value)
			self.keyboard = value
		end,
		SetSize = function(self, width, height)
			self.size = { width, height }
		end,
		SetScript = function(self, name, fn)
			self.scripts[name] = fn
		end,
		HookScript = function(self, name, fn)
			self.hooks[name] = self.hooks[name] or {}
			table.insert(self.hooks[name], fn)
		end,
		SetText = function(self, text)
			self.text = text
		end,
		SetTexture = function(self, texture)
			self.texture = texture
		end,
		GetWidth = function()
			return 1000
		end,
		GetHeight = function()
			return 600
		end,
		GetStringHeight = function()
			return 50
		end,
		GetFrameLevel = function()
			return 1
		end,
		CreateTexture = function()
			local texture = Frame("Texture")
			textures[#textures + 1] = texture
			return texture
		end,
		GenerateMenu = function()
			error("the native menu asserts in Forever build 70009")
		end,
		SetupMenu = function()
			error("the native menu asserts in Forever build 70009")
		end,
		CreateFontString = function()
			local text = Frame("FontString")
			fontStrings[#fontStrings + 1] = text
			return text
		end,
	}
	return setmetatable(frame, {
		__index = function(_, name)
			return methods[name] or function(self)
				return self
			end
		end,
	})
end

local map = Frame("Map")
map.ScrollContainer = Frame("ScrollContainer")
map.shownMap = 1000
map.GetMapID = function()
	return map.shownMap
end
map.AddDataProvider = function()
	error("the dungeon map adds no data provider to the world map")
end

local combat, instanceType, instance, playerMap = false, "party", 36, 1000
local nextFrame = {}
local art = {
	[36] = {
		{ title = "The Deadmines 1", pattern = "Interface\\WorldMap\\TheDeadmines\\TheDeadmines1", separator = "_" },
		{ title = "The Deadmines 2", pattern = "Interface\\WorldMap\\TheDeadmines\\TheDeadmines2", separator = "_" },
	},
	[48] = {
		{
			title = "Blackfathom Deeps 1",
			pattern = "Interface\\WorldMap\\BlackfathomDeeps\\BlackfathomDeeps1",
			separator = "_",
		},
		{
			title = "Blackfathom Deeps 2",
			pattern = "Interface\\WorldMap\\BlackfathomDeeps\\BlackfathomDeeps2",
			separator = "_",
		},
		{
			title = "Blackfathom Deeps 3",
			pattern = "Interface\\WorldMap\\BlackfathomDeeps\\BlackfathomDeeps3",
			separator = "_",
		},
	},
	[90] = { { title = "Gnomeregan", pattern = "Interface\\WorldMap\\Gnomeregan\\Gnomeregan1", separator = "_" } },
}
local env = setmetatable({
	WorldMapFrame = map,
	DungeonMapArt = art,
	InCombatLockdown = function()
		return combat
	end,
	GetInstanceInfo = function()
		return "name", instanceType, 1, "Normal", 5, 0, false, instance
	end,
	C_Map = {
		GetBestMapForUnit = function()
			return playerMap
		end,
	},
	CreateFrame = function(kind)
		created = created + 1
		return Frame(kind)
	end,
	CreateFromMixins = function(mixin)
		return setmetatable({}, { __index = mixin })
	end,
	C_Timer = {
		After = function(_, fn)
			nextFrame[#nextFrame + 1] = fn
		end,
	},
}, { __index = _G })
setfenv(assert(loadfile("UI/Keys.lua")), env)("TweaksForever", ns)
setfenv(assert(loadfile("Map/DungeonMaps.lua")), env)("TweaksForever", ns)
local Model = ns.DungeonMaps
ns.DungeonMapArt = art
local feature = features.dungeonMaps

-- On by default, with no optional addon dependency.
assert(feature.default == true and feature.category == "Maps")
assert(#(feature.conflicts or {}) == 0)

-- Floors come from generated native client metadata, including the tile stem.
local found = Model.Floors(art, 36)
assert(#found == 2 and found[1].title == "The Deadmines 1")
assert(found[1].pattern == "Interface\\WorldMap\\TheDeadmines\\TheDeadmines1" and found[1].separator == "_")
found = Model.Floors(art, 48)
assert(#found == 3 and found[1].title == "Blackfathom Deeps 1" and found[3].title == "Blackfathom Deeps 3")
assert(#Model.Floors(art, 90) == 1)
assert(#Model.Floors(art, 409) == 0)
assert(#Model.Floors(nil, 36) == 0 and #Model.Floors("bad", 36) == 0)

-- Only a party dungeon, while the map shows the zone the player is in.
assert(Model.Inside("party", 36, 1000, 1000) == 36)
assert(Model.Inside("party", 36, 1000, 1001) == nil)
assert(Model.Inside("party", 36, nil, nil) == nil)
assert(Model.Inside("raid", 409, 1, 1) == nil and Model.Inside("none", 0, 1, 1) == nil)
assert(Model.Floor(3, nil) == 1 and Model.Floor(3, 2) == 2 and Model.Floor(3, 9) == 3 and Model.Floor(1, 0) == 1)

-- The feature starts from ns.Init and reaches the map only through a view of our own (Map/MapCanvas.lua, stubbed
-- here: tests/map_canvas_spec.lua runs it) and its own hooks. Every frame is made with no parent, then set on the
-- map: the gamepad interface follows frames created inside an open window.
assert(#initializers == 1)
local frames = {}
local factory = env.CreateFrame
env.CreateFrame = function(kind, _, parent, template)
	assert(parent == nil, "a frame was made inside the map")
	local frame = factory(kind)
	frame.template = template
	frames[#frames + 1] = frame
	return frame
end
local watched
ns.MapCanvas = {
	FrameUnder = function(kind, parent, template)
		local frame = env.CreateFrame(kind, nil, nil, template)
		frame.parent = parent
		return frame
	end,
	Watch = function(watchedMap, listener)
		assert(watchedMap == map)
		watched = listener
	end,
}
-- The map turning to another map, as the view tells it.
local function Turned()
	watched(nil, "map")
end
initializers[1]()
assert(watched and map.hooks.OnShow and map.hooks.OnHide and events.PLAYER_ENTERING_WORLD)
assert(events.ZONE_CHANGED_NEW_AREA and events.PLAYER_REGEN_ENABLED and handlers.dungeonMaps)

local function Open()
	map:Show()
end
local function Close()
	map:Hide()
end

-- Nothing is built until a dungeon map is shown.
instanceType = "none"
Turned()
Close()
Open()
assert(created == 0 and #frames == 0, "an outdoor map built frames")

-- A dungeon draws a twelve-tile floor and offers its floors in the picker.
instanceType, instance = "party", 36
Close()
Open()
local host, back, reopen, picker, popup
for _, frame in ipairs(frames) do
	if frame.template == "UIPanelButtonTemplate" and frame.text == "Back to map" then
		back = frame
	elseif frame.template == "UIPanelButtonTemplate" and frame.text == "Dungeon map" then
		reopen = frame
	elseif frame.template == "UIPanelButtonTemplate" and frame.parent == frames[1] then
		picker = frame
	elseif frame.kind == "Frame" and frame.parent == picker then
		popup = frame
	end
end
host = frames[1] -- the first frame built is the one over the map canvas
assert(host and host.shown and back and reopen and picker and popup)
assert(reopen.text == "Dungeon map" and not reopen.shown)
assert(back.fitted == 112 and reopen.fitted == 112, "both buttons widen to a longer translated label")
local heading = fontStrings[1]
assert(heading.text == "The Deadmines 1")
assert(textures[2].texture == "Interface\\WorldMap\\TheDeadmines\\TheDeadmines1_1")
assert(textures[13].texture == "Interface\\WorldMap\\TheDeadmines\\TheDeadmines1_12")
assert(picker.shown, "multiple floors need a picker")
assert(not popup.shown and not popup.registered.GLOBAL_MOUSE_DOWN)
local built = #frames

-- Entering a dungeon with floors retargets the same host: every floor gets a choice.
instance = 48
events.ZONE_CHANGED_NEW_AREA()
assert(#frames > built and host.shown and picker.shown)
local choices = {}
for _, frame in ipairs(frames) do
	if frame.parent == popup then
		choices[#choices + 1] = frame
	end
end
assert(#choices == 3 and heading.text == "Blackfathom Deeps 1" and picker.text == "Blackfathom Deeps 1")
assert(
	choices[1].text == "Blackfathom Deeps 1" and not choices[1].enabled and choices[2].enabled and choices[3].enabled
)
assert(choices[3].shown and popup.size[2] == 3 * 26 + 12)
local rebuilt = #frames

-- The picker opens a popup of our own frames, and Escape, an outside click, a choice or the map closing shuts it.
picker.scripts.OnClick()
assert(popup.shown and popup.registered.GLOBAL_MOUSE_DOWN and popup.keyboard)
popup.scripts.OnKeyDown(popup, "A")
assert(popup.shown and popup.propagate == true, "a key other than Escape was swallowed")
popup.scripts.OnKeyDown(popup, "ESCAPE")
assert(not popup.shown and popup.propagate == false and not popup.registered.GLOBAL_MOUSE_DOWN)
nextFrame[1]()
assert(popup.propagate == true, "keys pass through again on the next frame")
picker.scripts.OnClick()
popup.mouseOver = true
popup.scripts.OnEvent(popup, "GLOBAL_MOUSE_DOWN")
picker.mouseOver = true
popup.mouseOver = false
popup.scripts.OnEvent(popup, "GLOBAL_MOUSE_DOWN")
assert(popup.shown, "a click on the popup or its button closed it")
picker.mouseOver = false
popup.scripts.OnEvent(popup, "GLOBAL_MOUSE_DOWN")
assert(not popup.shown and not popup.registered.GLOBAL_MOUSE_DOWN, "an outside click left the popup open")
picker.scripts.OnClick()
picker.scripts.OnClick()
assert(not popup.shown, "the button did not toggle")
picker.scripts.OnClick()
Close()
assert(not popup.shown and not popup.registered.GLOBAL_MOUSE_DOWN, "closing the map left the popup listening")
Open()
assert(not popup.shown)

-- Choosing a floor draws it, and the choice outlasts the map being closed and reopened, and another dungeon.
picker.scripts.OnClick()
choices[2].scripts.OnClick()
assert(not popup.shown and not popup.registered.GLOBAL_MOUSE_DOWN)
assert(heading.text == "Blackfathom Deeps 2" and picker.text == "Blackfathom Deeps 2")
assert(textures[2].texture == "Interface\\WorldMap\\BlackfathomDeeps\\BlackfathomDeeps2_1")
assert(choices[1].enabled and not choices[2].enabled and choices[3].enabled)
Close()
Open()
assert(heading.text == "Blackfathom Deeps 2" and not choices[2].enabled, "the chosen floor was forgotten")
instance = 36
events.ZONE_CHANGED_NEW_AREA()
assert(heading.text == "The Deadmines 1" and picker.shown)
instance = 48
events.ZONE_CHANGED_NEW_AREA()
assert(heading.text == "Blackfathom Deeps 2" and picker.shown, "the floor was not remembered for the dungeon")
assert(#frames == rebuilt, "reopening or retargeting rebuilt the frames")

-- Back to map steps aside to the stock map, and the canvas button brings the interior back.
back.scripts.OnClick()
assert(not host.shown and reopen.shown)
reopen.scripts.OnClick()
assert(host.shown and not reopen.shown)

-- Leaving the dungeon, browsing to another map or turning the setting off hides it, popup included.
picker.scripts.OnClick()
instanceType = "none"
events.ZONE_CHANGED_NEW_AREA()
assert(not host.shown and not reopen.shown and not popup.shown and not popup.registered.GLOBAL_MOUSE_DOWN)
instanceType = "party"
events.ZONE_CHANGED_NEW_AREA()
assert(host.shown)
map.shownMap = 1001
Turned()
assert(not host.shown)
map.shownMap = 1000
Turned()
assert(host.shown)
picker.scripts.OnClick()
active = false
handlers.dungeonMaps()
assert(not host.shown and not popup.shown)
active = true
handlers.dungeonMaps()
assert(host.shown)

-- A closed map leaves nothing to do.
Close()
instanceType = "none"
events.PLAYER_ENTERING_WORLD()
instanceType = "party"
Open()

-- In combat nothing is built or retargeted, and the host never holds another dungeon's floor: it steps aside,
-- remembers it is behind, and the end of combat catches up.
built = #frames
combat = true
instance = 90
events.ZONE_CHANGED_NEW_AREA()
assert(not host.shown and #frames == built, "combat kept or retargeted the old dungeon")
assert(heading.text == "Blackfathom Deeps 2", "combat drew over the old dungeon")
instanceType = "none"
events.ZONE_CHANGED_NEW_AREA()
assert(not host.shown, "combat kept the interior over the map")
instanceType = "party"
events.ZONE_CHANGED_NEW_AREA()
assert(not host.shown)
combat = false
events.PLAYER_REGEN_ENABLED()
assert(
	host.shown and heading.text == "Gnomeregan" and #frames == built,
	"the end of combat did not draw the new dungeon"
)

-- A map opened in combat shows no earlier dungeon: the host was left shown by the last map that closed.
Close()
combat = true
instance = 48
Open()
assert(not host.shown and heading.text == "Gnomeregan", "a combat map open showed the previous dungeon")
events.PLAYER_REGEN_ENABLED()
assert(not host.shown, "the end of combat drew while the map was still pending in combat")
combat = false
events.PLAYER_REGEN_ENABLED()
assert(host.shown and heading.text == "Blackfathom Deeps 2", "the end of combat missed the pending dungeon")

-- The same dungeon reopened in combat waits as well, and one already drawn is left alone.
Close()
combat = true
Open()
assert(not host.shown)
combat = false
events.PLAYER_REGEN_ENABLED()
assert(host.shown and heading.text == "Blackfathom Deeps 2")
combat = true
events.ZONE_CHANGED_NEW_AREA()
assert(host.shown, "combat hid an interior that was already right")
combat = false

-- An unlisted instance has no interior and nothing raises.
env.DungeonMapArt = {}
instance = 33
events.ZONE_CHANGED_NEW_AREA()
assert(not host.shown)
env.DungeonMapArt = art
instance = 90
events.ZONE_CHANGED_NEW_AREA()
assert(host.shown and heading.text == "Gnomeregan")
print("dungeonmaps: ok")
