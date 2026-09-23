local _, ns = ...

-- Click modes: the bag actions without a modifier key, for keyboards or window managers that swallow Alt or Ctrl.
-- Like the merchant's repair mode, one is picked from a bag's portrait menu, the cursor changes over bag items
-- and a left-click applies it. Right-click, closing the bags or entering combat ends it.
local modes = {}
local active

-- Declare a mode: { feature, label, tooltip, cursor, Apply(owner, bag, slot) }.
function ns.ClickMode(mode)
	modes[#modes + 1] = mode
end

ns.Init(function()
	-- [item button] = a transparent button over it, so Blizzard's own click path is never touched.
	local overlays = {}

	local function ShowTooltip(overlay)
		local button = overlay:GetParent()
		if not C_Container.GetContainerItemID(button:GetBagID(), button:GetID()) then
			GameTooltip:Hide()
			return
		end
		GameTooltip:SetOwner(overlay, "ANCHOR_RIGHT")
		GameTooltip:SetBagItem(button:GetBagID(), button:GetID())
		GameTooltip:Show()
	end

	local function Stop()
		active = nil
		for _, overlay in pairs(overlays) do
			overlay:Hide()
		end
		ResetCursor()
	end

	local function Click(overlay, mouseButton)
		if mouseButton == "RightButton" or not ns.Active(active.feature) then
			Stop()
			return
		end
		local button = overlay:GetParent()
		active.Apply(overlay, button:GetBagID(), button:GetID())
		if GameTooltip:IsOwned(overlay) then
			ShowTooltip(overlay)
		end
	end

	local function Cover(button)
		local overlay = overlays[button]
		if not overlay then
			overlay = CreateFrame("Button", nil, button)
			overlay:SetAllPoints()
			overlay:SetFrameLevel(button:GetFrameLevel() + 10)
			overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			overlay:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
			overlay:SetScript("OnClick", Click)
			-- The tooltip refreshes through its owner once item data loads; without this our lines drop off.
			overlay.UpdateTooltip = ShowTooltip
			overlay:SetScript("OnEnter", function(self)
				SetCursor(active.cursor)
				ShowTooltip(self)
			end)
			overlay:SetScript("OnLeave", function()
				GameTooltip:Hide()
				ResetCursor()
			end)
			overlays[button] = overlay
		end
		overlay:Show()
	end

	local function CoverBag(container)
		for _, button in container:EnumerateValidItems() do
			Cover(button)
		end
	end

	local function Start(mode)
		-- The menu can be opened before combat and clicked after it starts.
		if InCombatLockdown() then
			return
		end
		active = mode
		for _, container in ContainerFrameUtil_EnumerateContainerFrames() do
			if container:IsShown() then
				CoverBag(container)
			end
		end
	end

	hooksecurefunc("ContainerFrame_GenerateFrame", function(container)
		if active then
			CoverBag(container)
		end
	end)
	EventRegistry:RegisterCallback("ContainerFrame.CloseBag", function()
		if not active then
			return
		end
		for _, container in ContainerFrameUtil_EnumerateContainerFrames() do
			if container:IsShown() then
				return
			end
		end
		Stop()
	end, overlays)
	ns.On("PLAYER_REGEN_DISABLED", function()
		if active then
			Stop()
		end
	end)

	local function AddModes(owner, root)
		local container = owner:GetParent()
		local bag = container:GetBagID()
		if InCombatLockdown() then
			return
		end
		if not container:IsCombinedBagContainer() and not (bag >= 0 and bag <= NUM_TOTAL_EQUIPPED_BAG_SLOTS) then
			return
		end
		local divided = false
		for _, mode in ipairs(modes) do
			if ns.Active(mode.feature) then
				if not divided then
					root:CreateDivider()
					divided = true
				end
				local entry = root:CreateCheckbox(mode.label, function()
					return active == mode
				end, function()
					if active == mode then
						Stop()
					else
						Start(mode)
					end
					return MenuResponse.CloseAll
				end)
				entry:SetTooltip(function(tooltip)
					GameTooltip_SetTitle(tooltip, mode.label)
					GameTooltip_AddNormalLine(tooltip, mode.tooltip)
				end)
			end
		end
	end
	Menu.ModifyMenu("MENU_CONTAINER_FRAME", AddModes)
	Menu.ModifyMenu("MENU_CONTAINER_FRAME_COMBINED", AddModes)
end)
