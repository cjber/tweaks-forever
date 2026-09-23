local ns = { Feature = function() end, Init = function() end }
local env = setmetatable({}, { __index = _G })
setfenv(assert(loadfile("Data/CampBenefits.lua")), env)("TweaksForever", ns)
setfenv(assert(loadfile("Campsites.lua")), env)("TweaksForever", ns)
local Camp = ns.Camp

-- The list: benefits you have first, then the rest, each in the game's order.
local TENT, MANA_WELL, FIRST_AID, BANNER = 1229451, 1230587, 1230124, 1229718
local have = { [FIRST_AID] = 1200, [TENT] = 0 }
local rows = Camp.Listing(function(aura)
	return have[aura]
end)
assert(#rows == #ns.CampBenefits)
assert(rows[1].benefit[1] == TENT and rows[1].left == 0, "the tent comes first in the game's order")
assert(rows[2].benefit[1] == FIRST_AID and rows[2].left == 1200)
assert(rows[3].benefit[1] == MANA_WELL and rows[3].left == nil, "then what you don't have")
assert(rows[#rows].benefit[1] == BANNER)

-- Directions: bearings run counter-clockwise from north, as the player's facing does.
local pi = math.pi
assert(Camp.Toward(40, 0, 0) == "Campfire: about 40 yd ahead")
assert(Camp.Toward(0, 30, 0) == "Campfire: about 30 yd to your left", "west is left facing north")
assert(Camp.Toward(0, 30, pi / 2) == "Campfire: about 30 yd ahead", "facing west")
assert(Camp.Toward(-20, -20, 0) == "Campfire: about 30 yd behind you to the right")
assert(Camp.Toward(3, 3, 1) == "Campfire: right here")
print("campsites: ok")
