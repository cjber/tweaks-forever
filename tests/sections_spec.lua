local features = {}
local ns = {
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function() end,
}
assert(loadfile("Sections.lua"))("TweaksForever", ns)
local Model = ns.Sections
assert(features.gearSections.parent == "gearGroups")

-- Seven items in Blizzard's order, four columns: 2 and 5 are in A, 6 in B, the rest stay in the grid.
local items = { {}, { section = "A" }, {}, {}, { section = "A" }, { section = "B" }, {} }
local places, headings, height = Model.Layout(items, { "A", "B" }, 4)
local function at(index)
	return places[index].column .. "," .. places[index].y
end
-- The rest keeps Blizzard's bottom-right-first grid, now one full row.
assert(at(1) == "0,0" and at(3) == "1,0" and at(4) == "2,0" and at(7) == "3,0")
-- B sits above it after the gap, filling from the left; A above B's heading.
assert(at(6) == "3,48", at(6))
assert(at(2) == "3,106" and at(5) == "2,106", at(2) .. " " .. at(5))
assert(headings[1].section == "B" and headings[1].y == 90)
assert(headings[2].section == "A" and headings[2].y == 148)
assert(height == 164, height)

-- No sections leaves Blizzard's grid and height untouched.
places, headings, height = Model.Layout({ {}, {}, {}, {}, {} }, {}, 4)
assert(#headings == 0 and height == 84 and places[5].column == 0 and places[5].y == 42)
print("sections: ok")
