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

-- The gear sections' part of the combined bag's layout (CombinedBag.lua), which calls Active and Arrange.
---@class TFSections
local Model = {}
ns.Sections = Model

local Bag = ns.CombinedBag
local ITEM, STEP, ORIGIN_Y, GAP, MIN_SCALE = Bag.ITEM, Bag.STEP, Bag.ORIGIN_Y, Bag.GAP, Bag.MIN_SCALE
-- Room for a heading above its section.
local HEADING = 16
-- Before fishing is a moment rather than a set, so its heading carries the fishing icon to say so.
local FISHING_ICON = "|TInterface\\Icons\\Trade_Fishing:0|t "

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

-- Whether grouped gear is gathered into sections at all; they still go in only when Arrange finds they fit.
---@return boolean
function Model.Active()
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

-- Puts every item of the bag `lift` above the money frame, in Blizzard's grid or under section headings, and
-- returns the bag's height: `height` (Blizzard's plus the lift) as given, or taller for the sections. Sections go
-- in only when the taller bag fits on screen at the smallest scale, as its top rows could not be reached otherwise.
---@param height number
---@param lift number
---@param columns integer
---@return number
function Model.Arrange(height, lift, columns)
	local items, sections, firsts = Plan()
	table.sort(items, BlizzardOrder)
	local rows = math.ceil(#items / columns)
	local total = height
	if Model.Active() then
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
	return total
end

ns.Init(function()
	bag = ContainerFrameCombinedBags
end)
