-- Run from the repository root: luajit tests/art_spec.lua
-- Art.lua on its own, with a stub C_Texture.GetAtlasInfo and a stub texture: an atlas fits its box at its own
-- aspect, and its markup takes its width from that aspect.
local SIZES = { wide = { 209, 46 }, tall = { 16, 18 } }
local env = setmetatable({
	C_Texture = {
		GetAtlasInfo = function(atlas)
			local size = SIZES[atlas]
			return size and { width = size[1], height = size[2] }
		end,
	},
}, { __index = _G })
local ns = {}
setfenv(assert(loadfile("UI/Art.lua")), env)("TweaksForever", ns)
local Art = ns.Art

local texture = {}
function texture:SetAtlas(atlas)
	self.atlas = atlas
end
function texture:SetSize(width, height)
	self.width, self.height = width, height
end

local function near(actual, expected)
	return math.abs(actual - expected) < 1e-6
end

local width, height = Art.Fit(texture, "tall", 20, 20)
assert(texture.atlas == "tall" and texture.width == width and texture.height == height)
assert(height == 20 and near(width / height, 16 / 18), "a tall atlas fills the box's height")
width, height = Art.Fit(texture, "wide", 22, 25)
assert(width == 22 and near(width / height, 209 / 46), "a wide atlas fills the box's width")
width, height = Art.Fit(texture, "unknown", 14, 18)
assert(width == 14 and height == 14, "an unknown atlas is square, inside the box")

assert(Art.Markup("tall", 16) == "|A:tall:16:14|a", "the width from the aspect")
assert(Art.Markup("unknown", 14) == "|A:unknown:14:14|a", "an unknown atlas is square")
print("art: fit and markup keep the atlas's aspect")
