-- Exercise Gear's registered bag action and actual panel callbacks. Native menus are forbidden: the client
-- assertion was in AcquireMenu, outside Lua's error handling. Rendering still needs a client check.
local function noop() end
local frames, named, initializers = {}, {}, {}
local popup, picker, click, mode
local equipped, usedSets = {}, {}
local function region()
	return {
		SetPoint = noop,
		SetWidth = noop,
		SetText = function(self, text)
			self.text = text
		end,
	}
end
local function frame(kind, name, parent, template)
	local f = { kind = kind, parent = parent, template = template, scripts = {}, shown = true }
	function f:SetSize(width, height)
		self.width, self.height = width, height
	end
	function f:SetHeight(height)
		self.height = height
	end
	function f:SetWidth(width)
		self.width = width
	end
	function f:SetPoint(...)
		self.point = { ... }
	end
	function f:ClearAllPoints()
		self.point = nil
	end
	function f:SetScript(event, callback)
		self.scripts[event] = callback
	end
	function f:Show()
		self.shown = true
	end
	function f:Hide()
		self.shown = false
	end
	function f:SetText(text)
		assert(self.kind == "Button", "checkbutton text belongs to its template's Text region")
		self.text = text
	end
	function f:SetChecked(value)
		assert(self.kind == "CheckButton", "row pools cannot mix frame kinds")
		self.checked = value
	end
	function f:SetScrollChild(child)
		self.child = child
	end
	function f:SetVerticalScroll(value)
		self.scroll = value
	end
	function f:SetPropagateKeyboardInput(value)
		self.propagate = value
	end
	f.SetFrameStrata, f.SetClampedToScreen, f.EnableKeyboard = noop, noop, noop
	f.CreateFontString = region
	if template == "BasicFrameTemplateWithInset" then
		f.TitleText = region()
		f.CloseButton = { shown = true }
	end
	if kind == "CheckButton" then
		f.Text = region()
	end
	frames[#frames + 1] = f
	if name then
		named[name] = f
	end
	return f
end
local saved =
	{ groups = { Healing = { [100] = true }, Other = { [101] = true } }, colours = {}, beforeFishing = { [16] = 100 } }
local env = setmetatable({
	CreateFrame = frame,
	UIParent = {},
	TweaksForeverCharDB = saved,
	INVSLOT_MAINHAND = 16,
	INVSLOT_OFFHAND = 17,
	Enum = { TooltipDataType = { Item = 0 } },
	MenuUtil = {
		CreateContextMenu = function()
			error("native AcquireMenu path is forbidden")
		end,
	},
	C_Container = {
		GetContainerItemID = function()
			return 100
		end,
	},
	C_Item = {
		GetItemInfoInstant = function()
			return 100, nil, nil, "INVTYPE_WEAPON"
		end,
		GetItemNameByID = function()
			return "Test sword"
		end,
		GetItemCount = function()
			return 1
		end,
		EquipItemByName = function(item, slot)
			equipped[#equipped + 1] = { item, slot }
		end,
	},
	C_EquipmentSet = {
		GetEquipmentSetIDs = function()
			return { 10 }
		end,
		GetEquipmentSetInfo = function()
			return "Arena"
		end,
		GetItemIDs = function()
			return { [16] = 100 }
		end,
		UseEquipmentSet = function(id)
			usedSets[#usedSets + 1] = id
		end,
	},
	ColorPickerFrame = {
		SetupColorPickerAndShow = function(_, options)
			picker = options
		end,
		GetColorRGB = function()
			return 0.1, 0.2, 0.3
		end,
	},
	StaticPopup_ShowCustomGenericInputBox = function(options)
		popup = options
	end,
	strtrim = function(text)
		return text:match("^%s*(.-)%s*$")
	end,
	GetInventoryItemID = function()
		return nil
	end,
	InCombatLockdown = function()
		return false
	end,
	IsControlKeyDown = function()
		return true
	end,
	IsAltKeyDown = function()
		return false
	end,
	IsShiftKeyDown = function()
		return false
	end,
	CursorHasItem = function()
		return false
	end,
}, { __index = _G })
local ns = {
	Feature = noop,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
	Active = function()
		return true
	end,
	ForEachBagButton = noop,
	On = noop,
	OnSettingChanged = noop,
	OnTooltip = noop,
	IsBagActionClick = function()
		return false
	end,
	HookBagButtons = function(_, fn)
		click = fn
	end,
	ClickMode = function(value)
		mode = value
	end,
	Fishing = {
		IsPole = function()
			return false
		end,
	},
	db = { gearMark = "none" },
}
assert(loadfile("Locales/enUS.lua"))("TweaksForever", ns)
setfenv(assert(loadfile("Gear.lua")), env)("TweaksForever", ns)
for _, fn in ipairs(initializers) do
	fn()
end
local owner = {
	GetBagID = function()
		return 0
	end,
	GetID = function()
		return 1
	end,
}
local function open()
	click(owner, "RightButton")
end
local function row(text)
	for _, f in ipairs(frames) do
		local label = f.text or (f.Text and f.Text.text)
		if f.shown and label and label:gsub("|cff%x%x%x%x%x%x", ""):gsub("|r", "") == text then
			return f
		end
	end
	error("no visible row: " .. text)
end
local function press(text)
	local f = row(text)
	f.scripts.OnClick(f)
end
open()
local panel = assert(named.TweaksForeverGearPanel)
assert(panel.shown and panel.CloseButton.shown, "stock close button stays available")
assert(row("Healing").checked and not row("Other").checked, "saved membership drives checks")
press("Healing")
assert(saved.groups.Healing == nil and panel.shown, "real checkbox removes final member and refreshes")
press("Other")
assert(saved.groups.Other[100] and row("Other").checked, "real checkbox persists new member")
press("New group...")
assert(popup and not panel.shown)
popup.callback("  Levelling  ")
assert(saved.groups.Levelling[100] and row("Levelling").checked, "new-group acceptance reopens fresh rows")
press("Equip Levelling")
assert(equipped[#equipped][1] == 100 and not panel.shown, "group equips through its real action")
open()
press("Equip Arena")
assert(usedSets[#usedSets] == 10, "equipment set remains separate")
open()
press("Equip Before fishing")
assert(equipped[#equipped][2] == 16, "fishing equipment action remains available")
open()
press("Colour: Levelling")
assert(picker and not panel.shown)
picker.swatchFunc()
assert(saved.colours.group.Levelling[1] == 0.1)
picker.cancelFunc({ r = 0.7, g = 0.6, b = 0.5 })
assert(saved.colours.group.Levelling[1] == 0.7, "colour cancellation restores the chosen group")
for i = 1, 30 do
	saved.groups["Group " .. i] = { [101] = true }
end
open()
local highWater = #frames
for _ = 1, 20 do
	open()
end
assert(#frames == highWater, "reopening reuses frames")
for name in pairs(saved.groups) do
	saved.groups[name] = nil
end
open()
assert(row("New group...").kind == "Button", "shrinking groups preserves action frame kinds")
local scroll
for _, f in ipairs(frames) do
	if f.kind == "ScrollFrame" then
		scroll = f
	end
end
assert(scroll and scroll.child and scroll.scroll == 0, "dynamic rows use resettable scroll content")
mode.Apply(owner, 0, 1)
panel.scripts.OnKeyDown(panel, "A")
assert(panel.propagate and panel.shown, "ordinary keys pass through")
panel.scripts.OnKeyDown(panel, "ESCAPE")
assert(not panel.shown and not panel.propagate, "Escape closes only the panel")
print("gear UI: native-menu avoidance, membership, creation, equipment, colours, pools and keyboard: ok")
