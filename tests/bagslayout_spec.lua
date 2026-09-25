-- The combined bag's layout pass (Sections.lua, Reagents.lua) runs only after Blizzard's own and never calls Blizzard's
-- layout: folds the reagent bag in, adds sections, undoes each exactly, and leaves the bag alone when both are off.
-- luacheck: ignore 212/self (stub methods mirror the frame API)
local function Region(props)
	local r = props or {}
	r.points, r.shown, r.scale, r.height, r.alpha = {}, r.shown ~= false, r.scale or 1, r.height or 100, 1
	function r:SetPoint(p, rel, rp, x, y)
		self.points = { p, rel, rp, x or 0, y or 0 }
	end
	function r:GetPoint()
		return unpack(self.points, 1, 5)
	end
	function r:ClearAllPoints()
		self.points = {}
	end
	function r:SetAllPoints() end
	function r:Show()
		self.shown = true
	end
	function r:Hide()
		self.shown = false
	end
	function r:SetShown(v)
		self.shown = not not v
	end
	function r:IsShown()
		return self.shown
	end
	function r:SetHeight(h)
		self.height = h
	end
	function r:GetHeight()
		return self.height
	end
	function r:SetScale(s)
		self.scale = s
	end
	function r:GetScale()
		return self.scale
	end
	function r:SetAlpha(a)
		self.alpha = a
	end
	function r:GetAlpha()
		return self.alpha
	end
	function r:EnableMouse() end
	function r:IsMouseEnabled()
		return true
	end
	function r:SetParent(p)
		self.parent = p
	end
	function r:GetParent()
		return self.parent
	end
	function r:SetFrameStrata() end
	function r:GetFrameStrata()
		return "MEDIUM"
	end
	function r:SetFrameLevel() end
	function r:GetFrameLevel()
		return 1
	end
	function r:SetColorTexture() end
	function r:SetVertexColor() end
	function r:SetText(t)
		self.text = t
	end
	function r:SetTextColor() end
	function r:CreateTexture()
		return Region()
	end
	function r:CreateFontString()
		return Region()
	end
	function r:SetScript() end
	function r:RegisterEvent() end
	function r:UnregisterEvent() end
	function r:GetChildren()
		return
	end
	function r:GetRegions()
		return
	end
	return r
end

