local ns = {
	Feature = function() end,
	Init = function() end,
}
assert(loadfile("Sections.lua"))("TweaksForever", ns)
assert(loadfile("Reagents.lua"))("TweaksForever", ns)
local Model = ns.Reagents

-- A 16-slot bag in ten columns: slot 1 at the top left, slot 11 starting the bottom row on the money frame.
local function at(slot)
	local column, y = Model.Place(slot, 16, 10)
	return column .. "," .. y
end
assert(at(1) == "9,46", at(1))
assert(at(10) == "0,46", at(10))
assert(at(11) == "9,4", at(11))
assert(at(16) == "4,4", at(16))
-- One row per ten slots, a partial row counting whole, plus the gap under the rest of the bag.
assert(Model.Lift(10, 10) == 48 and Model.Lift(12, 10) == 90)
print("reagents: ok")
