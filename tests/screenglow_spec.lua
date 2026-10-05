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
	assert(key == "screenGlow")
	changed = fn
end
local values = { ffxGlow = "1" }
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
setfenv(assert(loadfile("UI/ScreenGlow.lua")), env)("TweaksForever", ns)
assert(features.screenGlow.default == false and features.screenGlow.category == "Interface")
initializers[1]()
assert(#writes == 0, "off with nothing saved writes nothing")

db.screenGlow = true
changed()
assert(values.ffxGlow == "0")
assert(db.screenGlowSaved == "1", "the player's own value is kept")
assert(#writes == 1)

db.screenGlow = false
changed()
assert(values.ffxGlow == "1", "the player's own value comes back")
assert(db.screenGlowSaved == nil, "the saved value is handed back once")
assert(#writes == 2)

-- A client without the cvar is left alone.
env.GetCVar = function()
	return nil
end
writes = {}
db.screenGlow = true
changed()
assert(#writes == 0 and db.screenGlowSaved == nil)

local leatrix = features.screenGlow.conflicts[1].when
assert(not leatrix())
env.LeaPlusDB = { NoScreenGlow = "On" }
assert(leatrix())
print("screenglow: ok")
