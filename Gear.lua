---@type string, TFNamespace
local _, ns = ...

ns.Feature({
	key = "gearGroups",
	category = "Gear",
	name = "Group gear with Ctrl+Right-click",
	tooltip = "Ctrl+Right-click a bag item, or pick Group gear from a bag's portrait menu, to put it in a named "
		.. "group, such as Healing, DPS or Levelling, or to start a new one. The same menu equips a whole group "
		.. "and picks each group's colour. Items in a group or an Equipment Manager set are marked in your bags "
		.. "and named in their tooltip.",
	default = true,
})

ns.Feature({
	key = "beforeFishing",
	category = "Gear",
	name = "Remember the weapons a fishing pole replaces",
	tooltip = "Equipping a fishing pole keeps the weapons it replaced as a Before fishing group, marked in your "
		.. "bags. Ctrl+Right-click one of them to put them back on.",
	default = true,
	parent = "gearGroups",
})

ns.Feature({
	key = "gearMark",
	category = "Gear",
	name = "Mark grouped gear with",
	tooltip = "How grouped gear shows in your bags, in each group's colour. A strip along the bottom of the slot "
		.. "keeps clear of the item quality border; a border takes the place of the quality border, split between "
		.. "groups.",
	default = "strip",
	options = {
		{ "strip", "A coloured strip" },
		{ "border", "A coloured border" },
		{ "dots", "Coloured dots" },
		{ "none", "Nothing" },
	},
	parent = "gearGroups",
})

local BEFORE_FISHING = "Before fishing"
local WHITE = "Interface\\Buttons\\WHITE8X8"
-- The quality border's own art, so a group border replaces it exactly.
local ICON_FRAME = "Interface\\Common\\WhiteIconFrame"
-- The glow the bags give a new item, tinted and kept on.
local GLOW = "bags-glow-white"
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
-- Dots sit along the top of a slot; more than this would run off its left edge.
local MAX_DOTS = 4
-- The border splits into one slice per group; narrower slices stop reading as separate colours.
local MAX_BORDERS = 4
-- Colours new groups take in turn: Catppuccin Mocha's rose, teal, lavender and pink, soft on the dark bag and
-- each at least CIEDE2000 20 from every item quality colour, so a group never reads as a rarity. Its other
-- accents sit on a quality's hue (green, peach, sky, sapphire, yellow) or next to one of these, so a fifth list
-- repeats a colour instead.
local PALETTE = {
	{ 243 / 255, 139 / 255, 168 / 255 },
	{ 148 / 255, 226 / 255, 213 / 255 },
	{ 180 / 255, 190 / 255, 254 / 255 },
	{ 245 / 255, 194 / 255, 231 / 255 },
}
-- Earlier palettes, which lists coloured then still carry unless their colour was picked by hand.
local RETIRED_PALETTES = {
	{
		{ 1, 0, 0.3 },
		{ 0.45, 1, 0.86 },
		{ 0.74, 1, 0.15 },
		{ 1, 0.45, 0.72 },
		{ 0.3, 0.4, 1 },
	},
	{
		{ 0.3, 0.65, 1 },
		{ 1, 0.55, 0.15 },
		{ 0.45, 0.85, 0.3 },
		{ 0.9, 0.35, 0.9 },
		{ 1, 0.85, 0.2 },
		{ 0.25, 0.85, 0.8 },
		{ 1, 0.35, 0.35 },
		{ 0.7, 0.55, 1 },
	},
}
-- The strip sits under the stack count; the border and dots sit over the quality border.
---@type table<string, DrawLayer>
local LAYERS = { strip = "ARTWORK", border = "OVERLAY", glow = "OVERLAY", dots = "OVERLAY" }
-- Where a list comes from: a Tweaks group, an Equipment Manager set, or Before fishing.
local KINDS = { "group", "set", "fishing" }

