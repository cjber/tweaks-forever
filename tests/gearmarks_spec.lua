-- Exercise Gear's bag marks: a group border is one slice per group in the group's colour across the quality
-- border, and the bags' new-item glow is no longer drawn over the slot. Frames and textures are stubbed, so the
-- render itself is checked in game.
local function noop() end
local initializer, drawer
local char = { groups = { DPS = { [100] = true }, Healing = { [100] = true } }, colours = {} }
local env = setmetatable({
	TweaksForeverCharDB = char,
	C_Container = {
		GetContainerItemID = function()
			return 100
		end,
	},
	-- A glow would be looked up here; a gear mark draws no atlas at all.
	C_Texture = {
		GetAtlasInfo = function(atlas)
			error("a gear mark draws no atlas: " .. tostring(atlas))
		end,
	},
	C_EquipmentSet = {
		GetEquipmentSetIDs = function()
			return {}
		end,
	},
	C_Timer = { After = noop },
	Enum = { TooltipDataType = { Item = 0 } },
	GetInventoryItemID = function()
		return nil
	end,
	INVSLOT_MAINHAND = 16,
	INVSLOT_OFFHAND = 17,
}, { __index = _G })
local ns = {
	Feature = noop,
	Init = function(fn)
		initializer = fn
	end,
	Active = function()
		return true
	end,
	On = noop,
	OnSettingChanged = noop,
	OnTooltip = noop,
	ClickMode = noop,
	EscapeCloses = noop,
	ForEachBagButton = noop,
	IsBagActionClick = function()
		return false
	end,
	HookBagButtons = function(draw)
		drawer = draw
	end,
	db = { gearMark = "border" },
	Fishing = {
		IsPole = function()
			return false
		end,
	},
}
assert(loadfile("Locales/enUS.lua"))("TweaksForever", ns)
setfenv(assert(loadfile("Bags/Gear.lua")), env)("TweaksForever", ns)
initializer()
assert(drawer, "the bag buttons take Gear's mark drawer")

local created = {}
local function texture(layer)
	local made = { layer = layer }
	function made:SetTexture(file)
		self.file = file
	end
	function made:SetVertexColor(...)
		self.colour = { ... }
	end
	function made:SetTexCoord(left, right, top, bottom)
		self.coords = { left, right, top, bottom }
	end
	function made:SetPoint(...)
		self.points = { ... }
	end
	function made:SetWidth(width)
		self.width = width
	end
	function made:SetHeight(height)
		self.height = height
	end
	function made:SetSize(width, height)
		self.width, self.height = width, height
	end
	function made:SetShown(shown)
		self.shown = shown
	end
	function made:Show()
		self.shown = true
	end
	function made:Hide()
		self.shown = false
	end
	function made:SetMask(mask)
		self.mask = mask
	end
	function made:SetBlendMode(mode)
		self.blend = mode
	end
	function made:SetDrawLayer(drawLayer, sub)
		self.layer, self.sub = drawLayer, sub
	end
	created[#created + 1] = made
	return made
end
local button = {
	IconBorder = {
		GetWidth = function()
			return 36
		end,
	},
	GetBagID = function()
		return 0
	end,
	GetID = function()
		return 1
	end,
	GetWidth = function()
		return 37
	end,
}
function button.CreateTexture(_, _, layer)
	return texture(layer)
end

drawer(button)
assert(#created == 2, "one border slice per group and nothing behind them")
for index, slice in ipairs(created) do
	assert(slice.layer == "OVERLAY", "a border slice sits over the quality border")
	assert(slice.file == "Interface\\Common\\WhiteIconFrame", "a slice draws the quality border's own file")
	assert(slice.blend == nil, "no glow blend over the slot")
	assert(slice.width == 18, "the slices share the quality border's width")
	assert(slice.shown)
	local left, right = slice.coords[1], slice.coords[2]
	assert(left == (index - 1) / 2 and right == index / 2, "the slices split the border between the groups")
end

-- The pool is reused: drawing again takes no new textures and leaves the same two slices.
drawer(button)
assert(#created == 2, "a refresh reuses the slices")

-- A strip mark is still a flat colour, with no atlas behind it either.
ns.db.gearMark = "strip"
drawer(button)
assert(#created == 5, "a strip is its backing and one segment per group")
assert(created[3].file == "Interface\\Buttons\\WHITE8X8", "the strip's backing is a flat colour")
assert(created[3].layer == "ARTWORK" and created[3].blend == nil, "the strip draws nothing over the slot")

print("gear marks: group border slices, no new-item glow, reused pool and strip: ok")
