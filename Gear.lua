local _, ns = ...

ns.Feature({
	key = "gearGroups",
	category = "Gear",
	name = "Group gear with Ctrl+Right-click",
	tooltip = "Ctrl+Right-click a bag item to put it in a named group, such as Healing, DPS or Levelling, or to "
		.. "start a new one. The same menu equips a whole group. Items in a group or an Equipment Manager set "
		.. "get a badge in your bags and a line in their tooltip.",
	default = true,
})

ns.Feature({
	key = "beforeFishing",
	category = "Gear",
	name = "Remember the weapons a fishing pole replaces",
	tooltip = "Equipping a fishing pole keeps the weapons it replaced as a Before fishing group, badged in your "
		.. "bags. Ctrl+Right-click one of them to put them back on.",
	default = true,
	parent = "gearGroups",
})

local BEFORE_FISHING = "Before fishing"
-- The Equipment Manager's own sidebar tab icon.
local BADGE = "Interface\\PaperDollInfoFrame\\PaperDollSidebarTabs"
local BADGE_COORDS = { 0.015625, 0.53125, 0.46875, 0.60546875 }

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

local Model = {}
ns.Gear = Model

-- Put itemID in or out of the named group. A group left empty is removed. Returns whether it is now in.
function Model.Toggle(groups, name, itemID)
	local group = groups[name] or {}
	group[itemID] = not group[itemID] or nil
	groups[name] = next(group) and group or nil
	return group[itemID] == true
end

