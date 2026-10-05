local features, initializers = {}, {}
local active = false
local ns = {
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
	Active = function(key)
		assert(features[key], "unknown feature")
		return active
	end,
}
local hooked = {}
local owners = {}
local env = setmetatable({
	hooksecurefunc = function(name, fn)
		hooked[name] = fn
	end,
	GameTooltip = {
		SetOwner = function(_, owner, point)
			owners[#owners + 1] = { owner = owner, point = point }
		end,
	},
}, { __index = _G })
setfenv(assert(loadfile("UI/CursorTooltip.lua")), env)("TweaksForever", ns)
assert(features.cursorTooltips.default == false and features.cursorTooltips.category == "Interface")
initializers[1]()
local anchor = assert(hooked.GameTooltip_SetDefaultAnchor, "the default anchor must be hooked")
-- A unit frame or action button owns the tooltip: the hook may pass the owner on but must never read or write it.
local parent = setmetatable({}, {
	__index = function()
		error("the tooltip owner is read")
	end,
	__newindex = function()
		error("the tooltip owner is written")
	end,
})
anchor(env.GameTooltip, parent)
assert(#owners == 0, "off: the game's own default anchor is left alone")
active = true
anchor(env.GameTooltip, parent)
assert(#owners == 1 and owners[1].owner == parent, "on: the game tooltip follows the cursor")
assert(owners[1].point == "ANCHOR_CURSOR", "the client's own cursor anchor is used")
-- A window that places its own tooltip, such as a bag item's, never reaches the default anchor.
local other = {
	SetOwner = function()
		error("a window's own tooltip is left alone")
	end,
}
anchor(other, parent)
assert(#owners == 1, "only the game tooltip is re-anchored")
print("cursortooltip: the game tooltip follows the cursor")
