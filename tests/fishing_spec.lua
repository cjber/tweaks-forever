local features, initializers, handlers, changes = {}, {}, {}, {}
local db = { fishingSounds = true, lureWarning = true }
local ns = {
	db = db,
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
	Active = function(key)
		return db[key]
	end,
	On = function(event, fn)
		handlers[event] = fn
	end,
}

local cvars = { Sound_SFXVolume = "0.4", Sound_MusicVolume = "0.3", Sound_AmbienceVolume = "0.6" }
local mainHand, messages = nil, {}
local env = setmetatable({
	INVSLOT_MAINHAND = 16,
	Settings = {
		SetOnValueChangedCallback = function(variable, fn)
			changes[variable:gsub("^TweaksForever_", "")] = fn
		end,
	},
	Enum = { ItemClass = { Weapon = 2 }, ItemWeaponSubclass = { Fishingpole = 20 } },
	C_Spell = {
		GetSpellName = function()
			return "Fishing"
		end,
	},
	C_Item = {
		GetItemInfoInstant = function(item)
			return item, nil, nil, nil, nil, 2, item == 6256 and 20 or 7
		end,
	},
	C_PaperDollInfo = { GetTemporaryEnchantmentInfo = function() end },
	GetInventoryItemID = function()
		return mainHand
	end,
	GetCVar = function(cvar)
		return cvars[cvar]
	end,
	SetCVar = function(cvar, value)
		cvars[cvar] = value
	end,
	CreateFrame = function()
		return { RegisterForClicks = function() end, SetAttribute = function() end, SetScript = function() end }
	end,
	UIErrorsFrame = {
		AddMessage = function(_, text)
			messages[#messages + 1] = text
		end,
	},
	YELLOW_FONT_COLOR = {
		GetRGB = function()
			return 1, 1, 0
		end,
	},
}, { __index = _G })
setfenv(assert(loadfile("Fishing.lua")), env)("TweaksForever", ns)
assert(features.applyLure.parent == "easyCast" and features.fishingSounds.default == false)
local Model = ns.Fishing

-- Lures: the best one carried that the skill allows.
local bags = { [6529] = 3, [6530] = 1, [6533] = 2 }
local function count(item)
	return bags[item] or 0
end
assert(Model.BestLure(count, 150) == 6533)
assert(Model.BestLure(count, 75) == 6530, "Aquadynamic needs 100 skill")
assert(Model.BestLure(count, 1) == 6529)
assert(Model.BestLure(function()
	return 0
end, 300) == nil)

assert(Model.IsDoubleClick(10, 10.2) and not Model.IsDoubleClick(10, 10.5) and not Model.IsDoubleClick(nil, 10))

-- Volumes: raised while a pole is equipped, the player's own back afterwards, whatever turned it off.
initializers[1]()
assert(cvars.Sound_SFXVolume == "0.4" and db.savedSounds == nil, "no pole, nothing changes")
mainHand = 6256
handlers.PLAYER_EQUIPMENT_CHANGED(16)
assert(cvars.Sound_SFXVolume == "1" and cvars.Sound_MusicVolume == "0" and cvars.Sound_AmbienceVolume == "0")
assert(messages[1] == "Your fishing pole has no lure.")
handlers.PLAYER_EQUIPMENT_CHANGED(16)
assert(db.savedSounds.Sound_SFXVolume == "0.4", "re-equipping keeps the first saved volumes")
mainHand = 1234
handlers.PLAYER_EQUIPMENT_CHANGED(16)
assert(cvars.Sound_SFXVolume == "0.4" and cvars.Sound_MusicVolume == "0.3" and db.savedSounds == nil)
mainHand = 6256
handlers.PLAYER_EQUIPMENT_CHANGED(16)
db.fishingSounds = false
changes.fishingSounds()
assert(cvars.Sound_AmbienceVolume == "0.6" and db.savedSounds == nil, "switching off restores at once")
db.fishingSounds = true
changes.fishingSounds()
handlers.PLAYER_LOGOUT()
assert(cvars.Sound_SFXVolume == "0.4" and db.savedSounds == nil, "logging out restores")
print("fishing: ok")
