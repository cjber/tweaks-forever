---@type string, TFNamespace
local _, ns = ...
local L = ns.L

local KEY = "rareAlerts"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Rare alerts",
	tooltip = "A chat line and a warning sound when a rare creature's nameplate or map marker appears near you. "
		.. "Not in combat, and once per rare for ten minutes.",
	default = false,
	conflicts = {
		{ addon = "RareScanner" },
		{ addon = "NovaRares", title = "Nova Rares" },
		{ polestar = "rares.alerts" },
	},
})

-- The same rare (by GUID) alerts again only after this long, in seconds.
local QUIET = 600
local RARE = { rare = true, rareelite = true }
-- The map markers the game gives a rare creature.
local VIGNETTE_ATLAS = { VignetteKill = true, VignetteKillElite = true }

---@class TFRareAlerts
local Model = {}
ns.RareAlerts = Model

-- [GUID] = when it last alerted.
---@type table<string, number>
local alerted = {}

-- Whether `guid` should alert now, recording it when so. An unreadable GUID never alerts.
---@param guid string?
---@param now number
---@return boolean
function Model.Fresh(guid, now)
	if type(guid) ~= "string" then
		return false
	end
	local last = alerted[guid]
	if last and now - last < QUIET then
		return false
	end
	alerted[guid] = now
	return true
end

---@param name string
local function Alert(name)
	ns.Print(L["rare nearby: %s."]:format(name))
	PlaySound(SOUNDKIT.RAID_WARNING, "Master")
end

local function Ready()
	return ns.Active(KEY) and not UnitAffectingCombat("player")
end

-- A nameplate whose creature the game classes as rare; its GUID and name may be secret, and then it is skipped.
---@param unit string
local function CheckUnit(unit)
	if not Ready() or not RARE[UnitClassification(unit) or ""] then
		return
	end
	local guid, name = ns.Readable(UnitGUID(unit)), ns.Readable(UnitName(unit)) -- multi-value: Readable keeps the name
	if type(name) == "string" and Model.Fresh(guid, GetTime()) then
		Alert(name)
	end
end

-- The map's rare markers, where the client has them.
local function CheckVignettes()
	if not Ready() or not C_VignetteInfo then
		return
	end
	for _, id in ipairs(C_VignetteInfo.GetVignettes() or {}) do
		local info = C_VignetteInfo.GetVignetteInfo(id)
		local guid, name = info and ns.Readable(info.objectGUID), info and ns.Readable(info.name)
		if
			info
			and VIGNETTE_ATLAS[info.atlasName or ""]
			and type(name) == "string"
			and Model.Fresh(guid, GetTime())
		then
			Alert(name)
		end
	end
end

ns.On("NAME_PLATE_UNIT_ADDED", CheckUnit)
-- Only where the client has map markers; registering an event it doesn't know raises.
if C_VignetteInfo and C_EventUtils and C_EventUtils.IsEventValid("VIGNETTES_UPDATED") then
	ns.On("VIGNETTES_UPDATED", CheckVignettes)
	ns.On("VIGNETTE_MINIMAP_UPDATED", CheckVignettes)
end
