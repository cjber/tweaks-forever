local printed, waypoints, superTracked, journeys = {}, {}, {}, {}
local ns = {
	Print = function(message)
		printed[#printed + 1] = message
	end,
}

local canSet, accepts = true, true
local env = setmetatable({
	C_Map = {
		CanSetUserWaypointOnMap = function()
			return canSet
		end,
		SetUserWaypoint = function(point)
			waypoints[#waypoints + 1] = point
		end,
		GetMapInfo = function()
			return { name = "Searing Gorge" }
		end,
	},
	C_SuperTrack = {
		SetSuperTrackedUserWaypoint = function(on)
			superTracked[#superTracked + 1] = on
		end,
	},
	UiMapPoint = {
		CreateFromCoordinates = function(map, x, y)
			return { uiMapID = map, x = x, y = y }
		end,
	},
}, { __index = _G })

local function Install(version)
	env.ShortestPathForever = {
		API = {
			version = version,
			Navigate = function(owner, map, x, y, title)
				journeys[#journeys + 1] = { owner = owner, map = map, x = x, y = y, title = title }
				return accepts
			end,
		},
	}
end

assert(loadfile("Locales/enUS.lua"))("TweaksForever", ns)
setfenv(assert(loadfile("Navigate.lua")), env)("TweaksForever", ns)

-- Shortest Path present and accepting: it alone guides, with the entrance's own map, place and name.
Install(1)
assert(ns.NavigateHint() == "Click to travel here with Shortest Path Forever")
ns.Navigate(1427, 0.35, 0.84, "Blackrock Mountain")
local journey = journeys[1]
assert(journey.owner == "TweaksForever" and journey.map == 1427 and journey.x == 0.35 and journey.y == 0.84)
assert(journey.title == "Blackrock Mountain")
assert(#waypoints == 0 and #superTracked == 0 and #printed == 0)

-- Shortest Path declining (combat, journeys off, no position): the game's super-tracked waypoint instead.
accepts = false
ns.Navigate(1427, 0.35, 0.84, "Blackrock Mountain")
assert(#journeys == 2 and #waypoints == 1 and superTracked[1] == true)
assert(waypoints[1].uiMapID == 1427 and waypoints[1].x == 0.35 and waypoints[1].y == 0.84)

-- Shortest Path absent, or a major version this addon does not know: the waypoint, and a hint that says so.
env.ShortestPathForever = nil
assert(ns.NavigateHint() == "Click to set a waypoint here")
ns.Navigate(1427, 0.35, 0.84, "Blackrock Mountain")
assert(#journeys == 2 and #waypoints == 2)
Install(2)
ns.Navigate(1427, 0.35, 0.84, "Blackrock Mountain")
assert(#journeys == 2 and #waypoints == 3)

-- A version-1 API without Navigate, or the addon without its API: the waypoint, never an error.
env.ShortestPathForever = { API = { version = 1 } }
assert(ns.NavigateHint() == "Click to set a waypoint here")
ns.Navigate(1427, 0.35, 0.84, "Blackrock Mountain")
env.ShortestPathForever = {}
ns.Navigate(1427, 0.35, 0.84, "Blackrock Mountain")
assert(#journeys == 2 and #waypoints == 5)

-- A map that takes no waypoint: the place goes to chat rather than nowhere.
env.ShortestPathForever, canSet = nil, false
ns.Navigate(1427, 0.35, 0.84, "Blackrock Mountain")
assert(#waypoints == 5 and printed[1] == "Blackrock Mountain is at 35.0, 84.0 in Searing Gorge.", printed[1])
print("navigate: ok")
