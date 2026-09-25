---@type string, TFNamespace
local _, ns = ...

ns.Feature({
	key = "gearSections",
	category = "Gear",
	name = "Gather grouped gear in the combined bag",
	tooltip = "With Combine Bags on, grouped gear sits together at the top of the bag under a heading for each "
		.. "group, in the group's colour. An item in several groups goes under the first. Separate bags keep "
		.. "items where they are.",
	default = true,
	parent = "gearGroups",
})

---@class TFSections
-- Set by Reagents.lua: Reserve folds the reagent bag in when it fits and returns its lift; Placed lays its rows out.
---@field Reserve fun(base: number, columns: integer): number?
---@field Placed fun(columns: integer)?
local Model = {}
ns.Sections = Model

-- ContainerFrameItemButtonTemplate is 37 square with 5 between buttons; the grid starts 4 above the money frame
-- (ContainerFrameCombinedBagsMixin:GetInitialItemAnchor).
local ITEM, STEP, ORIGIN_Y = 37, 42, 4
-- Room for a heading above its section, and a gap between the sections and the rest of the bag.
local HEADING, GAP = 16, 6
-- Before fishing is a moment rather than a set, so its heading carries the fishing icon to say so.
local FISHING_ICON = "|TInterface\\Icons\\Trade_Fishing:0|t "
-- The smallest scale Blizzard shrinks bags to so they fit on screen (CONTAINER_SCALE in ContainerFrame.lua).
local MIN_SCALE = 0.75
-- Shared with the reagent bag's section (Reagents.lua), so the two line up.
Model.ITEM, Model.STEP, Model.ORIGIN_Y, Model.GAP, Model.MIN_SCALE = ITEM, STEP, ORIGIN_Y, GAP, MIN_SCALE
-- How far the reagent bag's rows at the bottom lift the rest of the bag, from Model.Reserve on each layout.
Model.lift = 0

