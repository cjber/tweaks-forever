-- Exercise Frames.lua's real installation, lazy addon discovery and Edit Mode controls.
local function Run(installed, early, fromEditor)
	local callbacks, events, initializers, pending, frames = {}, {}, {}, {}, {}
	local combat = false
	local methods = {}
	local function noop() end
	local function frame(parent, template)
		local result = setmetatable(
			{ parent = parent, template = template, scripts = {}, points = {}, scale = 1, shown = true },
			{ __index = methods }
		)
		frames[#frames + 1] = result
		return result
	end
	for _, key in ipairs({
		"SetFrameStrata",
		"SetMovable",
		"SetClampedToScreen",
		"SetDontSavePosition",
		"EnableMouse",
		"RegisterForDrag",
		"StopMovingOrSizing",
		"StartMoving",
		"SetAllPoints",
		"SetScrollChild",
		"ShowHighlighted",
		"ShowSelected",
		"Init",
	}) do
		methods[key] = noop
	end
	function methods:SetScript(key, fn)
		self.scripts[key] = fn
	end
	function methods:HookScript(key, fn)
		local previous = self.scripts[key]
		self.scripts[key] = function(...)
			if previous then
				previous(...)
			end
			fn(...)
		end
	end
	function methods:Show()
		self.shown = true
		if self.scripts.OnShow then
			self.scripts.OnShow(self)
		end
	end
	function methods:Hide()
		self.shown = false
		if self.scripts.OnHide then
			self.scripts.OnHide(self)
		end
	end
	function methods:IsShown()
		return self.shown
	end
	function methods:SetShown(shown)
		if shown then
			self:Show()
		else
			self:Hide()
		end
	end
	function methods:SetSize(w, h)
		self.width, self.height = w, h
	end
	function methods:GetSize()
		return self.width or 800, self.height or 496
	end
	function methods:SetHeight(h)
		self.height = h
	end
	function methods:GetHeight()
		return self.height or 496
	end
	function methods:GetWidth()
		return self.width or 800
	end
	function methods:SetScale(scale)
		assert(not combat)
		self.scale = scale
	end
	function methods:GetScale()
		return self.scale
	end
	function methods:GetEffectiveScale()
		return self.scale
	end
	function methods:GetParent()
		return self.parent
	end
	function methods:GetNumPoints()
		return #self.points
	end
	function methods:GetPoint(index)
		return unpack(self.points[index])
	end
	function methods:ClearAllPoints()
		assert(not combat)
		self.points = {}
	end
	function methods:SetPoint(...)
		assert(not combat)
		self.points[#self.points + 1] = { ... }
	end
	function methods:GetCenter()
		return self.x or 400, self.y or 300
	end
	function methods.GetLeft()
		return 0
	end
	function methods.GetBottom()
		return 0
	end
	function methods:SetFrameLevel(level)
		self.level = level
	end
	function methods:GetFrameLevel()
		return self.level or 1
	end
	function methods:SetText(text)
		self.text = text
	end
	function methods:GetText()
		return self.text
	end
	function methods:CreateFontString()
		return frame(self)
	end
	function methods:SetID(id)
		self.id = id
	end
	function methods:SetLabelText(text)
		self.label = text
	end
	function methods:SetCallback(fn)
		self.callback = fn
	end
	function methods:IsControlChecked()
		return self.checked
	end
	function methods:RegisterCallback(event, fn, owner)
		self.callbacks = self.callbacks or {}
		self.callbacks[event] = function(...)
			fn(owner, ...)
		end
	end
	function methods:SetSystem(system)
		self.systemInfo = system
	end
	function methods:GetAttribute(key)
		return self.attributes and self.attributes[key]
	end

	local function fire(event, ...)
		for _, entry in ipairs(callbacks[event] or {}) do
			entry.fn(entry.owner, ...)
		end
		if events[event] then
			events[event](...)
		end
	end
	local function flush()
		local count = 0
		while #pending > 0 do
			count = count + 1
			assert(count < 30, "refresh must settle")
			local jobs = pending
			pending = {}
			for _, fn in ipairs(jobs) do
				fn()
			end
		end
	end
	local root = frame()
	root:SetSize(1600, 900)
	local manager = frame(root)
	manager.layoutInfo = { activeLayout = 1 }
	manager.Title = frame(manager)
	manager.Title:SetText("Edit Mode")
	manager.GetLayouts = function()
		return { { layoutName = "Solo", layoutType = 1 }, { layoutName = "Raid", layoutType = 1 } }
	end
	manager.IsEditModeActive = function()
		return false
	end
	manager.ClearSelectedSystem = noop
	manager.IsSnapEnabled = function()
		return false
	end
	manager.GetRegions = function()
		return manager.Title
	end
	manager.GetChildren = function() end
	methods.GetAlpha = function()
		return 1
	end
	methods.SetAlpha = noop
	local settingsDialog = frame(root)
	local env = setmetatable({
		UIParent = root,
		EditModeManagerFrame = manager,
		EditModeSystemSettingsDialog = settingsDialog,
		EditModeLayoutDialog = frame(root),
		EditModeImportLayoutDialog = frame(root),
		Enum = { EditModeLayoutType = { Preset = 0, Account = 1, Character = 2 } },
		InCombatLockdown = function()
			return combat
		end,
		UnitGUID = function()
			return "Player-1"
		end,
		UIPanelWindows = {},
		GetUIPanelLayoutAttribute = function(key)
			return key == "TOP_OFFSET" and -116 or 16
		end,
		C_Timer = {
			After = function(_, fn)
				pending[#pending + 1] = fn
			end,
		},
		EventRegistry = {
			RegisterCallback = function(_, event, fn, owner)
				callbacks[event] = callbacks[event] or {}
				table.insert(callbacks[event], { fn = fn, owner = owner })
			end,
			TriggerEvent = function(_, event, ...)
				fire(event, ...)
			end,
		},
		C_AddOns = {
			DoesAddOnExist = function()
				return installed
			end,
			LoadAddOn = noop,
		},
		CreateFrame = function(_, _, parent, template)
			local created = frame(parent, template)
			if template == "PanelTabButtonTemplate" then
				parent.Tabs = parent.Tabs or {}
				parent.Tabs[#parent.Tabs + 1] = created
			end
			return created
		end,
		NineSliceUtil = { ApplyLayoutByName = noop },
		PanelTemplates_SetNumTabs = noop,
		PanelTemplates_SetTab = noop,
		MinimalSliderWithSteppersMixin = { Event = { OnValueChanged = "value" } },
		SOUNDKIT = { IG_CHARACTER_INFO_TAB = 1 },
		PlaySound = noop,
	}, { __index = _G })
	env._G = env
	local ns = {
		db = {},
		Feature = noop,
		Init = function(fn)
			initializers[#initializers + 1] = fn
		end,
		Active = function()
			return true
		end,
		On = function(event, fn)
			events[event] = fn
		end,
		OnSettingChanged = noop,
		RefreshConflicts = noop,
	}
	env.hooksecurefunc = function(target, key, fn)
		if type(target) == "table" then
			assert(target == ns, "must not hook native object methods")
			local old = target[key]
			target[key] = function(...)
				old(...)
				fn(...)
			end
		end
	end
	setfenv(assert(loadfile("Locales/enUS.lua")), env)("TweaksForever", ns)
	setfenv(assert(loadfile("Frames.lua")), env)("TweaksForever", ns)
	local layout = ns.Frames.Layout(ns.db, "account:1:Solo", true)
	layout.AdventureGuideForeverWindow = { x = 0.6, y = 0.4, scale = 1.2 }
	local guide = frame(root)
	guide:SetSize(800, 496)
	guide:SetPoint("TOPLEFT", root, "TOPLEFT", 16, -116)
	guide.attributes = { ["UIPanelLayout-area"] = "doublewide" }
	if early then
		env.AdventureGuideForeverWindow = guide
	end
	initializers[1]()
	if not installed then
		fire("EditMode.Enter")
		for _, item in ipairs(frames) do
			assert(item.label ~= "Adventure Guide", "absent addon has no unusable control")
		end
		return
	end
	if fromEditor then
		env.EventRegistry:RegisterCallback("AdventureGuideForever.EnsureWindow", function()
			env.AdventureGuideForeverWindow = guide
			fire("AdventureGuideForever.WindowCreated", guide)
		end)
		fire("EditMode.Enter")
		for _, item in ipairs(frames) do
			if item.label == "Adventure Guide" then
				item.callback(true)
			end
		end
		assert(env.AdventureGuideForeverWindow == guide, "Edit Mode creates the unopened guide")
	elseif not early then
		assert(not env.AdventureGuideForeverWindow, "guide initially lazy")
		env.AdventureGuideForeverWindow = guide
		fire("AdventureGuideForever.WindowCreated", guide)
	end
	flush()
	assert(guide.scale == 1.2 and guide.points[1][1] == "CENTER", "late guide gets saved scale and position")
	assert(guide.attributes["UIPanelLayout-area"] == "doublewide", "panel ownership unchanged")
	manager.layoutInfo.activeLayout = 2
	fire("EDIT_MODE_LAYOUTS_UPDATED")
	flush()
	assert(guide.scale == 1 and guide.points[1][1] == "TOPLEFT", "fresh layout restores native defaults")
	manager.layoutInfo.activeLayout = 1
	combat = true
	fire("AdventureGuideForever.WindowLayoutChanged", guide)
	assert(guide.scale == 1, "combat postpones placement")
	combat = false
	fire("PLAYER_REGEN_ENABLED")
	flush()
	assert(guide.scale == 1.2, "placement resumes after combat")
	fire("EditMode.Enter")
	local checkbox, slider, reset
	for _, item in ipairs(frames) do
		if item.label == "Adventure Guide" then
			checkbox = item
		end
		if item.template == "MinimalSliderWithSteppersTemplate" then
			slider = item
		end
		if item.template == "EditModeSystemSettingsDialogButtonTemplate" then
			reset = item
		end
	end
	assert(checkbox and slider and reset, "guide available with scale and reset controls")
	checkbox.callback(true)
	local selection
	for _, item in ipairs(frames) do
		if item.systemInfo and item.systemInfo.GetSystemName() == "Adventure Guide" then
			selection = item
		end
	end
	assert(selection, "guide preview created")
	selection.scripts.OnMouseDown(selection)
	slider.callbacks.value(125)
	assert(guide.scale == 1.25 and layout.AdventureGuideForeverWindow.scale == 1.25, "scale control saves and applies")
	reset.scripts.OnClick(reset)
	assert(layout.AdventureGuideForeverWindow == nil and guide.scale == 1, "reset clears saved position and scale")
	assert(guide.attributes["UIPanelLayout-area"] == "doublewide", "reset preserves panel ownership")
end
Run(false, false)
Run(true, false)
Run(true, true)
Run(true, false, true)
print("frames_runtime_spec: absence, both load orders, layouts, combat, scale and reset passed")
