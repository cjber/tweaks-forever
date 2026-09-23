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
Model.ITEM, Model.STEP, Model.HEADING, Model.MIN_SCALE = ITEM, STEP, HEADING, MIN_SCALE

-- Where each item and heading goes, bottom-up from the money frame as Blizzard's grid is. `items` is in
-- Blizzard's order (bottom right first), each { section = key or nil }; `sections` is the keys top to bottom.
-- A place is { column counted from the right, y }; the total height the items and headings take is returned.
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

ns.Init(function()
	local bag = ContainerFrameCombinedBags
	-- Whether the bag is laid out in sections now, so switching them off lays it out once more to undo them.
	local headings, sectioned = {}, false

	local function Active()
		return ns.Active("gearGroups") and ns.Active("gearSections") and not InputUtil.IsGamepadUIEnabled()
	end

	-- Each item's section (its first list) and the sections in name order, with the list each one shows.
	local function Plan()
		local items, firsts, sections = {}, {}, {}
		for _, button in bag:EnumerateValidItems() do
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

	-- Blizzard's own order, read back from the grid it has just laid out: bottom row first, right to left.
	local function BlizzardOrder(a, b)
		local _, _, _, ax, ay = a.button:GetPoint()
		local _, _, _, bx, by = b.button:GetPoint()
		if ay ~= by then
			return ay < by
		end
		return ax > bx
	end

	local function Heading(index)
		if not headings[index] then
			headings[index] = bag:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		end
		return headings[index]
	end

	-- Blizzard sizes the bag before laying it out, so this decides for both whether the bag has sections: not when
	-- the taller bag would run off the screen even at the smallest scale, as its top rows could not be reached.
	local function Grow(container)
		sectioned = false
		if not Active() then
			return
		end
		local items, sections = Plan()
		local _, _, height = Model.Layout(items, sections, container:GetColumns())
		local total = container:GetHeight() + height - container:GetRows() * STEP
		if total * MIN_SCALE + CONTAINER_OFFSET_Y > GetScreenHeight() then
			return
		end
		sectioned = true
		container:SetHeight(total)
		NineSliceUtil.UpdateCornerCropping(container, total)
	end

	local function Arrange(container)
		for _, heading in ipairs(headings) do
			heading:Hide()
		end
		if not sectioned then
			return
		end
		local items, sections, firsts = Plan()
		table.sort(items, BlizzardOrder)
		local columns = container:GetColumns()
		local places, heads = Model.Layout(items, sections, columns)
		local money = container.MoneyFrame
		for index, item in ipairs(items) do
			local place = places[index]
			item.button:ClearAllPoints()
			item.button:SetPoint("BOTTOMRIGHT", money, "TOPRIGHT", -place.column * STEP, ORIGIN_Y + place.y)
		end
		for index, head in ipairs(heads) do
			local mark, text = firsts[head.section], Heading(index)
			text:SetText(mark.kind == "fishing" and FISHING_ICON .. mark.name or mark.name)
			text:SetTextColor(unpack(ns.Gear.ColourOf(mark)))
			text:ClearAllPoints()
			text:SetPoint("BOTTOMLEFT", money, "TOPRIGHT", -(columns - 1) * STEP - ITEM, ORIGIN_Y + head.y + 2)
			text:Show()
		end
	end

	-- Blizzard lays the bag out only when it opens, so a change of contents or groups redoes it the same way. While
	-- equipped weapons are settling, the refresh that ends it lays the bag out, so the moved weapons do not show
	-- under another section first.
	local function Relayout()
		if bag:IsShown() and (sectioned or Active()) and not ns.Gear.Settling() then
			bag:UpdateFrameSize()
			bag:UpdateItemLayout()
			UpdateContainerFrameAnchors()
		end
	end

	hooksecurefunc(bag, "UpdateFrameSize", Grow)
	hooksecurefunc(bag, "UpdateItemLayout", Arrange)
	ns.Gear.OnRefresh(Relayout)
	Settings.SetOnValueChangedCallback("TweaksForever_gearSections", Relayout)
end)
