-- QuestieDB read in game: what a caller sees with it installed, without it, and while Questie is still starting.
-- The library here is synthetic: made-up NPCs on made-up maps. Area 10 is map 100, area 11 is a subzone of area 10,
-- area 20 is map 50 and area 12 has its map switched off.
local npcs = {
	[1] = { name = "Ada", spawns = { [10] = { { 25, 75 }, { 1, 1 } }, [20] = { { 40, 60 } } }, zoneID = 10 },
	[2] = { name = "Bo", spawns = { [10] = { { 25, 75 } }, [20] = { { 40, 60 } } } }, -- no usual zone: the lowest map
	[3] = { name = "Cy", spawns = { [11] = { { 50, 50 } } }, zoneID = 11 }, -- a subzone, drawn on its parent's map
	[4] = { name = "Di", spawns = { [12] = { { 50, 50 } }, [10] = { { -1, -1 } } } }, -- nowhere it can be drawn
	[5] = { name = "Ed" },
	[6] = { name = "Flo", spawns = { [20] = { { 10, 20 } } } },
}
local reads, clock, flavour = 0, 0, "Forever"
local library = {
	RequireContract = function(required)
		return required == 2
	end,
	Npc = {
		GetAll = function(id, keys)
			reads, clock = reads + 1, clock + 0.4 -- each read costs 0.4 ms, so three fit a frame's millisecond
			local row = npcs[id]
			if not row then
				return nil
			end
			local values = {}
			for i, key in ipairs(keys) do
				values[i] = row[key]
			end
			return values
		end,
	},
	Support = {
		Get = function(name)
			assert(name == "ZoneDB")
			return {
				private = {
					areaIdToUiMapId = "return { [10] = 100, [12] = 200, [20] = 50 }",
					areaIdToUiMapIdOverride = "return { [12] = 0 }",
					subZoneToParentZone = "return { [11] = 10 }",
				},
			}
		end,
	},
}

---@param questie table? the Questie global, when it is installed
---@return table source, table world
local function Load(questie)
	local world = { timers = {}, library = library }
	local inits = {}
	local ns = {
		Init = function(fn)
			inits[#inits + 1] = fn
		end,
	}
	local env = setmetatable({
		Questie = questie,
		C_AddOns = {
			GetAddOnMetadata = function(addon, field)
				assert(addon == "QuestieDB" and field == "X-Flavor")
				return flavour
			end,
		},
		C_Timer = {
			After = function(seconds, fn)
				table.insert(world.timers, { seconds = seconds, fn = fn })
			end,
		},
		debugprofilestop = function()
			return clock
		end,
	}, {
		__index = function(_, key)
			if key == "LibQuestieDB" then
				return world.library
			end
			return _G[key]
		end,
	})
	setfenv(assert(loadfile("Integrations/QuestieSource.lua")), env)("TweaksForever", ns)
	-- One frame: every timer due on the next frame runs once; a longer one waits for Later.
	function world.Frame()
		local due = world.timers
		world.timers = {}
		for _, timer in ipairs(due) do
			if timer.seconds == 0 then
				timer.fn()
			else
				table.insert(world.timers, timer)
			end
		end
	end
	function world.Later()
		local due = world.timers
		world.timers = {}
		for _, timer in ipairs(due) do
			timer.fn()
		end
	end
	function world.Login()
		for _, init in ipairs(inits) do
			init()
		end
	end
	return ns.QuestieSource, world
end

local function Count(t)
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n
end

-- Present: asking books the read and answers at once with what is known so far, which is nothing yet.
local Source, world = Load()
world.Login()
local ids = { 1, 2, 3, 4, 5, 6, 99 }
local places, state = Source.Places(ids)
assert(state == "pending" and next(places) == nil and reads == 0, "nothing is read in the caller's frame")
assert(#world.timers == 1, "one frame booked")
-- A millisecond a frame: three of these reads, never the whole list at once.
world.Frame()
assert(reads == 3, "three reads in the first frame: " .. reads)
places, state = Source.Places(ids)
assert(state == "pending" and Count(places) == 3, "what has been read is given while the rest is pending")
assert(#world.timers == 1, "asking again books no second frame")
world.Frame()
world.Frame()
assert(reads == 7 and #world.timers == 0, "all read, and nothing left running: " .. reads)
places, state = Source.Places(ids)
assert(state == "ready")
-- The usual zone's map wins, then the lowest map, and the first spawn there, as fractions of the map.
assert(places[1].name == "Ada" and places[1].map == 100 and places[1].x == 0.25 and places[1].y == 0.75)
assert(places[2].map == 50 and places[2].x == 0.4 and places[2].y == 0.6, "no usual zone: the lowest map")
assert(places[3].map == 100 and places[3].x == 0.5, "a subzone is drawn on its parent zone's map")
assert(places[4].name == "Di" and places[4].map == nil, "a switched-off map and a spawn off the map place nothing")
assert(places[5].name == "Ed" and places[5].map == nil, "no spawns: a name and no place")
assert(places[6].map == 50)
assert(places[99] == nil, "an NPC QuestieDB doesn't have")
-- Kept for the session: nothing is read twice, the missing NPC included.
Source.Places(ids)
world.Frame()
assert(reads == 7 and #world.timers == 0, "cached for the session")
assert(Source.Places(ids) ~= places, "a fresh table each call")

-- Absent: no library, the wrong flavour, a contract it doesn't meet or zone tables that can't be read. Nothing is
-- booked and nothing is read.
reads = 0
Source, world = Load()
world.Login()
for name, absent in pairs({
	missing = function()
		world.library = nil
	end,
	flavour = function()
		flavour = "Vanilla"
	end,
	contract = function()
		world.library = setmetatable({ RequireContract = error }, { __index = library })
	end,
	zones = function()
		world.library = setmetatable({
			Support = {
				Get = function()
					return { private = { areaIdToUiMapId = "return {" } }
				end,
			},
		}, { __index = library })
	end,
}) do
	absent()
	places, state = Source.Places(ids)
	assert(state == "absent" and next(places) == nil, name)
	assert(#world.timers == 0 and reads == 0, name .. ": nothing booked")
	world.library, flavour = library, "Forever"
end
-- Installed later in the session (a load-on-demand copy): the next ask reads it.
assert(select(2, Source.Places({ 1 })) == "pending")
world.Frame()
assert(select(2, Source.Places({ 1 })) == "ready")

-- Not ready: Questie is installed and still starting, so the read waits for it to say it is ready.
reads = 0
local onReady
Source, world = Load({
	API = {
		RegisterOnReady = function(fn)
			onReady = fn
		end,
	},
})
assert(select(2, Source.Places({ 1 })) == "pending" and #world.timers == 0, "before login nothing is booked")
world.Login()
assert(#world.timers == 1 and world.timers[1].seconds == 60, "only the fallback is waiting")
world.Frame()
assert(reads == 0 and select(2, Source.Places({ 1 })) == "pending", "held while Questie starts")
onReady()
world.Frame()
places, state = Source.Places({ 1 })
assert(state == "ready" and places[1].map == 100, "read once Questie is ready")
-- A Questie that never reports ready does not hold the read for ever: it goes ahead after a minute.
reads = 0
Source, world = Load({ API = { RegisterOnReady = function() end } })
world.Login()
Source.Places({ 6 })
world.Frame()
assert(reads == 0, "still held")
world.Later()
world.Frame()
places, state = Source.Places({ 6 })
assert(state == "ready" and places[6].map == 50, "read after the wait")
print("questiesource: ok")
