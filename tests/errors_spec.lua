local features, initializers = {}, {}
local db = {}
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
}
local changed
local env = setmetatable({
	LE_GAME_ERR_SPELL_COOLDOWN = 1,
	LE_GAME_ERR_OUT_OF_MANA = 2,
	LE_GAME_ERR_INV_FULL = 3,
	-- The client already hides mana errors.
	BLACK_LISTED_MESSAGE_TYPES = { [2] = true },
	Settings = {
		SetOnValueChangedCallback = function(variable, fn)
			assert(variable == "TweaksForever_quietErrors")
			changed = fn
		end,
	},
}, { __index = _G })
env.UIErrorsFrame = {
	SetMessageTypeEnabled = function(_, messageType, enabled)
		env.BLACK_LISTED_MESSAGE_TYPES[messageType] = not enabled
	end,
	ShouldDisplayMessageType = function()
		error("the stock check is never replaced or called")
	end,
}
env._G = env
setfenv(assert(loadfile("Errors.lua")), env)("TweaksForever", ns)
assert(features.quietErrors.default == true and #initializers == 1)
local hidden = env.BLACK_LISTED_MESSAGE_TYPES
db.quietErrors = true
initializers[1]()
assert(hidden[1] and hidden[2], "quiet types are hidden")
assert(not hidden[3], "other errors still show")
db.quietErrors = false
changed()
assert(not hidden[1], "switching off applies at once")
assert(hidden[2], "and leaves the client's own hidden types hidden")
db.quietErrors = true
changed()
assert(hidden[1] and hidden[2] and not hidden[3])

local leatrix = features.quietErrors.conflicts[1].when
assert(not leatrix())
env.LeaPlusDB = { HideErrorMessages = "On" }
assert(leatrix())
print("errors: ok")
