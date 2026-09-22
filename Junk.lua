local _, ns = ...

local conflicts = {
	{ addon = "Peddler" },
	{ addon = "Scrap" },
	{ addon = "Dejunk" },
	{ addon = "Vendor" },
}

ns.Feature({
	key = "markJunk",
	category = "Vendors",
	name = "Mark items as junk",
	tooltip = "Alt+Right-click a bag item to toggle its account-wide junk mark."
		.. " The merchant's Sell All Junk also sells marked items.",
	default = false,
	conflicts = conflicts,
})

ns.Feature({
	key = "sellJunk",
	category = "Vendors",
	name = "Sell junk automatically",
	tooltip = "Sell up to 12 grey or marked stacks per merchant visit."
		.. " With Leatrix Plus auto-selling, only marked non-grey items are sold here.",
	default = true,
	-- Leatrix owns only greys; disabling this feature entirely would strand our marks.
	conflicts = conflicts,
})

local Model = {}
ns.Junk = Model
local BATCH_SIZE = 12
local POOR = 0

function Model.Toggle(marks, itemID)
	marks[itemID] = not marks[itemID] or nil
	return marks[itemID] == true
end

function Model.IsJunk(info, marks, includeGreys)
	if not info or not info.itemID or info.quality == nil then
		return false
	end
	if info.quality == POOR then
		return includeGreys
	end
	return marks[info.itemID] == true
end

function Model.SaleValue(info, price, marks, includeGreys)
	if
		not Model.IsJunk(info, marks, includeGreys)
		or info.isLocked
		or info.hasNoValue
		or not price
		or price <= 0
		or not info.stackCount
		or info.stackCount <= 0
	then
		return nil
	end
	return price * info.stackCount
end

function Model.SameStack(before, after)
	return after
		and before.itemID == after.itemID
		and before.hyperlink == after.hyperlink
		and before.stackCount == after.stackCount
		and not after.isLocked
end

local emptyMarks = {}
local function Marks()
	return ns.Active("markJunk") and TweaksForeverDB.junk or emptyMarks
end

local function LeatrixSellsGreys()
	return C_AddOns.IsAddOnLoaded("Leatrix_Plus") and LeaPlusDB and LeaPlusDB.AutoSellJunk == "On"
end

