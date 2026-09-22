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
local shown = {}
local env = setmetatable({
	LE_GAME_ERR_SPELL_COOLDOWN = 1,
	LE_GAME_ERR_OUT_OF_MANA = 2,
	LE_GAME_ERR_INV_FULL = 3,
	UIErrorsFrame = {
		ShouldDisplayMessageType = function(_, messageType)
			shown[#shown + 1] = messageType
			return true
		end,
	},
}, { __index = _G })
env._G = env
setfenv(assert(loadfile("Errors.lua")), env)("TweaksForever", ns)
assert(features.quietErrors.default == true and #initializers == 1)
initializers[1]()

local frame = env.UIErrorsFrame
db.quietErrors = true
assert(not frame:ShouldDisplayMessageType(1, "Spell is not ready yet."))
assert(not frame:ShouldDisplayMessageType(2, "Not enough mana"))
assert(frame:ShouldDisplayMessageType(3, "Inventory is full."), "other errors still show")
assert(#shown == 1 and shown[1] == 3, "quieted types never reach the stock check")
db.quietErrors = false
assert(frame:ShouldDisplayMessageType(1, "Spell is not ready yet."), "switching off applies at once")

local leatrix = features.quietErrors.conflicts[1].when
assert(not leatrix())
env.LeaPlusDB = { HideErrorMessages = "On" }
assert(leatrix())
print("errors: ok")
