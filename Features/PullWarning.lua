---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end
local L = ns.L

local KEY = "pullWarning"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Pull warning",
	tooltip = "In a group, a chat line when your threat on your target passes the tank's, just before it turns on you. "
		.. "Once each time, until you drop back below the tank or change target. To colour nameplates by threat, use "
		.. "the game's own Nameplates options.",
	default = true,
	conflicts = {
		{ addon = "Omen" },
		{ addon = "ThreatClassic2" },
	},
})

-- UnitThreatSituation's answer when someone else holds the mob but you are above them on its threat list: the game
-- turns it on you once you pass them by a margin, so this is the moment to stop.
local OVER_TANK = 1

-- Whether this target has been warned about since your threat last dropped below the tank's.
local warned = false

-- Your threat situation on your target: nil when the target is not on a threat list with you, or when the client
-- keeps it secret in some combat states, and then nothing changes.
local function Check()
	if not ns.Active(KEY) or not IsInGroup() then
		warned = false
		return
	end
	local status = ns.Readable(UnitThreatSituation("player", "target"))
	if status ~= OVER_TANK then
		-- Holding it yourself (2 or 3) keeps the warning spent; only dropping back below the tank re-arms it.
		if status == 0 then
			warned = false
		end
		return
	end
	if warned then
		return
	end
	warned = true
	local name = ns.Readable(UnitName("target")) -- multi-value: Readable keeps the name
	if type(name) == "string" and name ~= "" then
		ns.Print(L["you are about to pull %s off the tank."]:format(name))
	else
		ns.Print(L["you are about to pull your target off the tank."])
	end
end

ns.On("UNIT_THREAT_SITUATION_UPDATE", function(unit)
	if unit == "player" then
		Check()
	end
end)
ns.On("UNIT_THREAT_LIST_UPDATE", function(unit)
	if unit == "target" then
		Check()
	end
end)
ns.On("PLAYER_TARGET_CHANGED", function()
	warned = false
	Check()
end)
ns.On("PLAYER_REGEN_ENABLED", function()
	warned = false
end)