ns.Init(function()
	local hooked, icons = {}, {}
	local merchant, batch, confirmationVisit
	local UpdateMerchantButton, Start
	local extendedButton = false

	local function Info(button)
		return C_Container.GetContainerItemInfo(button:GetBagID(), button:GetID())
	end

	local function UpdateIcon(button)
		if not ns.Active("markJunk") and not icons[button] then
			return
		end
		local info = Info(button)
		local marked = info and info.quality ~= POOR and Marks()[info.itemID]
		icons[button] = marked or nil
		-- Recompute the native branch too, so unmarking cannot leave an old icon behind.
		local grey = info and info.quality == POOR and not info.hasNoValue and MerchantFrame:IsShown()
		button.JunkIcon:SetShown(not not (marked or grey))
	end

	local function RefreshBags()
		for button in pairs(hooked) do
			if button:IsShown() then
				UpdateIcon(button)
			end
		end
	end

	local function Mark(button, mouseButton)
		if
			mouseButton ~= "RightButton"
			or not ns.Active("markJunk")
			or not IsAltKeyDown()
			or IsControlKeyDown()
			or IsShiftKeyDown()
			or CursorHasItem()
		then
			return
		end
		-- Mainline has no Alt+Right-click bag action; leave user-remapped gestures alone.
		for _, action in ipairs({ "EXPANDITEM", "CHATLINK", "DRESSUP", "SPLITSTACK", "AUTOLOOTTOGGLE" }) do
			if IsModifiedClick(action) then
				return
			end
		end
		local info = Info(button)
		if not info or info.isLocked then
			return
		end
		Model.Toggle(TweaksForeverDB.junk, info.itemID)
		RefreshBags()
		UpdateMerchantButton()
		if GameTooltip:GetOwner() == button then
			button:OnUpdate()
		end
	end

	-- A bag reports its size before its buttons exist, so a slot can have no button yet.
	local function HookButton(button)
		if not button or hooked[button] then
			return
		end
		hooked[button] = true
		hooksecurefunc(button, "UpdateJunkItem", UpdateIcon)
		-- OnModifiedClick avoids ever running after the ordinary use/equip/sell path.
		hooksecurefunc(button, "OnModifiedClick", Mark)
	end

	local function Scan(includeGreys, limit)
		local result, pending = {}, false
		local marks = Marks()
		for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
			for slot = 1, C_Container.GetContainerNumSlots(bag) do
				local info = C_Container.GetContainerItemInfo(bag, slot)
				if info and info.quality == nil then
					C_Item.GetItemInfo(info.hyperlink)
					pending = true
				end
				if Model.IsJunk(info, marks, includeGreys) and not info.hasNoValue and not info.isLocked then
					local price = select(11, C_Item.GetItemInfo(info.hyperlink))
					pending = pending or price == nil
					local value = Model.SaleValue(info, price, marks, includeGreys)
					local purchase = value and C_Container.GetContainerItemPurchaseInfo(bag, slot, false)
					-- Refundable purchases belong to Blizzard's confirmation flow.
					if value and not (purchase and purchase.refundSeconds and purchase.refundSeconds > 0) then
						result[#result + 1] = { bag = bag, slot = slot, info = info, value = value }
						if #result == limit then
							return result, pending
						end
					end
				end
			end
		end
		return result, pending
	end

	local function ManualEnabled()
		return ns.Active("markJunk") and not ns.ConflictOf("sellJunk")
	end

	UpdateMerchantButton = function()
		if not MerchantFrame:IsShown() then
			return
		end
		local marked = ManualEnabled() and #Scan(false, 1) > 0
		if not marked and not extendedButton then
			return
		end
		extendedButton = marked
		local hasJunk = marked or C_MerchantFrame.GetNumJunkItems() > 0
		MerchantSellAllJunkButton:SetEnabled(hasJunk)
		MerchantSellAllJunkButton.Icon:SetDesaturated(not hasJunk)
	end

	local function Finish(run)
		if batch ~= run then
			return
		end
		batch = nil
		local waiting = run.waiting
		if waiting and not C_Container.GetContainerItemInfo(waiting.bag, waiting.slot) then
			run.sold, run.money = run.sold + 1, run.money + waiting.value
		end
		if run.sold > 0 then
			ns.Print(("Sold %d junk stacks for %s."):format(run.sold, C_CurrencyInfo.GetCoinTextureString(run.money)))
		end
		UpdateMerchantButton()
		if run.manualPending and merchant == run.merchant then
			Start(true)
		elseif merchant == run.merchant and merchant.retry then
			merchant.retry = nil
			Start(false)
		end
	end

	local function Allowed(run)
		return merchant == run.merchant
			and MerchantFrame:IsShown()
			and MerchantFrame.selectedTab == 1
			and not InCombatLockdown()
			and not CursorHasItem()
			and not InRepairMode()
			and ((run.manual and ManualEnabled()) or (not run.manual and ns.Active("sellJunk")))
	end

	local Step
	Step = function(run)
		if batch ~= run then
			return
		end
		if not Allowed(run) then
			Finish(run)
			return
		end
		if run.waiting then
			local item = run.waiting
			local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
			if not info then
				run.sold, run.money = run.sold + 1, run.money + item.value
				run.waiting = nil
			elseif run.polls < 10 then
				run.polls = run.polls + 1
				C_Timer.After(0.2, function()
					Step(run)
				end)
				return
			else
				-- A rejected or unacknowledged sale must not turn into an endless retry loop.
				Finish(run)
				return
			end
		end
		while run.index <= #run.items do
			local item = run.items[run.index]
			run.index = run.index + 1
			local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
			local includeGreys = not run.manual and not LeatrixSellsGreys()
			local price = item.value / item.info.stackCount
			local purchase = info and C_Container.GetContainerItemPurchaseInfo(item.bag, item.slot, false)
			if
				Model.SameStack(item.info, info)
				and Model.SaleValue(info, price, Marks(), includeGreys)
				and not (purchase and purchase.refundSeconds and purchase.refundSeconds > 0)
			then
				run.waiting, run.polls = item, 0
				if not run.manual then
					merchant.remaining = merchant.remaining - 1
				end
				C_Container.UseContainerItem(item.bag, item.slot)
				C_Timer.After(0.2, function()
					Step(run)
				end)
				return
			end
		end
		Finish(run)
	end

	Start = function(manual)
		if manual and batch then
			batch.manualPending = true
		end
		if not merchant or batch or (not manual and (merchant.remaining == 0 or not ns.Active("sellJunk"))) then
			return
		end
		local run = { merchant = merchant, manual = manual, index = 1, sold = 0, money = 0 }
		if not Allowed(run) then
			return
		end
		local pending
		run.items, pending = Scan(not manual and not LeatrixSellsGreys(), manual and BATCH_SIZE or merchant.remaining)
		if not manual then
			merchant.pending = pending
		end
		if #run.items > 0 then
			batch = run
			Step(run)
		end
	end

	hooksecurefunc(ContainerFrameItemButtonMixin, "OnLoad", HookButton)
	hooksecurefunc("ContainerFrame_GenerateFrame", function(container)
		for _, button in container:EnumerateValidItems() do
			HookButton(button)
			UpdateIcon(button)
		end
	end)
	for _, container in ContainerFrameUtil_EnumerateContainerFrames() do
		for _, button in container:EnumerateValidItems() do
			HookButton(button)
		end
	end
	hooksecurefunc(GameTooltip, "SetBagItem", function(tooltip, bag, slot)
		local itemID = C_Container.GetContainerItemID(bag, slot)
		if itemID and Marks()[itemID] then
			tooltip:AddLine("Marked as junk – Alt+Right-click to unmark", 1, 0.82, 0, true)
			tooltip:Show()
		end
	end)
	hooksecurefunc("MerchantFrame_Update", UpdateMerchantButton)
	MerchantSellAllJunkButton:HookScript("OnClick", function()
		confirmationVisit = merchant
	end)
	MerchantSellAllJunkButton:HookScript("OnEnter", function()
		if ManualEnabled() then
			GameTooltip:AddLine("Also sells up to 12 marked non-grey stacks.", 1, 0.82, 0, true)
			GameTooltip:Show()
		end
	end)
	-- The native popup captures its callback; a post-accept hook preserves confirmation and grey sales.
	hooksecurefunc(StaticPopupDialogs.GENERIC_CONFIRMATION, "OnAccept", function(_, data)
		if data.text == SELL_ALL_JUNK_ITEMS_POPUP and confirmationVisit == merchant and ManualEnabled() then
			confirmationVisit = nil
			Start(true)
		end
	end)
	ns.On("MERCHANT_SHOW", function()
		merchant = { remaining = BATCH_SIZE }
		local visit = merchant
		C_Timer.After(0.2, function()
			if merchant == visit then
				Start(false)
				UpdateMerchantButton()
			end
		end)
	end)
	ns.On("MERCHANT_CLOSED", function()
		merchant, confirmationVisit = nil, nil
		if batch then
			Finish(batch)
		end
		RefreshBags()
	end)
	ns.On("BAG_UPDATE_DELAYED", function()
		RefreshBags()
		UpdateMerchantButton()
	end)
	ns.On("GET_ITEM_INFO_RECEIVED", function()
		UpdateMerchantButton()
		if merchant and merchant.pending then
			if batch then
				merchant.retry = true
			else
				Start(false)
			end
		end
	end)
	RefreshBags()
end)
