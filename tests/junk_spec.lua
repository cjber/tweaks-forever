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
-- The coin drawn over a bag button takes the game's junk coin's layer and sublevel, each in its own slot.
local update
ns.Active = function()
	return true
end
ns.ClickMode, ns.OnTooltip, ns.On, ns.ForEachBagButton = function() end, function() end, function() end, function() end
ns.HookBagButtons = function(_, fn)
	update = fn
end
_G.Enum = { TooltipDataType = { Item = 0 } }
_G.hooksecurefunc = function() end
_G.MerchantSellAllJunkButton = { HookScript = function() end }
_G.TweaksForeverDB = { junk = { [100] = true } }
_G.C_Container = {
	GetContainerItemInfo = function()
		return item(2)
	end,
}
initializers[1]()
local drawn
local button = {
	JunkIcon = {
		GetDrawLayer = function()
			return "OVERLAY", 5
		end,
		GetAtlas = function()
			return "bags-junkcoin"
		end,
	},
	GetBagID = function()
		return 0
	end,
	GetID = function()
		return 1
	end,
	CreateTexture = function(_, name, layer, inherits, sublevel)
		assert(
			inherits == nil or type(inherits) == "string",
			('Couldn\'t find inherited node "%s"'):format(tostring(inherits))
		)
		assert(name == nil and layer == "OVERLAY" and sublevel == 5, "the coin keeps the junk coin's draw layer")
		drawn = {
			SetAtlas = function() end,
			SetAllPoints = function() end,
			SetShown = function(_, shown)
				drawn.shown = shown
			end,
		}
		return drawn
	end,
}
update(button)
assert(drawn and drawn.shown, "a marked item shows the coin")
print("junk_spec: ok")
