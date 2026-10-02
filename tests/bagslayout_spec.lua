-- The combined bag's layout pass (Bags/CombinedBag.lua) with both of its parts, driven as the client drives it:
-- Blizzard's anchor update, a setting change, a gear refresh and the reagent bag closing.
-- It folds the reagent bag in, then adds sections above it, undoes each exactly, leaves the bag alone when both are
-- off, grows from Blizzard's height rather than its own, and waits for settling weapons.
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
	function r:IsShown()
		return self.shown
	end
	function r:SetHeight(h)
		self.height = h
	end
	function r:GetHeight()
		return self.height + (self.drift or 0)
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
bag:SetPoint("BOTTOMRIGHT", nil, "BOTTOMRIGHT", -9, 90)
bag.Items = Buttons({ 0, 1 }, 10, bag)
bag.size = #bag.Items
function bag:GetColumns()
	return 10
end
local rule
function bag:CreateTexture()
	rule = Region()
	return rule
end
local reagents = Region({ height = 120 })
reagents.Items = Buttons({ 5 }, 12, reagents)
reagents.size = 12
function reagents:GetBagID()
	return 5
end
reagents:SetPoint("BOTTOMRIGHT", bag, "BOTTOMLEFT", -11, 0)

local hooks, inits, settings = {}, {}, {}
local settling, screen, Refreshed = false, 1000, nil
local db = { gearGroups = true, gearSections = true, combinedReagents = true }
local ns = {
	Feature = function() end,
	Init = function(fn)
		inits[#inits + 1] = fn
	end,
	Active = function(key)
		return db[key]
	end,
	OnSettingChanged = function(key, fn)
		settings[key] = fn
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
		OnRefresh = function(fn)
			Refreshed = fn
		end,
		Settling = function()
			return settling
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
		return screen
	end,
	CONTAINER_OFFSET_Y = 70,
	NineSliceUtil = { UpdateCornerCropping = function() end },
	hooksecurefunc = function(name, fn)
		assert(type(name) == "string", "global hooks only")
		hooks[name] = fn
	end,
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
for _, file in ipairs({ "Bags/CombinedBag.lua", "Bags/Sections.lua", "Bags/Reagents.lua" }) do
	setfenv(assert(loadfile(file)), env)("TweaksForever", ns)
end
for _, fn in ipairs(inits) do
	fn()
end

local Anchors = hooks.UpdateContainerFrameAnchors
local money = bag.MoneyFrame
-- A region's place on the money frame as "x,y", or nil when it is anchored elsewhere.
local function at(region)
	local _, relative, _, x, y = region:GetPoint()
	return relative == money and (x + 0) .. "," .. y or nil -- -0 + 0 is 0
end

-- Blizzard lays the bag out and anchors it. Twelve reagent slots in ten columns: two rows and the gap lift the rest.
Anchors()
local lift = 2 * 42 + 6
assert(reagents:GetParent() == bag, "reagent window moves into the bag")
assert(at(reagents) == "0,0" and reagents:GetScale() == 1, "reagent window sits on the money frame")
-- Slot 1 at the top left, slot 11 starting the bottom row on the money frame.
assert(at(reagents.Items[1]) == "-378,46", at(reagents.Items[1]))
assert(at(reagents.Items[10]) == "0,46", at(reagents.Items[10]))
assert(at(reagents.Items[11]) == "-378,4", at(reagents.Items[11]))
assert(at(reagents.Items[12]) == "-336,4", at(reagents.Items[12]))
-- The rest of the bag starts above the lift, under a rule in the gap: the last bag's last slot at the bottom right.
assert(at(bag.Items[20]) == "0," .. 4 + lift, at(bag.Items[20]))
assert(rule:IsShown() and select(5, rule:GetPoint()) == 4 + lift - 6, "rule between reagents and the rest")
-- Six of the twenty items are grouped: the rest still takes two rows, so the gap, a section row and a heading are new.
local grown = bag:GetHeight()
assert(grown == 300 + lift + 6 + 42 + 16, "bag grows for reagents and sections: " .. grown)
assert(at(bag.Items[18]) == "-378," .. 4 + lift + 2 * 42 + 6, "grouped gear from the top left: " .. at(bag.Items[18]))
-- Anchoring again without a new size keeps Blizzard's base, not the grown height (#78).
Anchors()
assert(bag:GetHeight() == grown, "no double growth: " .. bag:GetHeight())
-- The engine rounds a height it is given, so the grown height comes back a hair off; still not a new base.
bag.drift = 3e-5
Anchors()
Anchors()
assert(math.abs(bag:GetHeight() - grown) < 0.01, "no double growth from rounding: " .. bag:GetHeight())
bag.drift = nil
-- Whether the reagent bag fits is asked of Blizzard's height too: on a screen with room for the reagent rows but not
-- the sections, it stays folded in though the bag is still at its grown height.
screen = 400
Anchors()
assert(reagents:GetParent() == bag and bag:GetHeight() == 300 + lift, "reagents fit from the base: " .. bag:GetHeight())
-- The bag shrinks from Blizzard's scale to stay on that screen, its corner where Blizzard anchored it.
local shrunk = bag:GetScale()
assert(math.abs(bag:GetHeight() * shrunk + 70 - 400) < 1e-6, "fits on screen: " .. shrunk)
assert(math.abs(select(5, bag:GetPoint()) * shrunk - 90 * 0.9) < 1e-6, "corner stays put")
-- Room for neither: Blizzard's height and grid, the reagent bag back in its own window.
screen = 300
Anchors()
assert(bag:GetHeight() == 300 and reagents:GetParent() ~= bag, "neither fits: " .. bag:GetHeight())
assert(at(bag.Items[20]) == "0,4" and not rule:IsShown())
assert(select(2, reagents.Items[1]:GetPoint()) == reagents, "buttons back in their window")
screen = 1000
bag:SetScale(0.9)
-- A height Blizzard sets is a new base.
bag.height = 342
Anchors()
assert(bag:GetHeight() == 342 + grown - 300, "grows from Blizzard's new height: " .. bag:GetHeight())
bag.height = 300
Anchors()
assert(bag:GetHeight() == grown)

-- While equipped weapons settle, this addon's own changes wait for the gear refresh that ends it.
settling = true
db.gearSections = false
settings.gearSections()
Refreshed()
assert(bag:GetHeight() == grown, "no layout while weapons settle: " .. bag:GetHeight())
settling = false
Refreshed()
-- Sections off: only the reagent lift remains.
assert(bag:GetHeight() == 300 + lift, "sections undone: " .. bag:GetHeight())
-- Blizzard's own layout is never held back: it has just put the buttons back on its grid.
settling = true
db.gearSections = true
Anchors()
assert(bag:GetHeight() == grown, "Blizzard's layout is laid over while settling: " .. bag:GetHeight())
-- The reagent bag closing while settling leaves the bag at once; its rows' height goes with the refresh.
reagents:Hide()
hooks["ContainerFrame.CloseBag"](nil, reagents)
assert(reagents:GetParent() ~= bag, "unfolded on close")
assert(bag:GetHeight() == grown, "height waits for settling: " .. bag:GetHeight())
settling = false
Refreshed()
assert(bag:GetHeight() == grown - lift, "reagent rows gone: " .. bag:GetHeight())
assert(at(bag.Items[20]) == "0,4", at(bag.Items[20]))
reagents:Show()
Anchors()
assert(bag:GetHeight() == grown and reagents:GetParent() == bag, "folded in again")

db.gearSections = false
settings.gearSections()
assert(bag:GetHeight() == 300 + lift, "sections undone: " .. bag:GetHeight())
-- Reagents off: back to Blizzard's height, window and buttons where Blizzard put them.
db.combinedReagents = false
settings.combinedReagents()
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
assert(bag:GetScale() >= 0.75, "never below the native minimum scale: " .. bag:GetScale())
assert(fits or bag:GetScale() == 0.75, "fits on screen: " .. bag:GetHeight() .. " x " .. bag:GetScale())
-- Closing the reagent bag while folded.
assert(reagents:GetParent() == bag)
reagents:Hide()
hooks["ContainerFrame.CloseBag"](nil, reagents)
assert(reagents:GetParent() ~= bag, "unfolded on close")
print("bagslayout: ok")
