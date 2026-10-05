---@type string, TFNamespace
local _, ns = ...

local KEY = "cameraZoom"
local CVAR = "cameraDistanceMaxZoomFactor"
-- The game's own Max Camera Distance slider stops at 2.0; this is the same extended value Leatrix Plus sets.
local MAX = "2.6"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Maximum camera zoom",
	tooltip = "The camera pulls back further than the game's own Max Camera Distance setting allows. The value you "
		.. "had before is put back when you switch this off.",
	default = false,
	conflicts = {
		{
			addon = "Leatrix_Plus",
			when = function()
				return LeaPlusDB and LeaPlusDB.MaxCameraZoom == "On"
			end,
		},
	},
})

-- The extended value while the feature is on, the player's own value again once it is off. SavedVariables keeps
-- the earlier value across a reload. A client without the cvar, or one with the feature off and nothing saved,
-- is left untouched.
local function Apply()
	local current = GetCVar(CVAR)
	if not current then
		return
	end
	if ns.Active(KEY) then
		ns.db.cameraZoomSaved = ns.db.cameraZoomSaved or current
		if current ~= MAX then
			SetCVar(CVAR, MAX)
		end
	elseif ns.db.cameraZoomSaved then
		SetCVar(CVAR, ns.db.cameraZoomSaved)
		ns.db.cameraZoomSaved = nil
	end
end

ns.Init(function()
	Apply()
	ns.OnSettingChanged(KEY, Apply)
end)
