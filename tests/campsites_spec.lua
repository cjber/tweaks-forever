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

-- Aura updates: only watched auras count, and a removal is known by the instance it was added as.
local CAMPFIRE_NEARBY = 1283391
local instances = {}
assert(not Camp.Touches({ addedAuras = { { spellId = 774, auraInstanceID = 1 } } }, instances))
assert(Camp.Touches({ addedAuras = { { spellId = CAMPFIRE_NEARBY, auraInstanceID = 2 } } }, instances))
assert(instances[2] and not instances[1])
assert(not Camp.Touches({ updatedAuraInstanceIDs = { 1 } }, instances))
assert(Camp.Touches({ updatedAuraInstanceIDs = { 1, 2 } }, instances), "the campfire's refresh re-draws times")
assert(not Camp.Touches({ removedAuraInstanceIDs = { 1 } }, instances))
assert(Camp.Touches({ removedAuraInstanceIDs = { 2 } }, instances) and not instances[2])
print("campsites: ok")
