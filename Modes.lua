---@type string, TFNamespace
local _, ns = ...

-- Click modes: the bag actions without a modifier key, for keyboards or window managers that swallow Alt or Ctrl.
-- Like the merchant's repair mode, one is picked from a bag's portrait menu, the cursor changes over bag items
-- and a left-click applies it. Right-click, closing the bags or entering combat ends it.
---@type TFClickMode[]
local modes = {}
---@type TFClickMode?
local active

-- Declare a mode: { feature, label, tooltip, cursor, Apply(owner, bag, slot) }.
---@param mode TFClickMode
function ns.ClickMode(mode)
	modes[#modes + 1] = mode
end

-- [item button] = a transparent button over it, so Blizzard's own click path is never touched.
---@type table<ContainerFrameItemButtonTemplate, TFClickOverlay>
local overlays = {}

---@param overlay TFClickOverlay
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

---@param overlay TFClickOverlay
---@param mouseButton string
local function Click(overlay, mouseButton)
	if mouseButton == "RightButton" or not active or not ns.Active(active.feature) then
		Stop()
		return
	end
	local button = overlay:GetParent()
	active.Apply(overlay, button:GetBagID(), button:GetID())
	if GameTooltip:IsOwned(overlay) then
		ShowTooltip(overlay)
	end
end

---@param button ContainerFrameItemButtonTemplate
local function Cover(button)
	local overlay = overlays[button]
	if not overlay then
		overlay = CreateFrame("Button", nil, button) --[[@as TFClickOverlay]]
		overlay:SetAllPoints()
		overlay:SetFrameLevel(button:GetFrameLevel() + 10)
		overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		overlay:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		overlay:SetScript("OnClick", Click)
		-- The tooltip refreshes through its owner once item data loads; without this our lines drop off.
		overlay.UpdateTooltip = ShowTooltip
		overlay:SetScript("OnEnter", function(self)
			if active then
				SetCursor(active.cursor)
			end
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

---@param mode TFClickMode
local function Start(mode)
	-- The menu can be opened before combat and clicked after it starts.
	if InCombatLockdown() then
		return
	end
	active = mode
	ns.ForEachBagButton(Cover)
end

---@param owner Button
---@param root RootMenuDescriptionProxy
local function AddModes(owner, root)
	local container = owner:GetParent() --[[@as ContainerFrameTemplate]]
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

ns.Init(function()
	hooksecurefunc("ContainerFrame_GenerateFrame", function(container)
		if active then
			for _, button in container:EnumerateValidItems() do
				Cover(button)
			end
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

	Menu.ModifyMenu("MENU_CONTAINER_FRAME", AddModes)
	Menu.ModifyMenu("MENU_CONTAINER_FRAME_COMBINED", AddModes)
end)
