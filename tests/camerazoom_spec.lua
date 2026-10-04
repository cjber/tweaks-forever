local features, initializers, db = {}, {}, {}
local ns = {
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
	Active = function(key)
		return db[key]
	end,
	db = db,
}
local changed
ns.OnSettingChanged = function(key, fn)
	assert(key == "cameraZoom")
	changed = fn
end
local values = { cameraDistanceMaxZoomFactor = "1.9" }
local writes = {}
local env = setmetatable({
	GetCVar = function(name)
		return values[name]
	end,
	SetCVar = function(name, value)
		values[name] = value
		writes[#writes + 1] = name .. "=" .. value
	end,
}, { __index = _G })
setfenv(assert(loadfile("UI/CameraZoom.lua")), env)("TweaksForever", ns)
assert(features.cameraZoom.default == false and features.cameraZoom.category == "Interface")
initializers[1]()
assert(#writes == 0, "off with nothing saved writes nothing")

db.cameraZoom = true
changed()
assert(values.cameraDistanceMaxZoomFactor == "2.6")
assert(db.cameraZoomSaved == "1.9", "the player's own value is kept")
assert(#writes == 1)

changed()
assert(db.cameraZoomSaved == "1.9", "the extended value is never saved over the player's")
assert(#writes == 1, "an already extended value is not written again")

db.cameraZoom = false
changed()
assert(values.cameraDistanceMaxZoomFactor == "1.9", "the player's own value comes back")
assert(db.cameraZoomSaved == nil, "the saved value is handed back once")

-- A client without the cvar is left alone, and nothing is remembered.
env.GetCVar = function()
	return nil
end
writes = {}
db.cameraZoom = true
changed()
assert(#writes == 0 and db.cameraZoomSaved == nil)

local leatrix = features.cameraZoom.conflicts[1].when
assert(not leatrix())
env.LeaPlusDB = { MaxCameraZoom = "On" }
assert(leatrix())
print("camerazoom: ok")