-- Where each item and heading goes, bottom-up from the money frame as Blizzard's grid is. `items` is in
-- Blizzard's order (bottom right first), each { section = key or nil }; `sections` is the keys top to bottom.
-- A place is { column counted from the right, y }; the total height the items and headings take is returned.
---@param items TFSectionItem[]
---@param sections string[]
---@param columns integer
---@return TFSectionPlace[], TFSectionHeading[], number
function Model.Layout(items, sections, columns)
	local rest, members = {}, {}
	for _, key in ipairs(sections) do
		members[key] = {}
	end
	for index, item in ipairs(items) do
		local list = item.section and members[item.section] or rest
		list[#list + 1] = index
	end
	local places, headings = {}, {}
	for i, index in ipairs(rest) do
		places[index] = { column = (i - 1) % columns, y = math.floor((i - 1) / columns) * STEP }
	end
	local y = math.ceil(#rest / columns) * STEP
	if #rest > 0 and #sections > 0 then
		y = y + GAP
	end
	-- Sections read left to right from the top, so they fill from the left, unlike the rest of the grid.
	for s = #sections, 1, -1 do
		local list = members[sections[s]]
		local rows = math.ceil(#list / columns)
		for i, index in ipairs(list) do
			local row = math.floor((i - 1) / columns)
			places[index] = { column = columns - 1 - (i - 1) % columns, y = y + (rows - 1 - row) * STEP }
		end
		y = y + rows * STEP
		headings[#headings + 1] = { section = sections[s], y = y }
		y = y + HEADING
	end
	return places, headings, y
end

---@type ContainerFrameCombinedBags
local bag
local headings = {}
-- The bag's height and scale as Blizzard last set them, and the height this addon then gave it.
local base, scale, grown
-- Whether the bag is laid out differently from Blizzard's grid now, so switching both features off undoes it once.
local changed = false

local function Active()
	return ns.Active("gearGroups") and ns.Active("gearSections") and not InputUtil.IsGamepadUIEnabled()
end

-- Each item's section (its first list) and the sections in name order, with the list each one shows.
local function Plan()
	local items, firsts, sections = {}, {}, {}
	for _, button in ns.BagItems(bag) do
		local itemID = C_Container.GetContainerItemID(button:GetBagID(), button:GetID())
		local mark = itemID and ns.Gear.MarksOf(itemID)[1]
		local key = mark and mark.kind .. ":" .. mark.name
		if key and not firsts[key] then
			firsts[key] = mark
			sections[#sections + 1] = key
		end
		items[#items + 1] = { button = button, section = key }
	end
	table.sort(sections, function(a, b)
		if firsts[a].name ~= firsts[b].name then
			return firsts[a].name < firsts[b].name
		end
		return a < b
	end)
	return items, sections, firsts
end

-- Blizzard's order for the combined bag (ContainerFrame.lua's SortItemsByExtendedStateBottomRight): the backpack's
-- extended slots last, and otherwise the last bag's last slot first, at the bottom right.
---@param a TFSectionItem
---@param b TFSectionItem
---@return boolean
local function BlizzardOrder(a, b)
	local extendedA, extendedB = a.button:IsExtended(), b.button:IsExtended()
	if extendedA ~= extendedB then
		return not extendedA
	end
	local bagA, bagB = a.button:GetBagID(), b.button:GetBagID()
	if bagA ~= bagB then
		return bagA > bagB
	end
	return a.button:GetID() > b.button:GetID()
end

---@param index integer
---@return FontString
local function Heading(index)
	if not headings[index] then
		headings[index] = bag:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	end
	return headings[index]
end

-- Blizzard chose the bags' scale for the bag's own height. Shrink it, never below Blizzard's smallest, so a taller bag
-- stays on screen, with its corner where Blizzard anchored it.
---@param height number
local function Fit(height)
	local want = math.max(MIN_SCALE, math.min(scale, (GetScreenHeight() - CONTAINER_OFFSET_Y) / height))
	local now = bag:GetScale()
	if want ~= now then
		local point, relative, relativePoint, x, y = bag:GetPoint()
		bag:SetScale(want)
		bag:SetPoint(point, relative, relativePoint, x * now / want, y * now / want)
	end
end

-- Lays the whole combined bag out again with engine calls only (points, height, scale): after Blizzard's own
-- layout, which always ends in UpdateContainerFrameAnchors, and whenever its contents or these settings change.
-- Never by calling Blizzard's UpdateFrameSize, UpdateItemLayout or UpdateContainerFrameAnchors: run from addon code
-- they build the bags' cached item and open-bag lists tainted, and Blizzard's bank code is then blocked.
-- Sections go in only when the taller bag fits on screen at the smallest scale, as its top rows could not be
-- reached otherwise.
local function Layout()
	if not bag:IsShown() then
		return
	end
	local height = bag:GetHeight()
	if height ~= grown then
		base = height
	end
	scale = scale or bag:GetScale()
	local columns = bag:GetColumns()
	local lift = Model.Reserve and Model.Reserve(base, columns) or 0
	Model.lift = lift
	if lift == 0 and not Active() and not changed then
		return
	end
	local items, sections, firsts = Plan()
	table.sort(items, BlizzardOrder)
	local rows = math.ceil(#items / columns)
	local total = base + lift
	if Active() then
		local _, _, sectionsHeight = Model.Layout(items, sections, columns)
		local tall = total + sectionsHeight - rows * STEP
		if tall * MIN_SCALE + CONTAINER_OFFSET_Y <= GetScreenHeight() then
			total = tall
		else
			sections = {}
		end
	else
		sections = {}
	end

	local places, heads = Model.Layout(items, sections, columns)
	local money, origin = bag.MoneyFrame, ORIGIN_Y + lift
	for index, item in ipairs(items) do
		local place = places[index]
		item.button:ClearAllPoints()
		item.button:SetPoint("BOTTOMRIGHT", money, "TOPRIGHT", -place.column * STEP, origin + place.y)
	end
	for _, heading in ipairs(headings) do
		heading:Hide()
	end
	for index, head in ipairs(heads) do
		local mark, text = firsts[head.section], Heading(index)
		text:SetText(mark.kind == "fishing" and FISHING_ICON .. mark.name or mark.name)
		text:SetTextColor(unpack(ns.Gear.ColourOf(mark)))
		text:ClearAllPoints()
		text:SetPoint("BOTTOMLEFT", money, "TOPRIGHT", -(columns - 1) * STEP - ITEM, origin + head.y + 2)
		text:Show()
	end

	grown, changed = total, total ~= base
	bag:SetHeight(total)
	NineSliceUtil.UpdateCornerCropping(bag, total)
	Fit(total)
	if Model.Placed then
		Model.Placed(columns)
	end
end

-- While equipped weapons are settling, the refresh that ends it lays the bag out, so the moved weapons do not show
-- under another section first.
function Model.Relayout()
	if not ns.Gear.Settling() then
		Layout()
	end
end

ns.Init(function()
	bag = ContainerFrameCombinedBags
	hooksecurefunc("UpdateContainerFrameAnchors", function()
		scale = bag:GetScale()
		Layout()
	end)
	ns.Gear.OnRefresh(Model.Relayout)
	Settings.SetOnValueChangedCallback("TweaksForever_gearSections", Model.Relayout)
end)
