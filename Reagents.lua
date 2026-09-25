---@type string, TFNamespace
local _, ns = ...

ns.Feature({
	key = "combinedReagents",
	category = "Interface",
	name = "Show the reagent bag in the combined bag",
	tooltip = "With Combine Bags on, the reagent bag's slots sit at the bottom of the combined bag, tinted green "
		.. "under a thin rule, instead of in a small window beside it, and the backpack key opens and closes both. "
		.. "Opened on its own from the bag bar, it keeps its own window.",
	default = true,
	conflicts = {
		{ addon = "AdiBags" },
		{ addon = "ArkInventory" },
		{ addon = "Baganator" },
		{ addon = "Bagnon" },
		{ addon = "BetterBags" },
	},
})

---@class TFReagents
local Model = {}
ns.Reagents = Model

local Sections = ns.Sections

-- Rows the reagent bag takes at the bottom of the combined bag.
---@param slots integer
---@param columns integer
---@return integer
local function Rows(slots, columns)
	return math.ceil(slots / columns)
end

-- A reagent slot's column counted from the right and height above the money frame: slot 1 at the top left, read
-- left to right like the gear sections, the last row resting on the money frame where Blizzard's grid starts.
---@param slot integer
---@param slots integer
---@param columns integer
---@return integer, number
function Model.Place(slot, slots, columns)
	local index = slot - 1
	local row = math.floor(index / columns)
	return columns - 1 - index % columns, Sections.ORIGIN_Y + (Rows(slots, columns) - 1 - row) * Sections.STEP
end

-- How much the reagent rows and the gap above them lift the rest of the bag.
---@param slots integer
---@param columns integer
---@return number
function Model.Lift(slots, columns)
	return Rows(slots, columns) * Sections.STEP + Sections.GAP
end

-- Taint: the reagent bag keeps Blizzard's own window and item buttons, opened and closed only by Blizzard's code, so
-- a click on a reagent runs the same untouched path as in its own window. This file never writes a Blizzard table
-- field or calls a Blizzard function that opens, closes or fills a bag; it moves, reparents, fades and hides frames,
-- which are engine calls, not Lua state, from hooksecurefunc hooks and an EventRegistry callback.
---@type ContainerFrameCombinedBags, ContainerFrameTemplate
local bag, reagents
---@type Texture
local rule
-- [item button] = the combined bag's slot art, tinted green so empty reagent slots read as the reagent bag's.
local backgrounds = {}
-- The reagent window's border, background, portrait, title and buttons, faded while it sits in the combined bag.
local chrome
-- Where the reagent window came from, to put it back as it was.
local home, strata, level, mouse
local folded = false

local function Wanted()
	return ns.Active("combinedReagents")
		and not InputUtil.IsGamepadUIEnabled()
		and bag:IsShown()
		and reagents:IsShown()
		and ContainerFrame_IsReagentBag(reagents:GetBagID())
end

