---@type string, TFNamespace
local _, ns = ...

-- QuestieDB, read in game through its public API (contract 2) for the Forever flavour. Nothing of it is copied into
-- this addon: it carries no licence. QuestGivers.lua and QuestProgress.lua read quests through the same library.
local ADDON, CONTRACT = "QuestieDB", 2
-- Milliseconds of reading in one frame. An NPC's row is decoded from QuestieDB's store on its first read.
local SLICE_MS = 1
-- Questie can load and never report ready, when its startup stops on an error. The read then goes ahead without it.
local READY_WAIT = 60
local NPC_FIELDS = { "name", "spawns", "zoneID" }

---@class TFQuestieSource
local Source = {}
ns.QuestieSource = Source

-- [library] = its area-to-map lookup, or false when its zone tables can't be read; read once per library.
local mapOf = setmetatable({}, { __mode = "k" })
-- [npc] = its name and one place, or false for an NPC QuestieDB doesn't have; kept for the session.
---@type table<integer, TFNpcPlace|false>
local places = {}
---@type integer[]
local queue = {}
---@type table<integer, true>
local queued = {}
-- Reading waits for login, and for Questie to finish starting when it is installed; `running` while a frame is booked.
local open, running = false, false

-- One of ZoneDB's tables, which QuestieDB keeps as Lua source returning a table literal: run with no globals. Nil when
-- it is missing, doesn't parse, errors or returns something else.
---@param source any
---@return table?
local function Table(source)
	local chunk = type(source) == "string" and loadstring(source)
	if chunk then
		local ok, value = pcall(setfenv(chunk, {}))
		if ok and type(value) == "table" then
			return value
		end
	end
end

-- The loaded QuestieDB, if it is the Forever build of a contract this addon was written against.
---@return TFQuestieDB?
function ns.QuestieDB()
	local db = LibQuestieDB
	if type(db) ~= "table" or C_AddOns.GetAddOnMetadata(ADDON, "X-Flavor") ~= "Forever" then
		return nil
	end
	local ok, fits = pcall(db.RequireContract, CONTRACT)
	return ok and fits and db or nil
end

-- The loaded QuestieDB and the map each of its areas is drawn on; nil when its zone tables can't be read, so nothing
-- is ever placed from partial data.
---@return TFQuestieDB?
---@return (fun(area: integer): integer?)?
function Source.Zones()
	local db = ns.QuestieDB()
	if not db or not (db.Npc and db.Support) then
		return nil
	end
	local MapOf = mapOf[db]
	if MapOf == nil then
		local source = db.Support.Get("ZoneDB")
		local private = type(source) == "table" and source.private
		local map, override, parent
		if type(private) == "table" then
			map, override, parent =
				Table(private.areaIdToUiMapId),
				Table(private.areaIdToUiMapIdOverride),
				Table(private.subZoneToParentZone)
		end
		MapOf = false
		if map and override and parent then
			-- An area's map, or its parent zone's; an override of 0 means the area has no map.
			MapOf = function(area)
				local found = override[area] or map[area]
				if found == nil and parent[area] then
					found = override[parent[area]] or map[parent[area]]
				end
				return type(found) == "number" and found ~= 0 and found or nil
			end
		end
		mapOf[db] = MapOf
	end
	if MapOf then
		return db, MapOf
	end
end

-- An NPC's name and one of its spawns: on the map of the zone QuestieDB names as its usual one, else on the lowest
-- map, and the first spawn there. Spawns are percentages of their area's map.
---@param db TFQuestieDB
---@param MapOf fun(area: integer): integer?
---@param npc integer
---@return TFNpcPlace|false
local function Read(db, MapOf, npc)
	local values = db.Npc.GetAll(npc, NPC_FIELDS)
	if not values or type(values[1]) ~= "string" then
		return false
	end
	local place = { name = values[1] }
	local home = type(values[3]) == "number" and MapOf(values[3]) or nil
	local best
	for area, spots in pairs(type(values[2]) == "table" and values[2] or {}) do
		local map = type(area) == "number" and MapOf(area) or nil
		local spot = map and type(spots) == "table" and spots[1]
		local x, y = spot and tonumber(spot[1]), spot and tonumber(spot[2])
		if map and x and y and x >= 0 and x <= 100 and y >= 0 and y <= 100 then
			-- One number to order by: the usual map first, then the lowest map, then the lowest area on it.
			local order = (map == home and 0 or 1e12) + map * 1e6 + area
			if not best or order < best then
				best, place.map, place.x, place.y = order, map, x / 100, y / 100
			end
		end
	end
	return place
end

local function Step()
	running = false
	local db, MapOf = Source.Zones()
	local started = debugprofilestop()
	while db and MapOf and #queue > 0 do
		local npc = table.remove(queue, 1) --[[@as integer]]
		queued[npc] = nil
		places[npc] = Read(db, MapOf, npc)
		if debugprofilestop() - started >= SLICE_MS then
			break
		end
	end
	if db and #queue > 0 then
		running = true
		C_Timer.After(0, Step)
	end
end

local function Pump()
	if open and not running and #queue > 0 then
		running = true
		C_Timer.After(0, Step)
	end
end

-- What QuestieDB knows of these NPCs so far, by NPC, and how far the read has got: "absent" without a QuestieDB this
-- addon can read, "pending" while any of them is still to be read, "ready" once all are. Asking books the read, a
-- millisecond a frame, so a caller asks again later; an NPC is read once a session.
---@param npcs integer[]
---@return table<integer, TFNpcPlace>
---@return "absent"|"pending"|"ready"
function Source.Places(npcs)
	local found = {}
	if not Source.Zones() then
		return found, "absent"
	end
	local state = "ready"
	for _, npc in ipairs(npcs) do
		local place = places[npc]
		if place then
			found[npc] = place
		elseif place == nil then
			state = "pending"
			if not queued[npc] then
				queued[npc] = true
				queue[#queue + 1] = npc
			end
		end
	end
	Pump()
	return found, state
end

ns.Init(function()
	local function Open()
		open = true
		Pump()
	end
	local api = Questie and Questie.API
	if api and api.RegisterOnReady then
		api.RegisterOnReady(Open)
		C_Timer.After(READY_WAIT, Open)
	else
		Open()
	end
end)
