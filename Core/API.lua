---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end
local L = ns.L

-- Public addon-to-addon interface. It answers with the facts whether or not the spellbook shows Future Spells: a
-- caller such as Adventure Guide Forever plans a trainer visit from them, and turning the display off shouldn't
-- hide the visit. Trainer rows are recorded only while the feature is on, so with it off the answer is the baked
-- list's. A read with nothing to answer returns nil and a reason from ForeverCore.APIKit.NotReady, so a caller can
-- tell "ask again later" from "there is nothing to ask about"; docs/api.md lists which reason each read returns.
--
-- Trainers() needs version 2 or later. TrainableSpells() and DungeonEntrance() are there from version 1 and behave
-- the same in every version, so a caller checks version only before Trainers(). From version 3 a trainer's name and
-- place are QuestieDB's, so either can be missing, and Trainers() returns a second value. `minor` rises with each
-- addition within version 3 (1: each read's not-ready reason; 2: Subscribe and the reads below it); a caller checks
-- a member before using it.
---@class TFPublicAPI
local API = { version = 3, minor = 2 }

-- The shared shape every Forever addon's API follows: the not-ready answer a read gives while there is nothing to
-- answer (ForeverCore's docs/api-conventions.md). Core/Require.lua stops the addon before this file on an older
-- ForeverCore, so the kit is always here.
local APIKit = assert(ForeverCore.APIKit)

-- A read with nothing to answer, as the kit builds it: `nil, reason`. docs/api.md lists which reasons each read can
-- return, so a caller can tell "ask again later" from "there is nothing to ask about".
---@param reason ForeverCoreAPIReason
---@return nil, TFAPIReason
local function NotReady(reason)
	local _, answer = APIKit.NotReady(reason)
	return nil, answer --[[@as TFAPIReason]]
end

-- A positive or negative whole number, never NaN or infinity: a map or item ID.
---@param value any
---@return boolean
local function IsInteger(value)
	return type(value) == "number" and value == value and value % 1 == 0 and math.abs(value) < math.huge
end

---@return TFAPITrainableSpell[]?
---@return TFAPIReason?
function API.TrainableSpells()
	if not ns.db or InCombatLockdown() then
		return NotReady("loading")
	end
	local trainable = {}
	for _, entry in ipairs(ns.FutureSpells.Choose(ns.TrainerSpells(), nil, UnitLevel("player"), ns.KnownSpell)) do
		if entry.ready then
			local spell = entry.spell
			local lineID = spell.lineID --[[@as integer]] -- Choose lists only rows with a line
			trainable[#trainable + 1] = {
				spellID = entry.id,
				name = spell.name,
				level = spell.level,
				cost = spell.cost,
				line = spell.general and ns.GeneralName() or ns.LineName(lineID, spell.line),
				lineID = lineID,
				general = spell.general == true,
			}
		end
	end
	return trainable
end

-- The class trainers to visit, for the player's class, and where one of each stands. Which NPCs train a class is
-- baked, so every trainer is listed before login, in combat and with the spellbook's Future Spells off; an unknown
-- or unplayable class has none. A trainer's name and place are read from the installed QuestieDB a little each
-- frame, so they fill in over the first moments after login: ask again later. Without a QuestieDB to read, the
-- second value is a line for the player saying what to install. It always answers a table, so it has no not-ready
-- reason.
---@return TFAPITrainer[]
---@return string? install
function API.Trainers()
	local _, class = UnitClass("player")
	local baked = ns.ClassSpells[class]
	local trainers = {}
	if not baked then
		return trainers
	end
	local places, state = ns.QuestieSource.Places(baked.trainers)
	for _, npc in ipairs(baked.trainers) do
		local place = places[npc]
		trainers[#trainers + 1] = place and { npc = npc, name = place.name, map = place.map, x = place.x, y = place.y }
			or { npc = npc }
	end
	if state == "absent" then
		return trainers, L["Install Questie, or its QuestieDB addon on its own, to see where your class trainers are."]
	end
	return trainers
end

-- An instance's own door, never a merged pin's centre: Blackrock Mountain draws one pin for four doors, and a caller
-- routing to Blackwing Lair wants its own. Baked, so it answers with pins off or suppressed, before login and in
-- combat; an instance with no entrance in the client has nothing to answer.
---@param instanceID integer
---@return TFDungeonEntrance?
---@return TFAPIReason?
function API.DungeonEntrance(instanceID)
	local entrance = ns.InstanceEntrances[instanceID]
	if entrance then
		return { map = entrance.map, x = entrance.x, y = entrance.y }
	end
	return NotReady("none")
end

-- Whether the player marked `itemID` as junk, account-wide. It is their own mark, not a grey: a bag addon that also
-- treats poor quality as junk keeps doing that itself. The marks are read only while Mark items as junk is on, since
-- with it off there are none for a caller to draw.
---@param itemID integer
---@return boolean?
---@return TFAPIReason?
function API.IsJunk(itemID)
	if not ns.db then
		return NotReady("loading")
	end
	if not IsInteger(itemID) then
		return nil, "invalid"
	end
	if not ns.Active("markJunk") then
		return NotReady("disabled")
	end
	return ns.db.junk[itemID] == true
end

-- The player's own junk marks as a fresh sorted list of item IDs, for a bag addon that draws them. Greys are not in
-- it: poor quality is junk to the game's own Sell All Junk, and a bag addon treats it so itself.
---@return integer[]?
---@return TFAPIReason?
function API.JunkMarks()
	if not ns.db then
		return NotReady("loading")
	end
	if not ns.Active("markJunk") then
		return NotReady("disabled")
	end
	local marks = {}
	for itemID, marked in pairs(ns.db.junk) do
		if marked and IsInteger(itemID) then
			marks[#marks + 1] = itemID
		end
	end
	table.sort(marks)
	return marks
end

-- The reward choice on screen that sells to a merchant for strictly the most, as its index among the choices. A tie
-- at the top, fewer than two choices and no reward panel all have nothing to answer; a price the client hasn't read
-- yet asks again. It answers whether or not the marker feature is on.
---@return integer?
---@return TFAPIReason?
function API.BestReward()
	local choices = ns.BestReward.Choices()
	if not choices then
		return NotReady("none")
	end
	local best, pending = ns.BestReward.Best(choices)
	if pending then
		return NotReady("loading")
	end
	if not best then
		return NotReady("none")
	end
	return best
end

-- A zone's level range, from the client where it has one and Data/ZoneLevels.lua's otherwise. `map = nil` asks for
-- the zone the player is in. A map with no range (a city, an instance) has nothing to answer.
---@param map integer?
---@return { low: number, high: number }?
---@return TFAPIReason?
function API.ZoneLevels(map)
	if map ~= nil and not IsInteger(map) then
		return nil, "invalid"
	end
	local mapID = map or C_Map.GetBestMapForUnit("player")
	if not mapID then
		return NotReady("none")
	end
	local low, high = ns.ZoneLevels.Range(mapID)
	if not (low and high) then
		return NotReady("none")
	end
	return { low = low, high = high }
end

-- The XP per hour over the last 15 minutes, and the seconds to the next level at that pace, the same figure the
-- experience bar's tooltip shows. XP is only counted while the feature is on, so with it off there is no rate; the
-- first five minutes of a session have none either.
---@return { perHour: number, toLevel: number? }?
---@return TFAPIReason?
function API.XPRate()
	if not ns.db then
		return NotReady("loading")
	end
	if not ns.Active("xpRate") then
		return NotReady("disabled")
	end
	local rate = ns.XPRate.Rate(GetTime())
	if not rate then
		return NotReady("loading")
	end
	local answer = { perHour = rate }
	if rate > 0 then
		answer.toLevel = ns.XPRate.ToLevel(rate, UnitXP("player"), UnitXPMax("player"))
	end
	return answer
end

-- The most recent rare alert as fresh values, at its map marker's current position while the marker is still up.
-- Alerts only fire while the feature is on, so with it off there is nothing to answer.
---@return { name: string, map: integer, x: number, y: number }?
---@return TFAPIReason?
function API.LastRare()
	if not ns.db then
		return NotReady("loading")
	end
	if not ns.Active("rareAlerts") then
		return NotReady("disabled")
	end
	local place = ns.RareAlerts.Last()
	if not place then
		return NotReady("none")
	end
	return place
end

-- The unexplored areas of a zone map, each as a rectangle in the same 0 to 1 coordinates as a map position. `map =
-- nil` asks for the zone the player is in. A map that is not a zone, or whose art the client has no overlay data
-- for, has nothing to answer; every area explored answers an empty list.
---@param map integer?
---@return { left: number, top: number, right: number, bottom: number }[]?
---@return TFAPIReason?
function API.Unexplored(map)
	if map ~= nil and not IsInteger(map) then
		return nil, "invalid"
	end
	local mapID = map or C_Map.GetBestMapForUnit("player")
	if not mapID then
		return NotReady("none")
	end
	local info = C_Map.GetMapInfo(mapID)
	if not info or info.mapType ~= Enum.UIMapType.Zone then
		return NotReady("none")
	end
	local art = C_Map.GetMapArtID(mapID)
	local layers = art and ns.Exploration.Layers(art)
	local areas = layers and layers[1]
	local artLayers = C_Map.GetMapArtLayers(mapID)
	local layer = artLayers and artLayers[1]
	if not (areas and areas[1] and layer) then
		return NotReady("none")
	end
	local explored = C_MapExplorationInfo.GetExploredMapTextures(mapID)
	local rectangles = {}
	-- The tint places its textures in the map canvas's pixels, whose size is this art layer's, so the fractions are
	-- the same as a map position's.
	for _, area in ipairs(ns.Exploration.Unexplored(areas, explored)) do
		rectangles[#rectangles + 1] = {
			left = area.x / layer.layerWidth,
			top = area.y / layer.layerHeight,
			right = (area.x + area.width) / layer.layerWidth,
			bottom = (area.y + area.height) / layer.layerHeight,
		}
	end
	return rectangles
end

-- Subscribe's hub (ForeverCore.APIKit, docs/api-conventions.md): told once per burst what changed, the frame after
-- it did. `trainable` is keyed on the sorted spell IDs TrainableSpells answers, so an event that changes nothing
-- stays quiet; `junk`, `rare` and `explored` count the notices their producer raises and the hub compares.
local notices = { junk = 0, rare = 0, explored = 0 }

-- The sorted spell IDs as one comparable key, false while there is nothing to read. Before login and in combat the
-- read answers "loading", so the last key stands: entering combat is not itself a change.
---@type string|false?
local trainableKey
---@return string|false
local function TrainableKey()
	if not ns.db or InCombatLockdown() then
		return trainableKey or false
	end
	local ids = {}
	for _, spell in ipairs(API.TrainableSpells() or {}) do
		ids[#ids + 1] = spell.spellID
	end
	table.sort(ids)
	trainableKey = ids[1] and table.concat(ids, ",") or false
	return trainableKey
end

---@param name "junk"|"rare"|"explored"
---@return fun(): integer|false
local function Counter(name)
	return function()
		return notices[name] ~= 0 and notices[name] or false
	end
end

local hub = APIKit.Hub("TweaksForever", {
	trainable = TrainableKey,
	junk = Counter("junk"),
	rare = Counter("rare"),
	explored = Counter("explored"),
})

-- A producer telling subscribers that one of the event channels changed: Bags/Junk.lua's mark toggle, a rare alert,
-- a newly explored area.
---@param name "junk"|"rare"|"explored"
function ns.APIChanged(name)
	notices[name] = notices[name] + 1
	hub.Queue()
end

-- Call `callback(changes)` the frame after a channel changes, with only the changed names set to true. Returns an
-- unsubscribe function that is safe to call twice.
API.Subscribe = hub.Subscribe

-- The events that can change what TrainableSpells answers. The hub compares the sorted IDs, so one that changes
-- nothing sends nothing. Combat's own end is asked too: a spell learned during it reads once the work can.
local function TrainableChanged()
	hub.Queue()
end
ns.On("PLAYER_LEVEL_UP", TrainableChanged)
ns.On("SPELLS_CHANGED", TrainableChanged)
ns.On("PLAYER_REGEN_ENABLED", TrainableChanged)

TweaksForever = TweaksForever or {}
TweaksForever.API = API

-- Books the read of the player's own trainers at login, so the first caller usually finds them placed.
ns.Init(API.Trainers)
