---@type string, TFNamespace
local _, ns = ...
local L = ns.L

local KEY = "rareAlerts"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Rare alerts",
	tooltip = "A chat line and a sound when a rare creature's nameplate or map marker appears near you. "
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
-- The game has no sound for a rare as such. This is its own map marker (vignette) chime,
-- sound/interface/ui_vignette_mapping_01.ogg (sound kit 37881 in retail's SoundKitEntry); Forever's client ships the
-- file without that kit, so it is played by file.
local SOUND = 893809
-- The map markers the game gives a rare creature.
local VIGNETTE_ATLAS = { VignetteKill = true, VignetteKillElite = true }

-- [GUID] = when it last alerted; entries past the quiet time are dropped as it grows.
---@type table<string, number>
local alerted = {}
local count = 0

-- Whether `guid` should alert now, recording it when so. An unreadable GUID never alerts.
---@param guid any
---@param now number
---@return boolean
local function Fresh(guid, now)
	if type(guid) ~= "string" then
		return false
	end
	local last = alerted[guid]
	if last and now - last < QUIET then
		return false
	end
	if not last then
		count = count + 1
		if count > 100 then
			for other, at in pairs(alerted) do
				if now - at >= QUIET then
					alerted[other], count = nil, count - 1
				end
			end
		end
	end
	alerted[guid] = now
	return true
end

---@param name any
---@return boolean
local function Named(name)
	return type(name) == "string" and name ~= ""
end

-- Rares found within this many seconds of a chime (after a fight, in one marker update, or plates a frame apart)
-- each get their chat line but no chime of their own, so the sound never stacks.
local CHIME_GAP = 2
-- When the sound last played.
---@type number?
local chimed

---@param name string
---@param now number
local function Alert(name, now)
	ns.Print(L["rare nearby: %s."]:format(name))
	if not chimed or now - chimed >= CHIME_GAP then
		-- A sound the client refuses to play leaves the next rare free to try.
		if PlaySoundFile(SOUND, "Master") ~= false then
			chimed = now
		end
	end
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
	local now = GetTime()
	if Named(name) and Fresh(guid, now) then
		Alert(name, now)
	end
end

-- One map marker: a living rare's, shown on the minimap (so near you), with a readable name and GUID.
---@param id string
local function CheckVignette(id)
	local info = C_VignetteInfo.GetVignetteInfo(id)
	if not info or info.isDead or info.onMinimap == false or not VIGNETTE_ATLAS[info.atlasName or ""] then
		return
	end
	local guid, name = ns.Readable(info.objectGUID), ns.Readable(info.name)
	local now = GetTime()
	if Named(name) and Fresh(guid, now) then
		Alert(name, now)
	end
end

local function CheckVignettes()
	if not Ready() or not C_VignetteInfo then
		return
	end
	for _, id in ipairs(C_VignetteInfo.GetVignettes() or {}) do
		CheckVignette(id)
	end
end

-- After a fight, what appeared during it: the nameplates up now and the markers.
local function AfterCombat()
	if not ns.Active(KEY) then
		return
	end
	for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
		local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
		if unit then
			CheckUnit(unit)
		end
	end
	CheckVignettes()
end

---@param event WowEvent
---@return boolean
local function Valid(event)
	return not not (C_EventUtils and C_EventUtils.IsEventValid(event))
end

ns.On("NAME_PLATE_UNIT_ADDED", CheckUnit)
ns.On("PLAYER_REGEN_ENABLED", AfterCombat)
-- Only where the client has map markers; registering an event it doesn't know raises.
if C_VignetteInfo then
	if Valid("VIGNETTES_UPDATED") then
		ns.On("VIGNETTES_UPDATED", CheckVignettes)
	end
	if Valid("VIGNETTE_MINIMAP_UPDATED") then
		ns.On("VIGNETTE_MINIMAP_UPDATED", function(id, onMinimap)
			if onMinimap and Ready() then
				CheckVignette(id)
			end
		end)
	end
end
