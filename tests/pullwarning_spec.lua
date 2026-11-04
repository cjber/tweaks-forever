-- Pull warning (Features/PullWarning.lua): in a group, one chat line when your threat on your target passes the
-- tank's (UnitThreatSituation 1), re-armed only by dropping back below the tank, a new target or leaving combat, and
-- silent while the threat or the name is secret.
local features, handlers, db, printed = {}, {}, {}, {}
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
	Active = function(key)
		return db[key]
	end,
	Print = function(message)
		printed[#printed + 1] = message
	end,
}

local SECRET = {}
local grouped, status, name = true, 0, "Defias Pillager"
local env = setmetatable({
	canaccessvalue = function(value)
		return value ~= SECRET
	end,
	IsInGroup = function()
		return grouped
	end,
	UnitThreatSituation = function(unit, mob)
		assert(unit == "player" and mob == "target")
		return status
	end,
	UnitName = function(unit)
		assert(unit == "target")
		return name
	end,
}, { __index = _G })
setfenv(assert(loadfile("Core/Secret.lua")), env)("TweaksForever", ns)
setfenv(assert(loadfile("Features/PullWarning.lua")), env)("TweaksForever", ns)

assert(features.pullWarning.default == true, "a warning acts for no one, so it starts on")
db.pullWarning = true

local function Threat(value)
	status = value
	handlers.UNIT_THREAT_SITUATION_UPDATE("player")
end

Threat(1)
assert(
	#printed == 1 and printed[1] == "you are about to pull Defias Pillager off the tank.",
	"warns once over the tank"
)
Threat(1)
handlers.UNIT_THREAT_LIST_UPDATE("target")
assert(#printed == 1, "only once while still over the tank")
Threat(3)
Threat(1)
assert(#printed == 1, "taking it and losing it again does not repeat the warning")
Threat(0)
Threat(1)
assert(#printed == 2, "dropping back below the tank re-arms it")

handlers.UNIT_THREAT_LIST_UPDATE("nameplate3")
assert(#printed == 2, "another mob's threat list is not the target's")

status = 1
handlers.PLAYER_TARGET_CHANGED()
assert(#printed == 3, "a new target already over the tank warns at once")

Threat(SECRET)
Threat(1)
assert(#printed == 3, "a secret threat answer changes nothing")

handlers.PLAYER_REGEN_ENABLED()
name = SECRET
Threat(1)
assert(printed[4] == "you are about to pull your target off the tank.", "a secret name is left out")
name = "Defias Pillager"

Threat(0)
grouped = false
Threat(1)
assert(#printed == 4, "solo, a pet holding the mob is no warning")

grouped = true
db.pullWarning = false
Threat(0)
Threat(1)
assert(#printed == 4, "nothing while switched off")

print("pullwarning_spec: ok")
