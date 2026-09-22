local _, ns = ...

ns.Feature({
	key = "moveWindows",
	category = "Interface",
	name = "Move and scale windows in Edit Mode",
	tooltip = "Use Windows below Edit Mode to preview, move and scale Blizzard windows. "
		.. "Changes save immediately for the current layout. Reset returns a window to Blizzard's placement.",
	default = true,
	conflicts = { { addon = "BlizzMove" }, { addon = "MoveAnything" } },
})

-- Leatrix Plus 1.60.04-forever has no window-moving option (its old FrmEnabled setting is absent).
-- Camelot uses Mainline plus explicit Camelot overrides, NOT the Classic spellbook/talent/auction UI.
-- LootFrame and Minimap already have Edit Mode systems. ProfessionsBook is a PlayerSpellsFrame tab.
local windows = {
	{ "CharacterFrame", "Character" },
	{ "PlayerSpellsFrame", "Spellbook / Talents", "Blizzard_PlayerSpells" },
	{ "WorldMapFrame", "Map / Quest log" },
	{ "QuestLogPopupDetailFrame", "Quest details" },
	{ "QuestFrame", "Quest interaction" },
	{ "GossipFrame", "Gossip" },
	{ "MerchantFrame", "Merchant" },
	{ "MailFrame", "Mailbox" },
	{ "BankFrame", "Bank" },
	{ "ClassTrainerFrame", "Trainer", "Blizzard_TrainerUI" },
	{ "AuctionHouseFrame", "Auction house", "Blizzard_AuctionHouseUI" },
	{ "FriendsFrame", "Friends / Social" },
	{ "CommunitiesFrame", "Guild" },
	{ "DressUpFrame", "Dressing room" },
	{ "TaxiFrame", "Flight paths" },
	{ "FlightMapFrame", "Flight map", "Blizzard_FlightMap" },
	{ "TradeFrame", "Trade" },
	{ "ProfessionsFrame", "Professions", "Blizzard_Professions" },
	{ "GameMenuFrame", "Game menu" },
	{ "SettingsPanel", "Settings" },
	{ "AddonList", "Addons" },
}

-- Pure storage/geometry/queue helpers. No frame objects are written to SavedVariables.
local Model = {}
ns.Frames = Model

function Model.LayoutKey(layout, index, character)
	if not layout then
		return nil
	end
	if layout.layoutType == Enum.EditModeLayoutType.Preset then
		return "preset:" .. index
	end
	local owner = layout.layoutType == Enum.EditModeLayoutType.Character and character or "account"
	return owner .. ":" .. layout.layoutType .. ":" .. layout.layoutName
end

function Model.Layout(db, key, create)
	if not key then
		return nil
	end
	if create then
		db.windowLayouts = db.windowLayouts or {}
		db.windowLayouts[key] = db.windowLayouts[key] or {}
	end
	return db.windowLayouts and db.windowLayouts[key]
end

function Model.Rename(db, oldKey, newKey)
	if db.windowLayouts and oldKey and newKey and oldKey ~= newKey then
		db.windowLayouts[newKey] = db.windowLayouts[oldKey]
		db.windowLayouts[oldKey] = nil
	end
end

function Model.Prune(db, keys, character)
	local live = {}
	for _, key in ipairs(keys) do
		live[key] = true
	end
	for key in pairs(db.windowLayouts or {}) do
		local owner = key:match("^([^:]+):")
		if (owner == "account" or owner == character or owner == "preset") and not live[key] then
			db.windowLayouts[key] = nil
		end
	end
end

function Model.Serialize(x, y, effectiveScale, parentScale, width, height, scale, left, bottom)
	if not x or not y or width <= 0 or height <= 0 then
		return nil
	end
	return {
		x = (x * effectiveScale / parentScale - (left or 0)) / width,
		y = (y * effectiveScale / parentScale - (bottom or 0)) / height,
		scale = scale,
	}
end

function Model.Restore(position, effectiveScale, parentScale, width, height)
	return position.x * width * parentScale / effectiveScale, position.y * height * parentScale / effectiveScale
end

function Model.Snap(value, extent, spacing)
	return (math.floor((value * extent - extent / 2) / spacing + 0.5) * spacing + extent / 2) / extent
