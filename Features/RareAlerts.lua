---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end
local L = ns.L

local KEY = "rareAlerts"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Rare alerts",
	tooltip = "A chat line and a sound when a rare creature's nameplate or map marker appears near you. "
		.. "Not in combat, and once per rare for ten minutes. Click the rare's name in chat, or press the key "
		.. "bound under Key Bindings > AddOns, to set a waypoint to it.",
	default = false,
	conflicts = {
		{
			addon = "RareScanner",
			when = function()
				local profile = RareScannerDB and RareScannerDB.profile
				return profile and profile.general and profile.general.scanRares ~= false
			end,
		},
		{
			addon = "SilverDragon",
			when = function()
				local profile = SilverDragon3DB and SilverDragon3DB.profile
				return profile and (profile.scan or 0) > 0
			end,
		},
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

---@class TFRarePlace
---@field map integer
---@field x number
---@field y number
---@field name string
---@field vignette string? its map marker, read again on a click while the marker is still up

-- [GUID] = where it was when it alerted, dropped with its `alerted` entry; `lastPlace` is the latest, for the
-- key binding.
---@type table<string, TFRarePlace>
local places = {}
---@type TFRarePlace?
local lastPlace

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
					alerted[other], places[other], count = nil, nil, count - 1
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

-- The marker the game shows for `guid`, if any: a rare seen by its nameplate may also have one.
---@param guid string
---@return string?
local function MarkerOf(guid)
	for _, id in ipairs(C_VignetteInfo and C_VignetteInfo.GetVignettes() or {}) do
		local info = C_VignetteInfo.GetVignetteInfo(id)
		if info and ns.Readable(info.objectGUID) == guid then
			return ns.Readable(id)
		end
	end
end

-- Where the rare is on the player's map: its marker's position, else the player's own, since a rare with no marker
-- was seen by its nameplate and so is close. Nil inside an instance, where neither is given.
---@param vignette string?
---@return integer? map
---@return Vector2DMixin? position
local function Position(vignette)
	local map = C_Map.GetBestMapForUnit("player")
	if not map then
		return
	end
	local position = vignette and C_VignetteInfo.GetVignettePosition(vignette, map)
	return map, position or C_Map.GetPlayerMapPosition(map, "player")
end

-- Sets a waypoint to `place` (Shortest Path Forever's journey when it takes it), at the marker's current position
-- while it is still up.
---@param place TFRarePlace?
local function Waypoint(place)
	if not place then
		ns.Print(L["No rare has been found nearby yet."])
		return
	end
	local info = place.vignette and C_VignetteInfo.GetVignetteInfo(place.vignette)
	if info and not info.isDead then
		local position = C_VignetteInfo.GetVignettePosition(place.vignette, place.map)
		if position then
			place.x, place.y = position.x, position.y
		end
	end
	ns.Navigate(place.map, place.x, place.y, place.name)
end

local LINK = "addon:TweaksForever:rare:"

---@param guid string
---@param name string
---@param vignette string?
---@param now number
local function Alert(guid, name, vignette, now)
	vignette = vignette or MarkerOf(guid)
	local map, position = Position(vignette)
	local shown = name
	if map and position then
		lastPlace = { map = map, x = position.x, y = position.y, name = name, vignette = vignette }
		places[guid] = lastPlace
		-- A link the chat frame hands to the SetItemRef callback below when clicked.
		shown = NORMAL_FONT_COLOR:WrapTextInColorCode(("|H%s%s|h[%s]|h"):format(LINK, guid, name))
	end
	ns.Print(L["rare nearby: %s."]:format(shown))
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
		Alert(guid, name, nil, now)
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
		Alert(guid, name, ns.Readable(id), now)
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
-- Nameplates and markers that appeared while the world loaded, before the settings did (#202): a nameplate is
-- announced only once, so look again as soon as the settings are read.
ns.Init(AfterCombat)
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

-- A click on a rare's name in an alert line. The chat frame triggers this through EventRegistry, which runs each
-- callback in its own secure call, and a waypoint is not a protected action.
if EventRegistry then
	EventRegistry:RegisterCallback("SetItemRef", function(_, link)
		local guid = type(link) == "string" and link:sub(1, #LINK) == LINK and link:sub(#LINK + 1)
		if guid then
			ns.core.SafeCall("rare waypoint", Waypoint, places[guid])
		end
	end, places)
end

-- The key binding (Bindings.xml) clicks this button of our own, so a gamepad button can be bound to it too.
local BUTTON = "TweaksForeverRareWaypointButton"
_G["BINDING_NAME_CLICK " .. BUTTON .. ":LeftButton"] = L["Set a waypoint to the last rare found"]
CreateFrame("Button", BUTTON):SetScript("OnClick", function()
	ns.core.SafeCall("rare waypoint", Waypoint, lastPlace)
end)