-- Equipment slots per inventory type; a second item of a paired type takes the second slot.
local SLOTS = {
	INVTYPE_HEAD = { 1 },
	INVTYPE_NECK = { 2 },
	INVTYPE_SHOULDER = { 3 },
	INVTYPE_BODY = { 4 },
	INVTYPE_CHEST = { 5 },
	INVTYPE_ROBE = { 5 },
	INVTYPE_WAIST = { 6 },
	INVTYPE_LEGS = { 7 },
	INVTYPE_FEET = { 8 },
	INVTYPE_WRIST = { 9 },
	INVTYPE_HAND = { 10 },
	INVTYPE_FINGER = { 11, 12 },
	INVTYPE_TRINKET = { 13, 14 },
	INVTYPE_CLOAK = { 15 },
	INVTYPE_WEAPON = { 16, 17 },
	INVTYPE_2HWEAPON = { 16 },
	INVTYPE_WEAPONMAINHAND = { 16 },
	INVTYPE_WEAPONOFFHAND = { 17 },
	INVTYPE_SHIELD = { 17 },
	INVTYPE_HOLDABLE = { 17 },
	INVTYPE_RANGED = { 18 },
	INVTYPE_RANGEDRIGHT = { 18 },
	INVTYPE_THROWN = { 18 },
	INVTYPE_RELIC = { 18 },
	INVTYPE_TABARD = { 19 },
}
-- A two-hander also needs the off-hand slot empty.
local BLOCKS = { INVTYPE_2HWEAPON = 17 }

---@class TFGearMark
---@field kind string
---@field name string

---@class TFEquipStep
---@field item integer
---@field slot integer

---@class TFGear
local Model = {}
ns.Gear = Model

-- Put itemID in or out of the named group. A group left empty is removed. Returns whether it is now in.
---@param groups TFGroups
---@param name string
---@param itemID integer
---@return boolean
function Model.Toggle(groups, name, itemID)
	local group = groups[name] or {}
	group[itemID] = not group[itemID] or nil
	groups[name] = next(group) and group or nil
	return group[itemID] == true
end