end

function Model.NewQueue(blocked)
	local queue = { pending = {} }
	function queue:Run(key, fn)
		if blocked() then
			self.pending[key] = fn
		else
			self.pending[key] = nil
			fn()
		end
	end
	function queue:Flush()
		if blocked() then
			return
		end
		local pending = self.pending
		self.pending = {}
		for key, fn in pairs(pending) do
			self:Run(key, fn)
		end
	end
	return queue
end

local records, layoutKeys = {}, {}
local manager, tabs, sheet, faded, dialog, selected, layoutKey
local editing, installed, scheduled = false, false, false
local queue = Model.NewQueue(function()
	return InCombatLockdown()
end)

local function Active()
	return ns.Active("moveWindows")
end

local function Position(record)
	local layout = Model.Layout(ns.db, layoutKey)
	return layout and layout[record.name]
end

local function Points(frame)
	local points = {}
	for index = 1, frame:GetNumPoints() do
		points[index] = { frame:GetPoint(index) }
	end
	return points
end

local function Place(frame, position)
	local x, y = Model.Restore(
		position,
		frame:GetEffectiveScale(),
		UIParent:GetEffectiveScale(),
		UIParent:GetWidth(),
		UIParent:GetHeight()
	)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

local function Serialize(frame, scale)
	local x, y = frame:GetCenter()
	return Model.Serialize(
		x,
		y,
		frame:GetEffectiveScale(),
		UIParent:GetEffectiveScale(),
		UIParent:GetWidth(),
		UIParent:GetHeight(),
		scale,
		UIParent:GetLeft(),
		UIParent:GetBottom()
	)
end

local function Apply(record)
	local frame = record.frame
	if not frame then
		return
	end
	local restored = false
	queue:Run(record, function()
		-- Read the current layout and toggle on execution, never a stale combat-time position.
		local position = Active() and Position(record)
		if record.name == "WorldMapFrame" and frame:IsMaximized() then
			position = nil
		end
		record.applying = true
		if position then
			frame:SetScale(record.scale * position.scale)
			Place(frame, position)
			record.applied = true
		elseif record.applied then
			frame:SetScale(record.scale)
			frame:ClearAllPoints()
			for _, point in ipairs(record.points) do
				frame:SetPoint(unpack(point))
			end
			record.applied = false
			restored = true
		end
		record.applying = false
	end)
	return restored
end

local function RefreshPreview(record)
	local preview = record.preview
	if not preview or record.dragging then
		return
	end
	local frame, position = record.frame, Position(record)
	local width, height = 360, 440 -- Placeholder only, until the window's addon has loaded.
	local scale = 1
	if frame then
		width, height = frame:GetSize()
		scale = record.scale * frame:GetParent():GetEffectiveScale() / UIParent:GetEffectiveScale()
		if record.name == "CharacterFrame" then
			-- Camelot applies these dimensions only on opening; its inherited XML size is smaller.
			width = frame:IsRightPaneCollapsed() and CHARACTER_FRAME_COLLAPSED_WIDTH or CHARACTER_FRAME_WIDTH
			height = CHARACTER_FRAME_HEIGHT
		elseif record.name == "WorldMapFrame" then
			-- Opened minimized, as the quest log (L) does, with the log beside the map when it is shown.
			width = frame.minimizedWidth + (frame:ShouldShowQuestLogPanel() and frame.questLogWidth or 0)
			height = frame.minimizedHeight
		end
	end
	preview:SetSize(width, height)
	preview:SetScale(scale * (position and position.scale or 1))
	preview:ClearAllPoints()
	local panel = UIPanelWindows[record.name]
	if panel and panel.centerFrameSkipAnchoring then
		panel = nil -- The game menu centres itself.
	end
	if position then
		Place(preview, position)
	elseif panel then
		-- Where the panel manager opens it on its own (UpdateUIPanelPositions), not wherever its XML left it.
		local x = GetUIPanelLayoutAttribute("LEFT_OFFSET") + (panel.xoffset or 0)
		local y = GetUIPanelLayoutAttribute("TOP_OFFSET") + (panel.yoffset or 0)
		preview:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x / preview:GetScale(), y / preview:GetScale())
	elseif frame and frame:GetCenter() then
		Place(preview, Serialize(frame, 1))
	else
		preview:SetPoint("CENTER", UIParent, "CENTER")
	end
