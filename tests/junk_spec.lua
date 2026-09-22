local features, initializers = {}, {}
local ns = {
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
}
assert(loadfile("Junk.lua"))("TweaksForever", ns)
local Model = ns.Junk
assert(features.markJunk.default == false and features.sellJunk.default == true)
assert(#initializers == 1)
for _, conflict in ipairs(features.sellJunk.conflicts) do
	assert(conflict.addon ~= "Leatrix_Plus", "Leatrix's grey-only conflict must stay partial")
end

local marks = {}
assert(Model.Toggle(marks, 100))
assert(marks[100] == true)
assert(not Model.Toggle(marks, 100))
assert(marks[100] == nil)
marks[100] = true

local function item(quality, id, count)
	return { itemID = id or 100, quality = quality, stackCount = count or 2, hyperlink = "item:100:variant" }
end

assert(Model.SaleValue(item(0), 7, {}, true) == 14)
assert(not Model.SaleValue(item(0), 7, marks, false), "even marked greys belong to Leatrix")
assert(Model.SaleValue(item(2), 7, marks, false) == 14)
assert(not Model.SaleValue(item(2, 101), 7, marks, true))
assert(not Model.SaleValue(item(nil), 7, marks, true), "unknown quality must not bypass grey ownership")
assert(not Model.SaleValue(nil, 7, marks, true))
assert(not Model.SaleValue(item(0), nil, marks, true))
assert(not Model.SaleValue(item(0), 0, marks, true))
assert(not Model.SaleValue(item(0), -1, marks, true))
assert(not Model.SaleValue(item(0, 100, 0), 7, marks, true))
local locked = item(0)
locked.isLocked = true
assert(not Model.SaleValue(locked, 7, marks, true))
local worthless = item(0)
worthless.hasNoValue = true
assert(not Model.SaleValue(worthless, 7, marks, true))

local original = item(2)
assert(Model.SameStack(original, item(2)))
assert(not Model.SameStack(original, nil))
assert(not Model.SameStack(original, item(2, 101)))
assert(not Model.SameStack(original, item(2, 100, 3)))
assert(not Model.SameStack(original, locked))
local changed = item(2)
changed.hyperlink = "item:100:different-enchant"
assert(not Model.SameStack(original, changed), "same item ID does not guarantee the same item variant")
print("junk_spec: ok")