local function Chrome()
	if not chrome then
		chrome = {}
		for _, child in ipairs({ reagents:GetChildren() }) do
			-- Item buttons carry the container item mixin; everything else is the window around them.
			local item = child --[[@as TFBagChild]]
			if not item.GetSlotAndBagID then
				chrome[#chrome + 1] = { object = child, alpha = child:GetAlpha(), mouse = child:IsMouseEnabled() }
			end
		end
		for _, region in ipairs({ reagents:GetRegions() }) do
			chrome[#chrome + 1] = { object = region, alpha = region:GetAlpha() }
		end
	end
	return chrome
end

---@param button ContainerFrameItemButtonTemplate
---@return Texture
local function Background(button)
	if not backgrounds[button] then
		local texture = button:CreateTexture(nil, "BACKGROUND", "ItemSlotBackgroundCombinedBagsTemplate", -6)
		texture:SetAllPoints()
		texture:SetVertexColor(0.6, 0.9, 0.6)
		backgrounds[button] = texture
	end
	return backgrounds[button]
end

-- Both are open and visible, so moving the window from one parent to the other runs no OnShow or OnHide.
local function Fold()
	if folded then
		return
	end
	folded = true
	home, strata, level, mouse =
		reagents:GetParent(), reagents:GetFrameStrata(), reagents:GetFrameLevel(), reagents:IsMouseEnabled()
	-- Inside the combined bag it draws above it and hides with it.
	reagents:SetParent(bag)
	reagents:EnableMouse(false)
	for _, part in ipairs(Chrome()) do
		part.object:SetAlpha(0)
		if part.mouse then
			part.object:EnableMouse(false)
		end
	end
end

local function Unfold()
	Sections.lift = 0
	if not folded then
		return
	end
	folded = false
	reagents:SetParent(home)
	reagents:SetFrameStrata(strata)
	reagents:SetFrameLevel(level)
	reagents:EnableMouse(mouse)
	for _, part in ipairs(chrome) do
		part.object:SetAlpha(part.alpha)
		if part.mouse then
			part.object:EnableMouse(true)
		end
	end
	rule:Hide()
	for _, background in pairs(backgrounds) do
		background:Hide()
	end
	-- Still open, as when the setting is turned off: back to its own grid. UpdateContainerFrameAnchors, which
	-- always follows, stands the window beside the bag again at the bags' scale.
	if reagents:IsShown() then
		reagents:UpdateItemLayout()
	end
end

-- Blizzard sizes the bag before laying it out, so this decides whether the reagent bag is in it: not when the
-- taller bag would run off the screen even at the smallest scale, as its top rows could not be reached.
---@param container ContainerFrameCombinedBags
local function Grow(container)
	if Wanted() then
		local lift = Model.Lift(ns.BagSize(reagents), container:GetColumns())
		local height = container:GetHeight() + lift
		if height * Sections.MIN_SCALE + CONTAINER_OFFSET_Y <= GetScreenHeight() then
			Fold()
			Sections.lift = lift
			container:SetHeight(height)
			NineSliceUtil.UpdateCornerCropping(container, height)
			return
		end
	end
	Unfold()
end

local function Place()
	if not folded then
		return
	end
	local columns, slots, money = bag:GetColumns(), ns.BagSize(reagents), bag.MoneyFrame
	for _, button in ns.BagItems(reagents) do
		local column, y = Model.Place(button:GetID(), slots, columns)
		button:ClearAllPoints()
		button:SetPoint("BOTTOMRIGHT", money, "TOPRIGHT", -column * Sections.STEP, y)
		Background(button):Show()
	end
	local y = Sections.ORIGIN_Y + Sections.lift - Sections.GAP
	rule:ClearAllPoints()
	rule:SetPoint("BOTTOMLEFT", money, "TOPRIGHT", -(columns - 1) * Sections.STEP - Sections.ITEM, y)
	rule:SetPoint("BOTTOMRIGHT", money, "TOPRIGHT", 0, y)
	rule:Show()
end

-- Blizzard's grid starts on the money frame, where the reagent rows now sit, so it moves up above them. The gear
-- sections, when on, lay the bag out themselves from Sections.lift.
local function Lift()
	if not folded or Sections.Sectioned() then
		return
	end
	for _, button in ns.BagItems(bag) do
		local point, relative, relativePoint, x, y = button:GetPoint()
		button:ClearAllPoints()
		button:SetPoint(point, relative, relativePoint, x, y + Sections.lift)
	end
end

-- UpdateContainerFrameAnchors scales the window like a bag of its own and stands it beside the others.
local function Anchor()
	if folded then
		reagents:SetScale(1)
		reagents:ClearAllPoints()
		reagents:SetPoint("BOTTOMRIGHT", bag.MoneyFrame, "TOPRIGHT")
	end
end

local function Relayout()
	if bag:IsShown() then
		bag:UpdateFrameSize()
		bag:UpdateItemLayout()
		UpdateContainerFrameAnchors()
	end
end

local function Close()
	if not folded then
		return
	end
	-- Hidden along with the combined bag, it would still count as open, and merchants and the bag bar go by that.
	-- It is already out of sight, so hiding it runs no OnHide.
	if reagents:IsShown() and not bag:IsShown() then
		reagents:Hide()
	end
	if not reagents:IsShown() then
		Unfold()
		Relayout()
	end
end

local function InitBackpackBinding()
	-- With bags combined the Toggle Backpack key opens only the backpack; Blizzard's own Open All Bags binding opens
	-- the reagent bag with it. An override binding runs that secure binding, so nothing here opens a bag, and the
	-- player's saved key bindings stay as they are.
	local binder = CreateFrame("Frame")
	local function Bind()
		if InCombatLockdown() then
			binder:RegisterEvent("PLAYER_REGEN_ENABLED")
			return
		end
		binder:UnregisterEvent("PLAYER_REGEN_ENABLED")
		ClearOverrideBindings(binder)
		if ns.Active("combinedReagents") and ContainerFrameSettingsManager:IsUsingCombinedBags() then
			for _, key in ipairs({ GetBindingKey("TOGGLEBACKPACK") }) do
				SetOverrideBinding(binder, false, key, "OPENALLBAGS")
			end
		end
	end
	binder:SetScript("OnEvent", Bind)
	binder:RegisterEvent("USE_COMBINED_BAGS_CHANGED")
	hooksecurefunc("SaveBindings", Bind)
	Bind()

	return binder, Bind
end

ns.Init(function()
	bag, reagents = ContainerFrameCombinedBags, ContainerFrame6
	-- A faint gold rule between the reagent rows and the rest of the bag.
	rule = bag:CreateTexture(nil, "ARTWORK")
	rule:SetColorTexture(1, 0.82, 0, 0.3)
	rule:SetHeight(1)
	rule:Hide()
	local binder, Bind = InitBackpackBinding()

	hooksecurefunc(bag, "UpdateFrameSize", Grow)
	hooksecurefunc(bag, "UpdateItemLayout", function()
		Lift()
		Place()
	end)
	hooksecurefunc(reagents, "UpdateItemLayout", Place)
	hooksecurefunc("UpdateContainerFrameAnchors", Anchor)
	-- Opened while the combined bag is open, it moves in; a different bag in the slot can change its size.
	hooksecurefunc("ContainerFrame_GenerateFrame", function(frame)
		if frame == reagents then
			Relayout()
		end
	end)
	EventRegistry:RegisterCallback("ContainerFrame.CloseBag", function(_, frame)
		if frame ~= reagents or not folded then
			return
		end
		if reagents:IsShown() then
			-- The combined bag was closed. ToggleAllBags then closes the reagent bag by counting it open, so this
			-- waits until that key press or click has finished.
			C_Timer.After(0, Close)
		else
			Close()
		end
	end, binder)
	Settings.SetOnValueChangedCallback("TweaksForever_combinedReagents", function()
		Bind()
		Relayout()
	end)
end)
