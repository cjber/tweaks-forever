local ns = {
	Feature = function() end,
	Init = function() end,
}
assert(loadfile("Sections.lua"))("TweaksForever", ns)
assert(loadfile("Reagents.lua"))("TweaksForever", ns)
local Model = ns.Reagents

-- Ten columns: slot 1 at the top left under the heading, slot 10 at the top right, slot 11 starting the next row.
local function at(slot)
	local x, y = Model.Place(slot, 10)
	return x .. "," .. y
end
assert(at(1) == "-378,-16", at(1))
assert(at(10) == "0,-16", at(10))
assert(at(11) == "-378,-58", at(11))
-- The heading and one row per ten slots, a partial row counting whole.
assert(Model.Height(10, 10) == 58 and Model.Height(12, 10) == 100)
print("reagents: ok")
