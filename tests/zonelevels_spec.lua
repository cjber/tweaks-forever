local features, initializers = {}, {}
local ns = {
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
}
local clientLevels = {}
local env = setmetatable({
	C_Map = {
		GetMapLevels = function(mapID)
			local range = clientLevels[mapID]
			if range then
				return range[1], range[2], 0, 0
			end
			return 0, 0, 0, 0
		end,
	},
}, { __index = _G })
assert(loadfile("Data/ZoneLevels.lua"))("TweaksForever", ns)
setfenv(assert(loadfile("ZoneLevels.lua")), env)("TweaksForever", ns)
local Model = ns.ZoneLevels
assert(#initializers == 1 and features.zoneLevels.default == true)

-- Leatrix Maps shows zone levels unless its option is explicitly off.
local leatrix = features.zoneLevels.conflicts[1]
assert(leatrix.addon == "Leatrix_Maps" and leatrix.when())
env.LeaMapsDB = { ShowZoneLevels = "Off" }
assert(not leatrix.when())
env.LeaMapsDB.ShowZoneLevels = "On"
assert(leatrix.when())

-- The published range stands in for the client's empty one; the client's wins once it has one.
local low, high = Model.Range(1439)
assert(low == 10 and high == 20, "Darkshore")
clientLevels[1439] = { 12, 22 }
low, high = Model.Range(1439)
assert(low == 12 and high == 22)
assert(Model.Range(1454) == nil, "cities have no range")

assert(Model.Text(10, 20) == "10-20" and Model.Text(60, 60) == "60")

-- Blizzard's hover-label rule: bottom of a zone above you, your level inside, two under the top below you.
assert(Model.ChallengeLevel(5, 10, 20) == 10)
assert(Model.ChallengeLevel(15, 10, 20) == 15)
assert(Model.ChallengeLevel(10, 10, 20) == 10 and Model.ChallengeLevel(20, 10, 20) == 20)
assert(Model.ChallengeLevel(30, 10, 20) == 18)
print("zonelevels: ok")
