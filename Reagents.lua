local _, ns = ...

ns.Feature({
	key = "combinedReagents",
	category = "Interface",
	name = "Show the reagent bag in the combined bag",
	tooltip = "With Combine Bags on, the reagent bag sits at the top of the combined bag under its own name "
		.. "instead of in a small window beside it, and closes with it. Opened on its own from the bag bar, it "
		.. "keeps its own window.",
	default = true,
	conflicts = {
		{ addon = "AdiBags" },
		{ addon = "ArkInventory" },
		{ addon = "Baganator" },
		{ addon = "Bagnon" },
		{ addon = "BetterBags" },
	},
})

local Model = {}
ns.Reagents = Model

local Sections = ns.Sections
-- The combined bag's grid starts 75 below its top (GetPaddingHeight); a heading above it starts 5 higher, where
-- Sections puts its first. The grid's right edge is the money frame's, 8 in (UpdateCurrencyFrames).
local TOP, RIGHT = 70, -8

-- Offsets of a reagent slot's top right corner from the top right of the section: slot 1 at the top left, reading
-- left to right under the heading like a section of grouped gear.
function Model.Place(slot, columns)
	local index = slot - 1
	local row = math.floor(index / columns)
	return (index % columns - columns + 1) * Sections.STEP, -Sections.HEADING - row * Sections.STEP
end

-- How much taller the combined bag grows to hold the section.
function Model.Height(slots, columns)
	return Sections.HEADING + math.ceil(slots / columns) * Sections.STEP
end

-- Taint: the reagent bag keeps Blizzard's own window and item buttons, opened and closed only by Blizzard's code, so
-- a click on a reagent runs the same untouched path as in its own window. This file never writes a Blizzard table
-- field or calls a Blizzard function that opens, closes or fills a bag; it moves, reparents, fades and hides frames,
-- which are engine calls, not Lua state, from hooksecurefunc hooks and an EventRegistry callback.
ns.Init(function()
	local bag, reagents = ContainerFrameCombinedBags, ContainerFrame6
	-- The heading, and the corner the reagent slots are laid out from.
	local section = CreateFrame("Frame", nil, bag)
	section:SetSize(1, 1)
	section:SetPoint("TOPRIGHT", bag, "TOPRIGHT", RIGHT, -TOP)
	section:Hide()
	local heading = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	-- [item button] = the combined bag's slot art, which the reagent window's buttons lack.
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
				if not child.GetSlotAndBagID then
					chrome[#chrome + 1] = { object = child, alpha = child:GetAlpha(), mouse = child:IsMouseEnabled() }
				end
			end
			for _, region in ipairs({ reagents:GetRegions() }) do
				chrome[#chrome + 1] = { object = region, alpha = region:GetAlpha() }
			end
		end
		return chrome
	end

	local function Background(button)
		if not backgrounds[button] then
			local texture = button:CreateTexture(nil, "BACKGROUND", "ItemSlotBackgroundCombinedBagsTemplate", -6)
			texture:SetAllPoints()
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
		section:Show()
	end

	local function Unfold()
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
		section:Hide()
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
	local function Grow(container)
		if Wanted() then
			local height = container:GetHeight() + Model.Height(reagents:GetBagSize(), container:GetColumns())
			if height * Sections.MIN_SCALE + CONTAINER_OFFSET_Y <= GetScreenHeight() then
				Fold()
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
		local columns = bag:GetColumns()
		for _, button in reagents:EnumerateValidItems() do
			local x, y = Model.Place(button:GetID(), columns)
			button:ClearAllPoints()
			button:SetPoint("TOPRIGHT", section, "TOPRIGHT", x, y)
			Background(button):Show()
		end
		heading:SetText(C_Container.GetBagName(reagents:GetBagID()))
		heading:ClearAllPoints()
		heading:SetPoint(
			"BOTTOMLEFT",
			section,
			"TOPRIGHT",
			-(columns - 1) * Sections.STEP - Sections.ITEM,
			2 - Sections.HEADING
		)
	end

	-- UpdateContainerFrameAnchors scales the window like a bag of its own and stands it beside the others.
	local function Anchor()
		if folded then
			reagents:SetScale(1)
			reagents:ClearAllPoints()
			reagents:SetPoint("TOPRIGHT", section)
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

	hooksecurefunc(bag, "UpdateFrameSize", Grow)
	hooksecurefunc(bag, "UpdateItemLayout", Place)
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
	end, section)
	Settings.SetOnValueChangedCallback("TweaksForever_combinedReagents", Relayout)
end)