local function Buttons(bagIDs, perBag, owner)
	local items = {}
	for _, bagID in ipairs(bagIDs) do
		for slot = 1, perBag do
			local b = Region()
			function b:GetBagID()
				return bagID
			end
			function b:GetID()
				return slot
			end
			function b:IsExtended()
				return false
			end
			b.GetSlotAndBagID = function() end
			b:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -slot, bagID)
			items[#items + 1] = b
		end
	end
	return items
end

local bag = Region({ height = 300, scale = 0.9 })
bag.MoneyFrame = Region()
bag.Items = Buttons({ 0, 1 }, 10, bag)
bag.size = #bag.Items
function bag:GetColumns()
	return 10
end
local reagents = Region({ height = 120 })
reagents.Items = Buttons({ 5 }, 12, reagents)
reagents.size = 12
function reagents:GetBagID()
	return 5
end
reagents:SetPoint("BOTTOMRIGHT", bag, "BOTTOMLEFT", -11, 0)

local hooks, inits, settings = {}, {}, {}
local db = { gearGroups = true, gearSections = true, combinedReagents = true }
local ns = {
	Feature = function() end,
	Init = function(fn)
		inits[#inits + 1] = fn
	end,
	Active = function(key)
		return db[key]
	end,
	BagSize = function(c)
		return c.size
	end,
	BagItems = function(c)
		local i = 0
		return function()
			i = i + 1
			if i <= c.size then
				return i, c.Items[i]
			end
		end
	end,
	Gear = {
		MarksOf = function(itemID)
			return itemID % 3 == 0 and { { kind = "group", name = "Tank" } } or {}
		end,
		ColourOf = function()
			return { 1, 1, 1 }
		end,
		OnRefresh = function() end,
		Settling = function()
			return false
		end,
	},
}
local env = setmetatable({
	C_Container = {
		GetContainerItemID = function(b, s)
			return b * 100 + s
		end,
	},
	InputUtil = {
		IsGamepadUIEnabled = function()
			return false
		end,
	},
	GetScreenHeight = function()
		return 1000
	end,
	CONTAINER_OFFSET_Y = 70,
	NineSliceUtil = { UpdateCornerCropping = function() end },
	hooksecurefunc = function(name, fn)
		assert(type(name) == "string", "global hooks only")
		hooks[name] = fn
	end,
	Settings = {
		SetOnValueChangedCallback = function(v, fn)
			settings[v] = fn
		end,
	},
	EventRegistry = {
		RegisterCallback = function(_, name, fn)
			hooks[name] = fn
		end,
	},
	CreateFrame = function()
		return Region()
	end,
	ContainerFrameCombinedBags = bag,
	ContainerFrame6 = reagents,
	ContainerFrame_IsReagentBag = function(id)
		return id == 5
	end,
	ContainerFrameSettingsManager = {
		IsUsingCombinedBags = function()
			return true
		end,
	},
	C_Timer = {
		After = function(_, fn)
			fn()
		end,
	},
	GetBindingKey = function() end,
	ClearOverrideBindings = function() end,
	SetOverrideBinding = function() end,
	InCombatLockdown = function()
		return false
	end,
}, { __index = _G })
for _, file in ipairs({ "Sections.lua", "Reagents.lua" }) do
	setfenv(assert(loadfile(file)), env)("TweaksForever", ns)
end
for _, fn in ipairs(inits) do
	fn()
end

local Anchors = hooks.UpdateContainerFrameAnchors
-- Blizzard lays the bag out and anchors it.
Anchors()
local lift = ns.Sections.lift
assert(lift == ns.Reagents.Lift(12, 10), "reagents fold in: " .. lift)
assert(reagents:GetParent() == bag, "reagent window moves into the bag")
assert(select(2, reagents:GetPoint()) == bag.MoneyFrame)
assert(select(2, reagents.Items[1]:GetPoint()) == bag.MoneyFrame, "reagent buttons sit on the money frame")
local grown = bag:GetHeight()
assert(grown > 300 + lift, "bag grows for reagents and sections: " .. grown)
-- Anchoring again without a new size keeps Blizzard's base, not the grown height.
Anchors()
assert(bag:GetHeight() == grown, "no double growth: " .. bag:GetHeight())
-- Sections off: only the reagent lift remains.
db.gearSections = false
settings.TweaksForever_gearSections()
assert(bag:GetHeight() == 300 + lift, "sections undone: " .. bag:GetHeight())
-- Reagents off: back to Blizzard's height, window and buttons where Blizzard put them.
db.combinedReagents = false
settings.TweaksForever_combinedReagents()
assert(bag:GetHeight() == 300, "back to Blizzard's height: " .. bag:GetHeight())
assert(select(2, reagents:GetPoint()) == bag, "window back beside the bag")
assert(select(2, reagents.Items[1]:GetPoint()) == reagents, "buttons back in their window")
assert(reagents:GetScale() == 1)
-- Everything off: a fresh Blizzard pass is left alone.
bag.Items[1]:SetPoint("BOTTOMRIGHT", bag, "BOTTOMRIGHT", -99, -99)
Anchors()
assert(select(4, bag.Items[1]:GetPoint()) == -99, "untouched when nothing is on")
-- A tall bag shrinks to fit, never below Blizzard's smallest scale.
db.gearSections, db.combinedReagents = true, true
bag.height = 700
Anchors()
local fits = bag:GetHeight() * bag:GetScale() + 70 <= 1000 + 1e-6
assert(fits or bag:GetScale() == 0.75, "fits on screen: " .. bag:GetHeight() .. " x " .. bag:GetScale())
-- Closing the reagent bag while folded.
assert(reagents:GetParent() == bag)
reagents:Hide()
hooks["ContainerFrame.CloseBag"](nil, reagents)
assert(reagents:GetParent() ~= bag, "unfolded on close")
print("bagslayout: ok")