-- Every list an item is in, as { kind, name } sorted by name, from { [kind] = { [name] = { [itemID] = true } } }.
---@param itemID integer
---@param lists table<string, TFGroups>
---@return TFGearMark[]
function Model.GroupsOf(itemID, lists)
	local found = {}
	for _, kind in ipairs(KINDS) do
		for name, items in pairs(lists[kind] or {}) do
			if items[itemID] then
				found[#found + 1] = { kind = kind, name = name }
			end
		end
	end
	table.sort(found, function(a, b)
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.kind < b.kind
	end)
	return found
end

-- A list's { r, g, b }. The first time, it takes the first palette colour no other list has, then cycles.
---@param colours TFColours
---@param kind string
---@param name string|integer
---@return TFColour
function Model.Colour(colours, kind, name)
	colours[kind] = colours[kind] or {}
	if colours[kind][name] then
		return colours[kind][name]
	end
	local used, count = {}, 0
	for _, byName in pairs(colours) do
		for _, colour in pairs(byName) do
			used[table.concat(colour, ",")] = true
			count = count + 1
		end
	end
	local pick = PALETTE[count % #PALETTE + 1]
	for _, colour in ipairs(PALETTE) do
		if not used[table.concat(colour, ",")] then
			pick = colour
			break
		end
	end
	colours[kind][name] = { unpack(pick) }
	return colours[kind][name]
end

---@param a TFColour
---@param b TFColour
---@return boolean
local function Same(a, b)
	return math.abs(a[1] - b[1]) < 1e-3 and math.abs(a[2] - b[2]) < 1e-3 and math.abs(a[3] - b[3]) < 1e-3
end

-- Stored colours still on a retired palette entry are forgotten, so each list takes an unused current colour
-- the next time it is drawn; hand-picked colours stay.
---@param colours TFColours
function Model.Recolour(colours)
	for _, byName in pairs(colours) do
		for name, colour in pairs(byName) do
			for _, retiredPalette in ipairs(RETIRED_PALETTES) do
				for _, retired in ipairs(retiredPalette) do
					if Same(colour, retired) then
						byName[name] = nil
					end
				end
			end
		end
	end
end

-- { { item, slot } } in slot order for a group's items, given each item's inventory type.
---@param items integer[]
---@param equipLoc fun(itemID: integer): string?
---@return TFEquipStep[]
function Model.Plan(items, equipLoc)
	-- Fewest choices first, so a main-hand-only weapon is not crowded out by a one-hander.
	local ordered = { unpack(items) }
	table.sort(ordered, function(a, b)
		local na, nb = #(SLOTS[equipLoc(a)] or {}), #(SLOTS[equipLoc(b)] or {})
		if na ~= nb then
			return na < nb
		end
		return a < b
	end)
	local used, plan = {}, {}
	for _, item in ipairs(ordered) do
		local loc = equipLoc(item)
		for _, slot in ipairs(SLOTS[loc] or {}) do
			local blocks = BLOCKS[loc]
			if not used[slot] and not (blocks and used[blocks]) then
				used[slot] = true
				if blocks then
					used[blocks] = true
				end
				plan[#plan + 1] = { item = item, slot = slot }
				break
			end
		end
	end
	table.sort(plan, function(a, b)
		return a.slot < b.slot
	end)
	return plan
end

local function Char()
	return TweaksForeverCharDB
end

-- Saved Equipment Manager sets as { [name] = { [itemID] = true } }, with each set's ID. Read once per change,
-- since every bag slot asks.
local stockSets, stockIDs
local function StockSets()
	if stockSets then
		return stockSets, stockIDs
	end
	local sets, ids = {}, {}
	for _, id in ipairs(C_EquipmentSet.GetEquipmentSetIDs()) do
		local name = C_EquipmentSet.GetEquipmentSetInfo(id)
		local items = {}
		for _, itemID in pairs(C_EquipmentSet.GetItemIDs(id)) do
			items[itemID] = true
		end
		sets[name], ids[name] = items, id
	end
	-- A deleted set frees its colour. Colours follow the set's ID, which survives a rename.
	local live = {}
	for _, id in pairs(ids) do
		live[id] = true
	end
	for id in pairs(Char().colours.set or {}) do
		if not live[id] then
			Char().colours.set[id] = nil
		end
	end
	stockSets, stockIDs = sets, ids
	return sets, ids
end

local function BeforeFishing()
	local items = {}
	if ns.Active("beforeFishing") then
		for _, itemID in pairs(Char().beforeFishing or {}) do
			items[itemID] = true
		end
	end
	return { [BEFORE_FISHING] = next(items) and items or nil }
end

local function CanEquip()
	if InCombatLockdown() then
		UIErrorsFrame:AddExternalErrorMessage(ERR_NOT_IN_COMBAT)
		return false
	end
	return true
end

---@param plan TFEquipStep[]
local function EquipPlan(plan)
	if not CanEquip() then
		return
	end
	for _, step in ipairs(plan) do
		if GetInventoryItemID("player", step.slot) ~= step.item and C_Item.GetItemCount(step.item) > 0 then
			C_Item.EquipItemByName(step.item, step.slot)
		end
	end
end

---@param name string
local function EquipGroup(name)
	local items = {}
	for itemID in pairs(Char().groups[name] or {}) do
		items[#items + 1] = itemID
	end
	EquipPlan(Model.Plan(items, function(itemID)
		return (select(4, C_Item.GetItemInfoInstant(itemID)))
	end))
end

local function EquipBeforeFishing()
	local plan = {}
	for slot, itemID in pairs(Char().beforeFishing or {}) do
		plan[#plan + 1] = { item = itemID, slot = slot }
	end
	table.sort(plan, function(a, b)
		return a.slot < b.slot
	end)
	EquipPlan(plan)
end

---@param name string
local function EquipSet(name)
	local _, ids = StockSets()
	if CanEquip() and ids[name] then
		C_EquipmentSet.UseEquipmentSet(ids[name])
	end
end

local EQUIP = { group = EquipGroup, set = EquipSet, fishing = EquipBeforeFishing }

local function Lists()
	return { group = Char().groups, set = (StockSets()), fishing = BeforeFishing() }
end

---@param mark TFGearMark
---@return TFColour
local function Colour(mark)
	if mark.kind == "set" then
		local _, ids = StockSets()
		return Model.Colour(Char().colours, mark.kind, ids[mark.name])
	end
	return Model.Colour(Char().colours, mark.kind, mark.name)
end

-- For Sections.lua: the lists an item is in, a list's colour, and a call after every refresh of the marks.
---@param itemID integer
---@return TFGearMark[]
function Model.MarksOf(itemID)
	return Model.GroupsOf(itemID, Lists())
end
Model.ColourOf = Colour
local refreshed = {}
---@param fn fun()
function Model.OnRefresh(fn)
	refreshed[#refreshed + 1] = fn
end

---@param mark TFGearMark
---@return string
local function Coloured(mark)
	local r, g, b = unpack(Colour(mark))
	return string.format(
		"|cff%02x%02x%02x%s|r",
		math.floor(r * 255),
		math.floor(g * 255),
		math.floor(b * 255),
		mark.name
	)
end

ns.Init(function()
	TweaksForeverCharDB = TweaksForeverCharDB or {}
	Char().groups = Char().groups or {}
	Char().colours = Char().colours or {}
	Model.Recolour(Char().colours)
	-- [button] = { [style] = textures }, made on first use.
	local hooked = {}
	---@type table<ContainerFrameItemButtonTemplate, table<string, Texture[]>>
	local marks = {}

	---@param button ContainerFrameItemButtonTemplate
	---@param style string
	---@param index integer
	---@return Texture
	local function Texture(button, style, index)
		marks[button] = marks[button] or {}
		local pool = marks[button][style] or {}
		marks[button][style] = pool
		if not pool[index] then
			pool[index] = button:CreateTexture(nil, LAYERS[style], nil, 2)
			pool[index]:SetTexture(style == "border" and ICON_FRAME or WHITE)
			if style == "glow" then
				pool[index]:SetTexture(C_Texture.GetAtlasInfo(GLOW).file)
				pool[index]:SetBlendMode("ADD")
			elseif style == "dots" then
				pool[index]:SetMask(CIRCLE)
			end
		end
		return pool[index]
	end

	---@param button ContainerFrameItemButtonTemplate
	---@param found TFGearMark[]
	local function Strip(button, found)
		local back = Texture(button, "strip", 1)
		back:SetVertexColor(0, 0, 0, 0.8)
		back:SetPoint("BOTTOMLEFT", 2, 2)
		back:SetPoint("BOTTOMRIGHT", -2, 2)
		back:SetHeight(5)
		back:Show()
		local width = (button:GetWidth() - 6) / #found
		for index, mark in ipairs(found) do
			local segment = Texture(button, "strip", index + 1)
			segment:SetVertexColor(unpack(Colour(mark)))
			segment:SetSize(width, 3)
			segment:SetPoint("BOTTOMLEFT", 3 + (index - 1) * width, 3)
			segment:Show()
		end
	end

	-- One slice per group across the quality border's frame, with the new-item glow behind it split the same way.
	---@param button ContainerFrameItemButtonTemplate
	---@param found TFGearMark[]
	local function Border(button, found)
		local frame, count = button.IconBorder, math.min(#found, MAX_BORDERS)
		local glow = C_Texture.GetAtlasInfo(GLOW)
		local width, glowWidth = frame:GetWidth() / count, glow.width / count
		local glowSpan = glow.rightTexCoord - glow.leftTexCoord
		for index = 1, count do
			local colour = Colour(found[index])
			local slice = Texture(button, "border", index)
			slice:SetVertexColor(unpack(colour))
			slice:SetTexCoord((index - 1) / count, index / count, 0, 1)
			slice:SetPoint("TOPLEFT", frame, (index - 1) * width, 0)
			slice:SetPoint("BOTTOMLEFT", frame, (index - 1) * width, 0)
			slice:SetWidth(width)
			slice:Show()
			local halo = Texture(button, "glow", index)
			halo:SetVertexColor(unpack(colour))
			halo:SetTexCoord(
				glow.leftTexCoord + glowSpan * (index - 1) / count,
				glow.leftTexCoord + glowSpan * index / count,
				glow.topTexCoord,
				glow.bottomTexCoord
			)
			halo:SetPoint("TOPLEFT", button, "CENTER", -glow.width / 2 + (index - 1) * glowWidth, glow.height / 2)
			halo:SetSize(glowWidth, glow.height)
			halo:Show()
		end
	end

	---@param button ContainerFrameItemButtonTemplate
	---@param found TFGearMark[]
	local function Dots(button, found)
		for index = 1, math.min(#found, MAX_DOTS) do
			local ring, dot = Texture(button, "dots", 2 * index - 1), Texture(button, "dots", 2 * index)
			ring:SetVertexColor(0, 0, 0, 0.9)
			ring:SetSize(10, 10)
			ring:SetPoint("TOPRIGHT", -2 - (index - 1) * 8, -2)
			ring:Show()
			dot:SetVertexColor(unpack(Colour(found[index])))
			dot:SetSize(7, 7)
			dot:SetPoint("CENTER", ring)
			dot:SetDrawLayer("OVERLAY", 3)
			dot:Show()
		end
	end

	---@param button ContainerFrameItemButtonTemplate
	local function UpdateMarks(button)
		for _, pool in pairs(marks[button] or {}) do
			for _, texture in ipairs(pool) do
				texture:Hide()
			end
		end
		local itemID = C_Container.GetContainerItemID(button:GetBagID(), button:GetID())
		if not ns.Active("gearGroups") or not itemID then
			return
		end
		local style = ns.db.gearMark
		if style == "none" then
			return
		end
		local found = Model.GroupsOf(itemID, Lists())
		if #found == 0 then
			return
		end
		if style == "strip" then
			Strip(button, found)
		elseif style == "border" then
			Border(button, found)
		elseif style == "dots" then
			Dots(button, found)
		else
			error("unknown gear mark " .. tostring(style))
		end
	end

	local function RefreshBags()
		ns.ForEachBagButton(UpdateMarks)
		for _, fn in ipairs(refreshed) do
			fn()
		end
	end

	---@param name string
	---@param itemID integer
	local function ToggleGroup(name, itemID)
		Model.Toggle(Char().groups, name, itemID)
		if not Char().groups[name] and Char().colours.group then
			Char().colours.group[name] = nil
		end
		RefreshBags()
	end

	---@param mark TFGearMark
	local function PickColour(mark)
		local colour = Colour(mark)
		local function Set(r, g, b)
			colour[1], colour[2], colour[3] = r, g, b
			RefreshBags()
		end
		ColorPickerFrame:SetupColorPickerAndShow({
			r = colour[1],
			g = colour[2],
			b = colour[3],
			swatchFunc = function()
				Set(ColorPickerFrame:GetColorRGB())
			end,
			cancelFunc = function(previous)
				Set(previous.r, previous.g, previous.b)
			end,
		})
	end

	---@param itemID integer
	local function NewGroup(itemID)
		StaticPopup_ShowCustomGenericInputBox({
			text = "New gear group",
			maxLetters = 32,
			callback = function(text)
				local name = strtrim(text)
				if name ~= "" and name ~= BEFORE_FISHING then
					ToggleGroup(name, itemID)
				end
			end,
		})
	end

	---@param button Button
	---@param itemID integer
	local function OpenMenu(button, itemID)
		MenuUtil.CreateContextMenu(button, function(_, root)
			root:CreateTitle(C_Item.GetItemNameByID(itemID) or "")
			local names = {}
			for name in pairs(Char().groups) do
				names[#names + 1] = name
			end
			table.sort(names)
			for _, name in ipairs(names) do
				root:CreateCheckbox(Coloured({ kind = "group", name = name }), function()
					return Char().groups[name] and Char().groups[name][itemID]
				end, function()
					ToggleGroup(name, itemID)
					-- A refresh cannot add or drop the Equip and Colour entries below, so reopen for fresh ones.
					return MenuResponse.CloseAll
				end)
			end
			root:CreateButton("New group…", function()
				NewGroup(itemID)
			end)
			-- Each source equips its own way, so a group and a set sharing a name stay distinct.
			local found = Model.GroupsOf(itemID, Lists())
			if #found > 0 then
				root:CreateDivider()
				for _, mark in ipairs(found) do
					root:CreateButton("Equip " .. mark.name, function()
						EQUIP[mark.kind](mark.name)
					end)
				end
				local colours = root:CreateButton("Colour")
				for _, mark in ipairs(found) do
					colours:CreateButton(Coloured(mark), function()
						PickColour(mark)
					end)
				end
			end
		end)
	end

	---@param owner Button
	---@param bag integer
	---@param slot integer
	local function OpenItemMenu(owner, bag, slot)
		local itemID = C_Container.GetContainerItemID(bag, slot)
		if itemID and select(4, C_Item.GetItemInfoInstant(itemID)) ~= "" then
			OpenMenu(owner, itemID)
		end
	end

	ns.ClickMode({
		feature = "gearGroups",
		label = "Group gear",
		tooltip = "Click bag items to group them, equip their groups or change a group's colour. Right-click or close "
			.. "your bags to stop.",
		cursor = "INTERACT_CURSOR",
		Apply = OpenItemMenu,
	})

	---@param button ContainerFrameItemButtonTemplate
	---@param mouseButton string
	local function Click(button, mouseButton)
		if
			mouseButton ~= "RightButton"
			or not ns.Active("gearGroups")
			or not IsControlKeyDown()
			or IsAltKeyDown()
			or IsShiftKeyDown()
			or CursorHasItem()
		then
			return
		end
		-- Mainline has no Ctrl+Right-click bag action; leave user-remapped gestures alone.
		if ns.IsBagActionClick() then
			return
		end
		OpenItemMenu(button, button:GetBagID(), button:GetID())
	end

	ns.HookBagButtons(hooked, UpdateMarks, Click)

	---@param tooltip GameTooltip
	---@param itemID integer?
	local function AddTooltipLine(tooltip, itemID)
		if not ns.Active("gearGroups") or not itemID then
			return
		end
		local names = {}
		for index, mark in ipairs(Model.GroupsOf(itemID, Lists())) do
			names[index] = Coloured(mark)
		end
		if #names > 0 then
			tooltip:AddLine("Gear: " .. table.concat(names, ", "), 1, 0.82, 0, true)
			tooltip:Show()
		end
	end
	hooksecurefunc(GameTooltip, "SetBagItem", function(tooltip, bag, slot)
		AddTooltipLine(tooltip, C_Container.GetContainerItemID(bag, slot))
	end)
	hooksecurefunc(GameTooltip, "SetInventoryItem", function(tooltip, unit, slot)
		if unit == "player" then
			AddTooltipLine(tooltip, GetInventoryItemID(unit, slot))
		end
	end)

	-- What the weapon slots held the last time they settled without a pole. Equipping a two-hander fires an
	-- event per slot, so reading waits a moment for both to settle. A weapon held only between two events, such
	-- as one swapped in just before the pole, is caught as it passes.
	local worn, seen, pending = {}, nil, false
	-- Sections wait for this: the weapons a pole replaced reach the bag before they are known as Before fishing.
	function Model.Settling()
		return pending
	end
	local function Weapons()
		return {
			[INVSLOT_MAINHAND] = GetInventoryItemID("player", INVSLOT_MAINHAND),
			[INVSLOT_OFFHAND] = GetInventoryItemID("player", INVSLOT_OFFHAND),
		}
	end
	local function Settle()
		pending = false
		local main = GetInventoryItemID("player", INVSLOT_MAINHAND)
		if seen and seen[INVSLOT_MAINHAND] ~= worn[INVSLOT_MAINHAND] then
			worn = seen
		end
		seen = nil
		if main and ns.Fishing.IsPole(main) then
			if not Char().beforeFishing and next(worn) then
				Char().beforeFishing = worn
			end
		elseif main then
			-- A weapon back in hand ends it; an empty hand keeps it, so a pole put away still leaves the mark.
			Char().beforeFishing = nil
			worn = Weapons()
		end
		RefreshBags()
	end
	ns.On("PLAYER_EQUIPMENT_CHANGED", function(slot)
		if slot ~= INVSLOT_MAINHAND and slot ~= INVSLOT_OFFHAND then
			return
		end
		local main = GetInventoryItemID("player", INVSLOT_MAINHAND)
		if main and not ns.Fishing.IsPole(main) then
			seen = Weapons()
		end
		if not pending then
			pending = true
			C_Timer.After(0.2, Settle)
		end
	end)
	ns.On("BAG_UPDATE_DELAYED", RefreshBags)
	ns.On("EQUIPMENT_SETS_CHANGED", function()
		stockSets = nil
		RefreshBags()
	end)
	Settings.SetOnValueChangedCallback("TweaksForever_gearGroups", RefreshBags)
	Settings.SetOnValueChangedCallback("TweaksForever_beforeFishing", RefreshBags)
	Settings.SetOnValueChangedCallback("TweaksForever_gearMark", RefreshBags)
	Settle()
end)