end

local function ClearSelection()
	if selected then
		selected.preview.Selection:ShowHighlighted()
		selected = nil
	end
	if dialog then
		dialog:Hide()
	end
end

local WINDOWS_TAB = 2
local SHEET_MIN_HEIGHT = 420

-- Everything the manager draws except the grid and snap lines, which stay useful on the Windows tab.
local function ManagerArt()
	local art = { manager:GetRegions() }
	for _, child in ipairs({ manager:GetChildren() }) do
		if child ~= manager.Grid and child ~= manager.MagnetismPreviewLinesContainer then
			art[#art + 1] = child
		end
	end
	return art
end

local function ShowTab(id)
	PanelTemplates_SetTab(tabs, id)
	local onWindows = id == WINDOWS_TAB
	sheet:SetShown(onWindows)
	-- The Windows tab covers the manager and fades its own controls. Hiding them or re-running its Layout
	-- from here would taint Edit Mode's secure layout code; alpha is not Lua state, so it stays clean.
	if onWindows and not faded then
		faded = {}
		for _, region in ipairs(ManagerArt()) do
			faded[region] = region:GetAlpha()
			region:SetAlpha(0)
		end
	elseif not onWindows and faded then
		for region, alpha in pairs(faded) do
			region:SetAlpha(alpha)
		end
		faded = nil
	end
	tabs.Tabs[1]:ClearAllPoints()
	tabs.Tabs[1]:SetPoint("TOPLEFT", onWindows and sheet or manager, "BOTTOMLEFT", 11, 2)
end

local function FitSheet()
	sheet:SetHeight(math.max(SHEET_MIN_HEIGHT, manager:GetHeight()))
end

local function HideEditor()
	ClearSelection()
	if tabs then
		ShowTab(1) -- Gives the manager its controls back.
		tabs:Hide()
	end
	for _, record in ipairs(records) do
		if record.preview then
			record.preview:StopMovingOrSizing()
			record.dragging = nil
			record.preview:Hide()
		end
	end
end

local function SyncLayouts()
	if not manager or not manager.layoutInfo then
		return
	end
	local character = UnitGUID("player")
	local keys = {}
	for index, layout in ipairs(manager:GetLayouts()) do
		keys[index] = Model.LayoutKey(layout, index, character)
	end
	local nextKey = not manager.overrideLayoutInfo and keys[manager.layoutInfo.activeLayout] or nil
	if layoutKey ~= nextKey then
		ClearSelection()
		for _, record in ipairs(records) do
			if record.dragging then
				record.preview:StopMovingOrSizing()
				record.dragging = nil
			end
		end
	end
	layoutKey, layoutKeys = nextKey, keys
	if Active() then
		Model.Prune(ns.db, keys, character)
	end
end

local function RefreshAll()
	SyncLayouts()
	local restored = false
	for _, record in ipairs(records) do
		restored = Apply(record) or restored
		if editing and Active() then
			RefreshPreview(record)
		end
	end
	if restored then
		-- Native offsets were calculated at the old scale. Recompute them at Blizzard's scale.
		UpdateUIPanelPositions()
	end
end

-- Defer until native placement/scale calculations have finished, including private delegate calls.
-- UIParentPanelManager's FramePositionDelegate is local and forbidden on this client.
local function Schedule()
	if scheduled then
		return
	end
	scheduled = true
	C_Timer.After(0, function()
		scheduled = false
		queue:Run("refresh", RefreshAll)
	end)
end

local function Attach(record)
	local frame = _G[record.name]
	if record.frame or not frame or frame.system then
		return
	end
	record.frame, record.scale, record.points = frame, frame:GetScale(), Points(frame)
	-- Keep Blizzard's latest anchors for reset. Do not detach area/doublewide panels or write
	-- UIPanelWindows / UIPanelLayout-*; the native manager must retain occupancy and close rules.
	hooksecurefunc(frame, "SetPoint", function()
		if record.applying or not Active() then
			return
		end
		record.points = Points(frame)
		Schedule()
	end)
	hooksecurefunc(frame, "SetScale", function(_, scale)
		if record.applying or not Active() then
			return
		end
		record.scale = scale
		Schedule()
	end)
	frame:HookScript("OnShow", function()
		if Active() then
			Schedule()
		end
	end)
	frame:HookScript("OnSizeChanged", function()
		if not record.applying and Active() then
			Schedule()
		end
	end)
end

local function SavePreview(record, scale, snap)
	if not Active() or not editing or not layoutKey or InCombatLockdown() then
		return
	end
	local position = Serialize(record.preview, scale)
	if not position then
		return
	end
	if snap and manager:IsSnapEnabled() and manager.Grid:IsShown() then
		local spacing = manager.Grid.gridSpacing
		position.x = Model.Snap(position.x, UIParent:GetWidth(), spacing)
		position.y = Model.Snap(position.y, UIParent:GetHeight(), spacing)
	end
	Model.Layout(ns.db, layoutKey, true)[record.name] = position
	Apply(record)
	RefreshPreview(record)
end

local function Label(parent, text, font, x, y)
	local label = parent:CreateFontString(nil, "OVERLAY", font)
	label:SetPoint("TOPLEFT", x, y)
	label:SetText(text)
	return label
end

local function MakePanel(width, height)
	local panel = CreateFrame("Frame", nil, UIParent)
	panel:Hide()
	panel:SetSize(width, height)
	panel:SetFrameStrata("DIALOG")
	panel:SetFrameLevel(210)
	panel:SetClampedToScreen(true)
	panel:EnableMouse(true)
	CreateFrame("Frame", nil, panel, "DialogBorderTranslucentTemplate")
	return panel
end

local function UpdateSlider()
	dialog.initializing = true
	local position = selected and Position(selected)
	local value = math.floor((position and position.scale or 1) * 100 + 0.5)
	dialog.Slider:Init(value, 50, 150, 100)
	dialog.Value:SetText(value .. "%")
	dialog.initializing = false
end

local function Select(record)
	if not editing or not Active() or InCombatLockdown() or not layoutKey then
		return
	end
	-- Camelot's ClearSelectedSystem uses its native secure delegate outside combat.
	-- SelectSystem itself traverses protected systems, so never pass it an addon preview.
	manager:ClearSelectedSystem()
	selected = record
	record.preview.Selection:ShowSelected()
	dialog.Title:SetText(record.label)
	UpdateSlider()
	dialog:Show()
end

local function MakePreview(record)
	local preview = CreateFrame("Frame", nil, UIParent)
	preview:Hide()
	preview:SetMovable(true)
	preview:SetClampedToScreen(true)
	preview:SetDontSavePosition(true)
	preview:SetFrameStrata("MEDIUM")
	preview:SetFrameLevel(999)
	local selection = CreateFrame("Frame", nil, preview, "EditModeSystemSelectionTemplate")
	preview.Selection = selection
	selection:SetAllPoints()
	selection:SetSystem({
		GetSystemName = function()
			return record.label
		end,
	})
	-- Replace input handlers only on our own overlay. Native SelectSystem traverses protected HUD frames.
	selection:SetScript("OnMouseDown", function()
		Select(record)
	end)
	selection:SetScript("OnDragStart", function()
		Select(record)
		if selected == record and not InCombatLockdown() then
			record.dragging = true
			preview:StartMoving()
		end
	end)
	selection:SetScript("OnDragStop", function()
		preview:StopMovingOrSizing()
		if record.dragging then
			record.dragging = nil
			local position = Position(record)
			SavePreview(record, position and position.scale or 1, true)
		end
	end)
	selection:ShowHighlighted()
	record.preview = preview
	RefreshPreview(record)
end

local function ShowPreview(record, shown)
	if not Active() or InCombatLockdown() then
		return
	end
	if shown and record.addon and not record.frame then
		C_AddOns.LoadAddOn(record.addon)
		Attach(record)
	end
	if shown and not record.preview then
		MakePreview(record)
	end
	if record.preview then
		RefreshPreview(record)
		record.preview:SetShown(shown and editing)
	end
	if selected == record and not shown then
		ClearSelection()
	end
end

local function BuildEditor()
	-- Parented to UIParent, not the manager: a child would join the manager's ResizeLayoutFrame layout.
	tabs = CreateFrame("Frame", nil, UIParent)
	tabs:SetSize(1, 1)
	tabs:SetFrameStrata("DIALOG")
	tabs:SetFrameLevel(manager:GetFrameLevel())
	for id, text in ipairs({ "HUD", "Windows" }) do
		local tab = CreateFrame("Button", nil, tabs, "PanelTabButtonTemplate")
		tab:SetID(id)
		tab:SetText(text)
		tab:SetScript("OnClick", function()
			ShowTab(id)
			PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
		end)
	end
	PanelTemplates_SetNumTabs(tabs, #tabs.Tabs)

	sheet = CreateFrame("Frame", nil, UIParent)
	sheet:Hide()
	sheet:SetFrameStrata("DIALOG")
	sheet:SetFrameLevel(manager:GetFrameLevel() + 20)
	sheet:EnableMouse(true)
	sheet:SetPoint("TOPLEFT", manager)
	sheet:SetPoint("TOPRIGHT", manager)
	CreateFrame("Frame", nil, sheet, "DialogBorderTranslucentTemplate")
	local title = sheet:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	title:SetPoint("TOP", 0, -15)
	title:SetText(manager.Title:GetText())
	Label(
		sheet,
		"Show a window to move and scale it. Changes save at once for this layout.",
		"GameFontHighlight",
		25,
		-48
	)
	-- The same inset as Edit Mode's expanded options.
	local inset = CreateFrame("Frame", nil, sheet)
	inset:SetPoint("TOPLEFT", 25, -84)
	inset:SetPoint("BOTTOMRIGHT", -25, 24)
	NineSliceUtil.ApplyLayoutByName(inset, "UniqueCornersLayout", "OptionsFrame")
	Label(inset, "Windows", "GameFontNormalLarge", 10, -8)
	local scroll = CreateFrame("ScrollFrame", nil, inset, "ScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 4, -36)
	scroll:SetPoint("BOTTOMRIGHT", -24, 6)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(420, math.ceil(#records / 2) * 32)
	scroll:SetScrollChild(child)
	for index, record in ipairs(records) do
		local checkbox = CreateFrame("Frame", nil, child, "EditModeCheckButtonTemplate")
		checkbox:SetPoint("TOPLEFT", (index - 1) % 2 * 215, -math.floor((index - 1) / 2) * 32)
		checkbox:SetLabelText(record.label)
		checkbox:SetCallback(function(checked)
			ShowPreview(record, checked)
		end)
		record.checkbox = checkbox
	end
	manager:HookScript("OnSizeChanged", FitSheet)

	dialog = MakePanel(320, 164)
	dialog:SetPoint("TOPLEFT", manager, "TOPRIGHT", 8, 0)
	dialog.Title = Label(dialog, "", "GameFontHighlightLarge", 18, -18)
	Label(dialog, "Scale", "GameFontHighlightMedium", 18, -55)
	dialog.Slider = CreateFrame("Frame", nil, dialog, "MinimalSliderWithSteppersTemplate")
	dialog.Slider:SetSize(180, 32)
	dialog.Slider:SetPoint("TOPLEFT", 80, -46)
	dialog.Value = Label(dialog, "", "GameFontHighlightSmall", 267, -55)
	dialog.Slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
		if selected and not dialog.initializing then
			dialog.Value:SetText(math.floor(value + 0.5) .. "%")
			SavePreview(selected, value / 100)
		end
	end, dialog)
	local reset = CreateFrame("Button", nil, dialog, "EditModeSystemSettingsDialogButtonTemplate")
	reset:SetSize(284, 24)
	reset:SetPoint("TOPLEFT", 18, -94)
	reset:SetText("Reset To Default Position")
	reset:SetScript("OnClick", function()
		if not selected or not Active() or InCombatLockdown() then
			return
		end
		local layout = Model.Layout(ns.db, layoutKey)
		if layout then
			layout[selected.name] = nil
		end
		Apply(selected)
		UpdateUIPanelPositions()
		RefreshPreview(selected)
		UpdateSlider()
	end)
	Label(dialog, "Reset also restores the original scale.", "GameFontHighlightSmall", 18, -133)
	local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT")
	close:SetScript("OnClick", ClearSelection)
end

local function Enter()
	if not Active() or InCombatLockdown() or not manager:IsShown() then
		return
	end
	editing = true
	SyncLayouts()
	if not tabs then
		BuildEditor()
	end
	FitSheet()
	tabs:Show()
	ShowTab(1)
	for _, record in ipairs(records) do
		ShowPreview(record, record.checkbox:IsControlChecked())
	end
end

local function Install()
	if installed or not Active() or not EditModeManagerFrame then
		return
	end
	installed, manager = true, EditModeManagerFrame
	for _, window in ipairs(windows) do
		local record = { name = window[1], label = window[2], addon = window[3] }
		records[#records + 1] = record
		Attach(record)
	end
	SyncLayouts()
	EventRegistry:RegisterCallback("EditMode.Enter", Enter, Model)
	EventRegistry:RegisterCallback("EditMode.Exit", function()
		editing = false
		HideEditor()
	end, Model)
	manager:HookScript("OnHide", HideEditor)
	manager:HookScript("OnShow", function()
		if manager:IsEditModeActive() then
			Enter()
		end
	end)
	hooksecurefunc(manager, "SelectSystem", ClearSelection)
	hooksecurefunc(manager, "ClearSelectedSystem", ClearSelection)
	hooksecurefunc(manager, "UpdateLayoutInfo", function()
		if Active() then
			Schedule()
		end
	end)
	-- Names/types are the API's only durable identity. Indices shift on insertion/deletion.
	-- Post-hooks run before our deferred refresh, so the old key is still available after a rename.
	hooksecurefunc(manager, "RenameLayout", function(_, index)
		if Active() then
			local layout = manager:GetLayouts()[index]
			Model.Rename(ns.db, layoutKeys[index], Model.LayoutKey(layout, index, UnitGUID("player")))
			Schedule()
		end
	end)
	hooksecurefunc(manager, "DeleteLayout", function(_, index)
		if Active() and ns.db.windowLayouts and #manager:GetLayouts() < #layoutKeys then
			ns.db.windowLayouts[layoutKeys[index]] = nil
			SyncLayouts()
			Schedule()
		end
	end)
	EventRegistry:RegisterCallback("EditMode.SavedLayouts", function()
		if Active() then
			Schedule()
		end
	end, Model)
	RefreshAll()
	if manager:IsEditModeActive() then
		Enter()
	end
end

local wasActive = false
local function CheckState()
	local active = Active()
	if active then
		queue:Run("install", Install)
	end
	if active ~= wasActive then
		wasActive = active
		if not active then
			editing = false
			HideEditor()
		end
		queue:Run("state", function()
			if installed then
				if Active() then
					for _, record in ipairs(records) do
						Attach(record)
						-- Native layout may have changed while our hooks were dormant.
						if record.frame and not record.applied then
							record.scale, record.points = record.frame:GetScale(), Points(record.frame)
						end
					end
				end
				RefreshAll()
				if Active() and manager:IsEditModeActive() then
					Enter()
				end
			end
		end)
	end
end

ns.Init(function()
	-- These are checks only until enabled and conflict-free; no Blizzard frames are hooked while off.
	hooksecurefunc(ns, "RefreshConflicts", CheckState)
	Settings.SetOnValueChangedCallback("TweaksForever_moveWindows", CheckState)
	ns.On("ADDON_LOADED", function()
		ns.RefreshConflicts()
		if Active() then
			queue:Run("addons", function()
				if Active() then
					Install()
					for _, record in ipairs(records) do
						Attach(record)
					end
					Schedule()
				end
			end)
		end
	end)
	ns.On("PLAYER_REGEN_DISABLED", HideEditor)
	ns.On("PLAYER_REGEN_ENABLED", function()
		queue:Flush()
		CheckState()
		if Active() and manager and manager:IsEditModeActive() then
			Enter()
		end
	end)
	ns.On("UI_SCALE_CHANGED", function()
		if Active() then
			Schedule()
		end
	end)
	ns.On("DISPLAY_SIZE_CHANGED", function()
		if Active() then
			Schedule()
		end
	end)
	CheckState()
end)