-- Group names, sorted, from { [name] = { [itemID] = true } } lists.
function Model.GroupsOf(itemID, ...)
	local names = {}
	for index = 1, select("#", ...) do
		for name, items in pairs(select(index, ...)) do
			if items[itemID] then
				names[#names + 1] = name
			end
		end
	end
	table.sort(names)
	return names
end

-- { { item, slot } } in slot order for a group's items, given each item's inventory type.
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
		for _, slot in ipairs(SLOTS[equipLoc(item)] or {}) do
			if not used[slot] then
				used[slot] = true
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

local function Equip(name)
	if InCombatLockdown() then
		UIErrorsFrame:AddExternalErrorMessage(ERR_NOT_IN_COMBAT)
		return
	end
	local _, ids = StockSets()
	if ids[name] and not Char().groups[name] then
		C_EquipmentSet.UseEquipmentSet(ids[name])
		return
	end
	local plan = {}
	if name == BEFORE_FISHING then
		for slot, itemID in pairs(Char().beforeFishing) do
			plan[#plan + 1] = { item = itemID, slot = slot }
		end
		table.sort(plan, function(a, b)
			return a.slot < b.slot
		end)
	else
		local items = {}
		for itemID in pairs(Char().groups[name]) do
			items[#items + 1] = itemID
		end
		plan = Model.Plan(items, function(itemID)
			return select(4, C_Item.GetItemInfoInstant(itemID))
		end)
	end
	for _, step in ipairs(plan) do
		if GetInventoryItemID("player", step.slot) ~= step.item and C_Item.GetItemCount(step.item) > 0 then
			C_Item.EquipItemByName(step.item, step.slot)
		end
	end
end

ns.Init(function()
	TweaksForeverCharDB = TweaksForeverCharDB or {}
	Char().groups = Char().groups or {}
	local hooked, badges = {}, {}

	local function Groups(itemID)
		local stock = StockSets()
		return Model.GroupsOf(itemID, Char().groups, stock, BeforeFishing())
	end

	local function UpdateBadge(button)
		local itemID = C_Container.GetContainerItemID(button:GetBagID(), button:GetID())
		local shown = ns.Active("gearGroups") and itemID and #Groups(itemID) > 0
		if shown and not badges[button] then
			local badge = button:CreateTexture(nil, "OVERLAY", nil, 2)
			badge:SetTexture(BADGE)
			badge:SetTexCoord(unpack(BADGE_COORDS))
			badge:SetSize(16, 16)
			badge:SetPoint("TOPRIGHT", -1, -1)
			badges[button] = badge
		end
		if badges[button] then
			badges[button]:SetShown(not not shown)
		end
	end

	local function RefreshBags()
		for button in pairs(hooked) do
			if button:IsShown() then
				UpdateBadge(button)
			end
		end
	end

	local function NewGroup(itemID)
		StaticPopup_ShowCustomGenericInputBox({
			text = "New gear group",
			maxLetters = 32,
			callback = function(text)
				local name = strtrim(text)
				if name ~= "" and name ~= BEFORE_FISHING then
					Model.Toggle(Char().groups, name, itemID)
					RefreshBags()
				end
			end,
		})
	end

	local function OpenMenu(button, itemID)
		MenuUtil.CreateContextMenu(button, function(_, root)
			root:CreateTitle(C_Item.GetItemNameByID(itemID) or "")
			local names = {}
			for name in pairs(Char().groups) do
				names[#names + 1] = name
			end
			table.sort(names)
			for _, name in ipairs(names) do
				root:CreateCheckbox(name, function()
					return Char().groups[name] and Char().groups[name][itemID]
				end, function()
					Model.Toggle(Char().groups, name, itemID)
					RefreshBags()
				end)
			end
			root:CreateButton("New group…", function()
				NewGroup(itemID)
			end)
			local groups = Groups(itemID)
			if #groups > 0 then
				root:CreateDivider()
				for _, name in ipairs(groups) do
					root:CreateButton("Equip " .. name, function()
						Equip(name)
					end)
				end
			end
		end)
	end

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
		for _, action in ipairs({ "EXPANDITEM", "CHATLINK", "DRESSUP", "SPLITSTACK", "AUTOLOOTTOGGLE" }) do
			if IsModifiedClick(action) then
				return
			end
		end
		local itemID = C_Container.GetContainerItemID(button:GetBagID(), button:GetID())
		if itemID and select(4, C_Item.GetItemInfoInstant(itemID)) ~= "" then
			OpenMenu(button, itemID)
		end
	end

	-- A bag reports its size before its buttons exist, so a slot can have no button yet.
	local function HookButton(button)
		if not button or hooked[button] then
			return
		end
		hooked[button] = true
		hooksecurefunc(button, "UpdateJunkItem", UpdateBadge)
		hooksecurefunc(button, "OnModifiedClick", Click)
	end

	hooksecurefunc(ContainerFrameItemButtonMixin, "OnLoad", HookButton)
	hooksecurefunc("ContainerFrame_GenerateFrame", function(container)
		for _, button in container:EnumerateValidItems() do
			HookButton(button)
			UpdateBadge(button)
		end
	end)
	for _, container in ContainerFrameUtil_EnumerateContainerFrames() do
		for _, button in container:EnumerateValidItems() do
			HookButton(button)
		end
	end

	local function AddTooltipLine(tooltip, itemID)
		if not ns.Active("gearGroups") or not itemID then
			return
		end
		local groups = Groups(itemID)
		if #groups > 0 then
			tooltip:AddLine("Gear: " .. table.concat(groups, ", "), 1, 0.82, 0, true)
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
	-- event per slot, so reading waits a moment for both to settle.
	local worn, pending = {}, false
	local function Settle()
		pending = false
		local main = GetInventoryItemID("player", INVSLOT_MAINHAND)
		if main and ns.Fishing.IsPole(main) then
			if not Char().beforeFishing and next(worn) then
				Char().beforeFishing = worn
			end
		elseif main then
			-- A weapon back in hand ends it; an empty hand keeps it, so a pole put away still leaves the badge.
			Char().beforeFishing = nil
			worn = { [INVSLOT_MAINHAND] = main, [INVSLOT_OFFHAND] = GetInventoryItemID("player", INVSLOT_OFFHAND) }
		end
		RefreshBags()
	end
	ns.On("PLAYER_EQUIPMENT_CHANGED", function(slot)
		if (slot == INVSLOT_MAINHAND or slot == INVSLOT_OFFHAND) and not pending then
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
	Settle()
end)
