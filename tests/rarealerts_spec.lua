-- Rare alerts (Features/RareAlerts.lua): a chat line and a sound when a rare's nameplate or map marker appears,
-- off by default, never in combat, once per rare for ten minutes, and never from a secret GUID or name.
local features, handlers, db, printed, sounds, initializers = {}, {}, {}, {}, 0, {}
local ns = {
	L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}),
	Feature = function(feature)
		features[feature.key] = feature
	end,
	On = function(event, fn)
		handlers[event] = fn
	end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
	Active = function(key)
		return db[key]
	end,
	Print = function(message)
		printed[#printed + 1] = message
	end,
	core = {
		SafeCall = function(_, fn, ...)
			return fn(...)
		end,
	},
}
local navigated = {}
function ns.Navigate(map, x, y, title)
	navigated[#navigated + 1] = { map = map, x = x, y = y, title = title }
end

-- No map until the waypoint section below: inside an instance an alert is a plain line.
local now, combat, playerMap = 100, false, nil
local markerAt = { v1 = { x = 0.4, y = 0.5 } }
local callbacks, buttons = {}, {}
local units = {
	nameplate1 = { class = "rare", guid = "Creature-0-1-0-1-61-AAA", name = "Mother Fang" },
	nameplate2 = { class = "normal", guid = "Creature-0-1-0-1-299-BBB", name = "Young Wolf" },
	nameplate3 = { class = "rareelite", guid = "secret", name = "Hidden" },
	nameplate4 = { class = "rare", guid = "Creature-0-1-0-1-105-III", name = "Snort the Heckler" },
}
local vignettes = {
	v1 = { atlasName = "VignetteKill", objectGUID = "Creature-0-1-0-1-100-CCC", name = "Gruff Swiftbite" },
	v2 = { atlasName = "VignetteLoot", objectGUID = "GameObject-0-1-0-1-5-DDD", name = "Chest" },
	v3 = { atlasName = "VignetteKill", objectGUID = "Creature-0-1-0-1-101-EEE", name = "Dead One", isDead = true },
	v4 = { atlasName = "VignetteKill", objectGUID = "Creature-0-1-0-1-102-FFF", name = "Far One", onMinimap = false },
	v5 = { atlasName = "VignetteKill", objectGUID = "Creature-0-1-0-1-103-GGG", name = "" },
}
local env = setmetatable({
	canaccessvalue = function(value)
		return value ~= "secret"
	end,
	GetTime = function()
		return now
	end,
	UnitAffectingCombat = function()
		return combat
	end,
	UnitClassification = function(unit)
		return units[unit].class
	end,
	UnitGUID = function(unit)
		return units[unit].guid
	end,
	UnitName = function(unit)
		return units[unit].name
	end,
	C_NamePlate = {
		GetNamePlates = function()
			return { { namePlateUnitToken = "nameplate1" } }
		end,
	},
	PlaySoundFile = function(file, channel)
		assert(file == 893809 and channel == "Master", "the map marker chime on the Master channel")
		sounds = sounds + 1
		return true
	end,
	C_EventUtils = {
		IsEventValid = function()
			return true
		end,
	},
	C_VignetteInfo = {
		GetVignettes = function()
			return { "v1", "v2", "v3", "v4", "v5" }
		end,
		GetVignetteInfo = function(id)
			return vignettes[id]
		end,
		GetVignettePosition = function(id, map)
			assert(map == playerMap, "on the player's map")
			return markerAt[id]
		end,
	},
	C_Map = {
		GetBestMapForUnit = function(unit)
			assert(unit == "player")
			return playerMap
		end,
		GetPlayerMapPosition = function(map, unit)
			assert(map == playerMap and unit == "player")
			return { x = 0.1, y = 0.2 }
		end,
	},
	NORMAL_FONT_COLOR = {
		WrapTextInColorCode = function(_, text)
			return "|cffffd200" .. text .. "|r"
		end,
	},
	EventRegistry = {
		RegisterCallback = function(_, event, fn, owner)
			callbacks[event] = function(...)
				return fn(owner, ...)
			end
		end,
	},
	CreateFrame = function(kind, name)
		assert(kind == "Button" and not name:find("Secure"), "a plain button of our own, never a secure template")
		local button = {}
		function button:SetScript(script, fn)
			self[script] = fn
		end
		buttons[name] = button
		return button
	end,
}, { __index = _G })
setfenv(assert(loadfile("Core/Secret.lua")), env)("TweaksForever", ns)
setfenv(assert(loadfile("Features/RareAlerts.lua")), env)("TweaksForever", ns)
local feature = features.rareAlerts
assert(feature.default == false, "off by default")
local named = {}
for _, conflict in ipairs(feature.conflicts) do
	named[conflict.addon or conflict.polestar] = true
end
assert(named.RareScanner and named.NovaRares and named["rares.alerts"], "rare addons and Polestar's alerts")

handlers.NAME_PLATE_UNIT_ADDED("nameplate1")
assert(#printed == 0, "nothing while off")
db.rareAlerts = true
handlers.NAME_PLATE_UNIT_ADDED("nameplate1")
assert(printed[1] == "rare nearby: Mother Fang." and sounds == 1, "a rare's nameplate")
handlers.NAME_PLATE_UNIT_ADDED("nameplate1")
assert(#printed == 1, "once per rare")
handlers.NAME_PLATE_UNIT_ADDED("nameplate2")
handlers.NAME_PLATE_UNIT_ADDED("nameplate3")
assert(#printed == 1, "not a normal creature, nor a secret one")
now = now + 601
handlers.NAME_PLATE_UNIT_ADDED("nameplate1")
assert(#printed == 2 and sounds == 2, "again after ten minutes")
handlers.NAME_PLATE_UNIT_ADDED("nameplate4")
assert(#printed == 3 and sounds == 2, "a second rare within two seconds: its line, no stacked chime")
now = now + 2
handlers.VIGNETTES_UPDATED()
assert(printed[4] == "rare nearby: Gruff Swiftbite." and #printed == 4, "a living, near rare's marker only")
assert(sounds == 3, "a marker chimes too")
handlers.VIGNETTE_MINIMAP_UPDATED("v1", true)
assert(#printed == 4 and sounds == 3, "once")
combat = true
now = now + 601
handlers.VIGNETTES_UPDATED()
handlers.NAME_PLATE_UNIT_ADDED("nameplate1")
assert(#printed == 4 and sounds == 3, "never in combat")
combat = false
handlers.PLAYER_REGEN_ENABLED()
assert(printed[5] == "rare nearby: Mother Fang." and printed[6] == "rare nearby: Gruff Swiftbite.", "told once it ends")
assert(sounds == 4, "two rares found together chime once")
-- Two rares' markers in one update: two lines, one chime; then a marker reaching the minimap chimes on its own.
now = now + 601
vignettes.v2 = { atlasName = "VignetteKillElite", objectGUID = "Creature-0-1-0-1-104-HHH", name = "Second Rare" }
handlers.VIGNETTES_UPDATED()
assert(#printed == 8 and sounds == 5, "two markers in one update chime once")
now = now + 601
handlers.VIGNETTE_MINIMAP_UPDATED("v1", true)
assert(printed[9] == "rare nearby: Gruff Swiftbite." and sounds == 6, "a marker reaching the minimap")
-- A rare already near when the settings load (its nameplate came up during the loading screen) is told then.
now = now + 601
local before = #printed
assert(#initializers == 1)
initializers[1]()
assert(printed[before + 1] == "rare nearby: Mother Fang.", "the nameplates up at login")
db.rareAlerts = false
now = now + 601
before = #printed
initializers[1]()
assert(#printed == before, "and nothing with Rare alerts off")

-- Waypoints. The binding before any rare with a place says so, and sets nothing.
assert(env["BINDING_NAME_CLICK TweaksForeverRareWaypointButton:LeftButton"] == "Set a waypoint to the last rare found")
local button = buttons.TweaksForeverRareWaypointButton
before = #printed
button.OnClick(button)
assert(printed[before + 1] == "No rare has been found nearby yet." and #navigated == 0, "nothing to point at yet")
-- A rare with a map marker: its name is a link, and a click on it points at the marker.
db.rareAlerts, playerMap = true, 1429
now = now + 601
handlers.VIGNETTE_MINIMAP_UPDATED("v1", true)
local link = "addon:TweaksForever:rare:Creature-0-1-0-1-100-CCC"
assert(printed[#printed] == "rare nearby: |cffffd200|H" .. link .. "|h[Gruff Swiftbite]|h|r.", printed[#printed])
callbacks.SetItemRef(link, "[Gruff Swiftbite]", "LeftButton")
local went = navigated[1]
assert(went.map == 1429 and went.x == 0.4 and went.y == 0.5 and went.title == "Gruff Swiftbite", "at its marker")
-- The marker moved: a later click follows it; once the marker is gone, the last place it was.
markerAt.v1 = { x = 0.45, y = 0.55 }
callbacks.SetItemRef(link)
assert(navigated[2].x == 0.45 and navigated[2].y == 0.55, "the marker's current position")
vignettes.v1.isDead = true
callbacks.SetItemRef(link)
assert(navigated[3].x == 0.45, "where it was last seen")
vignettes.v1.isDead = nil
-- Other addons' links and links to a rare we don't know are left alone.
callbacks.SetItemRef("addon:OtherAddon:rare:x")
callbacks.SetItemRef("item:6948")
assert(#navigated == 3, "only our own links")
-- A nameplate-only rare (no marker carries its GUID) is pinned where the player stood, close by plate range.
now = now + 601
handlers.NAME_PLATE_UNIT_ADDED("nameplate4")
assert(printed[#printed]:find("|h%[Snort the Heckler%]|h"), "a nameplate rare's name is a link too")
button.OnClick(button)
went = navigated[4]
assert(went.x == 0.1 and went.y == 0.2 and went.title == "Snort the Heckler", "the binding: the last rare, by you")
-- A nameplate rare that also has a marker uses the marker.
units.nameplate5 = { class = "rare", guid = "Creature-0-1-0-1-100-CCC", name = "Gruff Swiftbite" }
now = now + 601
handlers.NAME_PLATE_UNIT_ADDED("nameplate5")
button.OnClick(button)
assert(navigated[5].x == 0.45, "a nameplate rare with a marker: the marker")
print("rarealerts: ok")
