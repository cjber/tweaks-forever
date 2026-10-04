---@type string, TFNamespace
local _, ns = ...

local KEY = "screenGlow"
local CVAR = "ffxGlow"
local OFF = "0"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "No screen glow",
	tooltip = "Turns off the full screen glow effect. The value you had before is put back when you switch this off.",
	default = false,
	conflicts = {
		{
			addon = "Leatrix_Plus",
			when = function()
				return LeaPlusDB and LeaPlusDB.NoScreenGlow == "On"
			end,
		},
	},
})

-- The glow off while the feature is on, the player's own value again once it is off. SavedVariables keeps the
-- earlier value across a reload. A client without the cvar, or one with the feature off and nothing saved, is
-- left untouched.
local function Apply()
	local current = GetCVar(CVAR)
	if not current then
		return
	end
	if ns.Active(KEY) then
		ns.db.screenGlowSaved = ns.db.screenGlowSaved or current
		if current ~= OFF then
			SetCVar(CVAR, OFF)
		end
	elseif ns.db.screenGlowSaved then
		SetCVar(CVAR, ns.db.screenGlowSaved)
		ns.db.screenGlowSaved = nil
	end
end

ns.Init(function()
	Apply()
	ns.OnSettingChanged(KEY, Apply)
end)
