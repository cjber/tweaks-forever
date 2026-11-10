-- Settings rows must reach their layouts only through Settings.RegisterInitializer, which inserts them from
-- Blizzard's secure attribute delegate. A row inserted from addon code (layout:AddInitializer, or
-- Settings.CreateCheckbox/CreateDropdown, which insert from the caller) taints the settings search, and a
-- restricted button in its results (Social's Discord Sign In) is then blocked and blamed on this addon. The
-- search also reads each row's parent link, so SetParentInitializer from addon code taints it the same way.
local registered = {}
-- [key] = the addon a feature needs and can't find.
local missing = {}
local panelScripts, refreshes, gamepad = {}, 0, false

local function Layout()
	return {
		AddInitializer = function()
			error("addon code inserted a row into a settings layout; use Settings.RegisterInitializer")
		end,
	}
end

local function Initializer(kind, setting)
	return {
		kind = kind,
		setting = setting,
		modify = {},
		AddModifyPredicate = function(self, predicate)
			table.insert(self.modify, predicate)
		end,
		Indent = function(self)
			self.indented = true
		end,
		AddEvaluateStateCVar = function(self, variable)
			self.evaluate = variable
		end,
		SetParentInitializer = function()
			error("addon code linked a row to its parent; the settings search reads that link")
		end,
	}
end

local function Category(name)
	return {
		name = name,
		GetID = function()
			return name
		end,
	}, Layout()
end
local opened
local canvas
local vertical
-- Calls to the client's own restricted settings opener.
local opens = 0
-- [function] = how many secure delegates the settings built around it. Blizzard data the secure row build reads is
-- written through one, never by our code directly (#433).
local delegated = {}

local env = setmetatable({
	Settings = {
		VarType = { Boolean = "boolean", String = "string", Number = "number" },
		RegisterVerticalLayoutCategory = function(name)
			return Category(name)
		end,
		RegisterVerticalLayoutSubcategory = function(_, name)
			return Category(name)
		end,
		-- The Forever addons page: the shared module's own frame on a canvas, or its rows under the gamepad UI.
		RegisterCanvasLayoutSubcategory = function(parent, frame, name)
			canvas = { parent = parent, frame = frame, name = name }
			return Category(name)
		end,
		RegisterAddOnSetting = function(category, variable, key, _, varType, name)
			return { category = category, variable = variable, key = key, varType = varType, name = name }
		end,
		RegisterProxySetting = function(category, variable, varType, name, defaultValue, getValue, setValue)
			return {
				category = category,
				variable = variable,
				varType = varType,
				name = name,
				defaultValue = defaultValue,
				getValue = getValue,
				setValue = setValue,
				proxy = true,
			}
		end,
		CreateCheckboxInitializer = function(setting, _, tooltip)
			assert(setting.varType == "boolean")
			local initializer = Initializer("checkbox", setting)
			initializer.tooltip = tooltip
			return initializer
		end,
		CreateDropdownInitializer = function(setting, options, tooltip)
			assert(setting.varType == "string" and options)
			local initializer = Initializer("dropdown", setting)
			initializer.tooltip = tooltip
			return initializer
		end,
		CreateSliderOptions = function(minValue, maxValue, step)
			local options = { min = minValue, max = maxValue, step = step }
			function options:SetLabelFormatter(_, formatter)
				self.formatter = formatter
				self.formatterSet = true
			end
			return options
		end,
		CreateSliderInitializer = function(setting, options, tooltip)
			assert(setting.varType == "number" and options)
			local initializer = Initializer("slider", setting)
			initializer.options = options
			initializer.tooltip = tooltip
			return initializer
		end,
		RegisterInitializer = function(category, initializer)
			registered[#registered + 1] = { category = category, initializer = initializer }
		end,
		RegisterAddOnCategory = function() end,
		-- The restricted route: the client refuses this call from addon code and blames the addon, so reaching it
		-- fails the spec (cjber/forever-core#333).
		OpenToCategory = function()
			error("the settings opened through Settings.OpenToCategory, which the client refuses from addon code")
		end,
	},
	-- The shared opener wraps the client's own function in a secure delegate and calls that (Core/OpenSettings.lua).
	C_SettingsUtil = {
		OpenSettingsPanel = function(categoryID)
			opens = opens + 1
			opened = categoryID
		end,
	},
	CreateSecureDelegate = function(fn)
		delegated[fn] = (delegated[fn] or 0) + 1
		return function(...)
			return fn(...)
		end
	end,
	InCombatLockdown = function()
		return false
	end,
	CreateSettingsButtonInitializer = function(name, _, click, _, addSearchTags)
		assert(addSearchTags == false, "index buttons stay out of search")
		return { kind = "button", name = name, click = click }
	end,
	SettingsPanel = {
		HookScript = function(_, script, fn)
			panelScripts[script] = fn
		end,
	},
	InputUtil = {
		IsGamepadUIEnabled = function()
			return gamepad
		end,
	},
	MinimalSliderWithSteppersMixin = { Label = { Right = "Right" } },
	RED_FONT_COLOR = {
		WrapTextInColorCode = function(_, text)
			return text
		end,
	},
	SlashCmdList = {},
	strtrim = function(text)
		return (text:gsub("^%s+", ""):gsub("%s+$", ""))
	end,
}, { __index = _G })

local ns
ns = {
	db = {},
	features = {
		-- `needs` an addon, so its tooltip can carry a note and is read as it shows.
		{
			key = "repair",
			category = "Merchants",
			name = "Repair",
			tooltip = "Repairs.",
			needs = { title = "QuestieDB", check = function() end },
		},
		{ key = "guildRepair", category = "Merchants", name = "Guild repair", parent = "repair" },
		{
			key = "gearMark",
			category = "Bags",
			name = "Mark",
			tooltip = "Marks.",
			default = "border",
			options = { { "strip", "Strip" }, { "border", "Border" }, { "dots", "Dots" } },
		},
		{
			key = "iconSize",
			category = "Interface",
			name = "Icon size",
			default = 100,
			slider = { min = 50, max = 200, step = 5 },
		},
	},
	Init = function(fn)
		fn()
	end,
	ConflictOf = function() end,
	RefreshConflicts = function()
		refreshes = refreshes + 1
	end,
	SettingVariable = function(key)
		return "TweaksForever_" .. key
	end,
	MissingOf = function(key)
		return missing[key]
	end,
	Active = function(key)
		return ns.db[key] ~= false
	end,
	SafeCall = function(_, fn, ...)
		return pcall(fn, ...)
	end,
	ReportLines = function()
		return { "own line" }
	end,
	Family = {
		CreatePanel = function(parent, db, current, L)
			return { kind = "family panel", parent = parent, db = db, current = current, L = L }
		end,
		-- The shared page: a canvas with the mouse, the client's own rows under the gamepad UI (#382).
		Register = function(category, db, current, L)
			if env.InputUtil.IsGamepadUIEnabled() then
				vertical = env.Settings.RegisterVerticalLayoutSubcategory(category, "Forever addons")
				vertical.kind = "vertical"
				return vertical
			end
			return env.Settings.RegisterCanvasLayoutSubcategory(
				category,
				ns.Family.CreatePanel(nil, db, current, L),
				"Forever addons"
			)
		end,
	},
}
local reported
ns.Report = {
	Text = function(lines)
		return "report: " .. lines[1]
	end,
	Show = function(text)
		reported = text
	end,
	Command = function(command)
		if command == "report" then
			local ok, lines = ns.SafeCall("report lines", ns.ReportLines)
			ns.Report.Show(ns.Report.Text(ok and lines or { "Report lines failed: " .. tostring(lines) }))
			return true
		end
		return false
	end,
}
assert(loadfile("Locales/enUS.lua"))("TweaksForever", ns)
-- A packaged German client: features declare English, and the settings show the translation where there is one.
ns.L["Bags"], ns.L["Repair"], ns.L["Repairs."] = "Taschen", "Reparieren", "Repariert."
-- The shared opener is loaded first, as the TOC does: the settings page asks it, not Settings.OpenToCategory.
setfenv(assert(loadfile("Core/OpenSettings.lua")), env)("TweaksForever", ns)
assert(ns.OpenSettingsPanel, "the shared settings opener is loaded")
setfenv(assert(loadfile("UI/Settings.lua")), env)("TweaksForever", ns)

-- Rows per page, in order: each subpage's settings, then the index's button to it.
local kinds = {}
for index, entry in ipairs(registered) do
	kinds[index] = entry.initializer.kind .. "@" .. entry.category.name
end
assert(
	table.concat(kinds, " ")
		== "checkbox@Merchants checkbox@Merchants button@Tweaks Forever dropdown@Taschen button@Tweaks Forever "
			.. "slider@Interface button@Tweaks Forever button@Tweaks Forever",
	table.concat(kinds, " ")
)
local repair, guildRepair = registered[1].initializer, registered[2].initializer
-- The Forever addons page, last: the shared panel on our saved variables, with this addon's row named.
assert(canvas and canvas.name == "Forever addons" and canvas.parent.name == "Tweaks Forever")
assert(canvas.frame.kind == "family panel" and canvas.frame.db == ns.db and canvas.frame.current == "TweaksForever")
assert(canvas.frame.L == nil, "ns.Family is already bound to Tweaks' L (ForeverFamily.For)")
assert(registered[8].initializer.name == "Forever addons", "the index opens it like any other subpage")

-- The index's Open buttons, the Forever addons one included, open their page through the client's own function,
-- carried by one secure delegate. Settings.OpenToCategory is Blizzard's Lua around the restricted call, which the
-- client refuses from addon code (cjber/forever-core#333).
do
	local buttons = 0
	for _, entry in ipairs(registered) do
		local initializer = entry.initializer
		if initializer.kind == "button" then
			buttons = buttons + 1
			local before = opens
			initializer.click()
			assert(opens == before + 1, initializer.name .. ": opened through the client's own opener")
			assert(opened == initializer.name, initializer.name .. ": on its own page")
		end
	end
	assert(buttons == 4, "the index has a button per subpage and the Forever addons page")
	assert(delegated[env.C_SettingsUtil.OpenSettingsPanel] == 1, "every page opens through one secure delegate")
end

-- A failing shared panel (another addon's newer copy) leaves the rest of the settings and /tweaks working.
do
	local before, family = #registered, ns.Family
	local addOnCategories = 0
	env.Settings.RegisterAddOnCategory = function()
		addOnCategories = addOnCategories + 1
	end
	ns.Family = {
		Register = function()
			error("broken copy")
		end,
	}
	env.SLASH_TWEAKSFOREVER1 = nil
	setfenv(assert(loadfile("UI/Settings.lua")), env)("TweaksForever", ns)
	assert(addOnCategories == 1, "the category still registers")
	assert(env.SLASH_TWEAKSFOREVER1 == "/tweaks", "and /tweaks still works")
	for index = before + 1, #registered do
		assert(registered[index].initializer.name ~= "Forever addons", "no index button for a page that failed")
	end
	ns.Family = family
end
assert(repair.setting.name == "Reparieren" and repair.tooltip() == "Repariert.", "names and tooltips are translated")
assert(guildRepair.setting.name == "Guild repair", "a phrase with no translation stays English")
local function Modifiable(initializer)
	for _, predicate in ipairs(initializer.modify) do
		if not predicate() then
			return false
		end
	end
	return true
end
assert(Modifiable(repair) and not repair.indented, "conflict-free rows stay modifiable")
assert(guildRepair.indented and guildRepair.evaluate == "TweaksForever_repair", "a child row sits under its parent")
assert(
	delegated[guildRepair.Indent],
	"the row indents through a secure delegate, so Blizzard's row build reads no taint of ours (#433)"
)
assert(Modifiable(guildRepair), "a child row is modifiable while its parent is on")
ns.db.repair = false
assert(not Modifiable(guildRepair) and Modifiable(repair), "a child row greys out with its parent off")
ns.db.repair = nil
missing.repair = "QuestieDB"
assert(not Modifiable(repair), "a row missing an addon it needs is greyed out")
assert(repair.tooltip():find("Needs QuestieDB, which isn't loaded", 1, true), "and says so")
missing.repair = nil
assert(registered[4].initializer.setting.variable == "TweaksForever_gearMark")
-- A row with no conflict and no needed addon carries its text, not a function of ours: under the gamepad interface a
-- dropdown row's tooltip shows in the same call that pushes its footer bindings (#168).
assert(registered[4].initializer.tooltip == "Marks.", "a row that can't carry a note gets its text")
local size = registered[6].initializer
assert(
	size.setting.variable == "TweaksForever_iconSize" and size.setting.varType == "number",
	"a slider is a number setting"
)
assert(size.options.min == 50 and size.options.max == 200 and size.options.step == 5, "the slider takes its bounds")
assert(
	size.options.formatterSet and type(size.options.formatter) == "function",
	"without the gamepad UI the slider keeps its percentage label formatter"
)
assert(
	size.options.formatter(50) == "50%"
		and size.options.formatter(75.4) == "75%"
		and size.options.formatter(75.5) == "76%",
	"the percentage formatter rounds to the nearest whole number"
)
assert(
	delegated[env.Settings.CreateSliderOptions] and delegated[env.Settings.CreateSliderInitializer],
	"the slider's Blizzard row data is built through secure delegates (#433)"
)

-- /tweaks opens the settings; /tweaks report shows the report instead.
env.SlashCmdList.TWEAKSFOREVER("")
assert(opened == "Tweaks Forever" and reported == nil, "/tweaks opens the settings")
opened = nil
env.SlashCmdList.TWEAKSFOREVER("  Report ")
assert(reported == "report: own line" and opened == nil, "/tweaks report shows the report")
env.SlashCmdList.TWEAKSFOREVER("anything")
assert(opened == "Tweaks Forever", "anything else opens the settings")
ns.ReportLines = function()
	error("lines broke", 0)
end
env.SlashCmdList.TWEAKSFOREVER("report")
assert(reported == "report: Report lines failed: lines broke", "failing lines still open the report, saying so")
-- #168: opening the settings re-reads conflicts, except with the gamepad UI on.
assert(panelScripts.OnShow, "the settings panel's OnShow is hooked")
panelScripts.OnShow()
assert(refreshes == 1, "opening the settings re-reads conflicts")
gamepad = true
panelScripts.OnShow()
assert(refreshes == 1, "with the gamepad UI on, opening the settings skips the conflict check")
gamepad = false

-- With the gamepad interface on, a choice is a number proxy setting on a slider: opening a dropdown would run our
-- options and value code before the menu takes focus, and the binding set it removes in that same tainted call
-- blocks the action bar's protected one (#168). Without it, the choice stays the dropdown it was.
do
	local function Choice(entries)
		for _, entry in ipairs(entries) do
			local setting = entry.initializer.setting
			if setting and setting.variable == "TweaksForever_gearMark" then
				return entry.initializer
			end
		end
	end
	local desktop = Choice(registered)
	assert(desktop and desktop.kind == "dropdown", "without the gamepad UI a choice stays a dropdown")
	local before = registered
	registered = {}
	gamepad = true
	setfenv(assert(loadfile("UI/Settings.lua")), env)("TweaksForever", ns)
	gamepad = false
	assert(
		vertical and vertical.kind == "vertical" and vertical.name == "Forever addons",
		"with the gamepad UI on the Forever addons page is the client's rows (#382)"
	)
	local choice = Choice(registered)
	assert(choice and choice.kind == "slider", "with the gamepad UI on a choice is a slider")
	local child
	for _, entry in ipairs(registered) do
		local rowSetting = entry.initializer.setting
		if rowSetting and rowSetting.variable == "TweaksForever_guildRepair" then
			child = entry.initializer
		end
	end
	assert(
		child and child.indented and delegated[child.Indent],
		"with the gamepad UI on a nested row still indents through a secure delegate (#433)"
	)
	local numberSlider
	for _, entry in ipairs(registered) do
		local rowSetting = entry.initializer.setting
		if rowSetting and rowSetting.variable == "TweaksForever_iconSize" then
			numberSlider = entry.initializer
		end
	end
	assert(
		numberSlider and numberSlider.options.formatter == nil and numberSlider.options.formatterSet == nil,
		"with the gamepad UI on the number slider has no label formatter of ours (#433)"
	)
	local setting = choice.setting
	assert(setting.proxy and setting.varType == "number", "the choice is a number proxy setting")
	assert(setting.variable == "TweaksForever_gearMark" and setting.name == "Mark", "it keeps its variable and name")
	assert(setting.defaultValue == 2, "the default's index, not the string")
	assert(
		choice.options.min == 1 and choice.options.max == 3 and choice.options.step == 1,
		"one step per option, from 1 to the last"
	)
	-- The option names are text in the row's tooltip: a formatter of ours would run inside Blizzard's secure row
	-- build and taint the gamepad rows (#433). The names stay visible, in slider order; no number replaces them.
	assert(
		choice.options.formatter == nil and choice.options.formatterSet == nil,
		"the row build runs no label formatter of ours (#433)"
	)
	assert(type(choice.tooltip) == "string", "the choice's tooltip is text, not a function (#424)")
	assert(
		choice.tooltip:find("The choices, in order: Strip, Border, Dots.", 1, true),
		"the option names are in the tooltip, in slider order (#433)"
	)
	assert(
		delegated[env.Settings.CreateSliderOptions] and delegated[env.Settings.CreateSliderInitializer],
		"the choice's Blizzard row data is built through secure delegates (#433)"
	)
	ns.db.gearMark = "dots"
	assert(setting.getValue() == 3, "the saved string maps to its index")
	ns.db.gearMark = "not an option"
	assert(setting.getValue() == 2, "an unknown saved value maps to the default's index")
	setting.setValue(2.4)
	assert(ns.db.gearMark == "border", "the setter writes the option's string")
	ns.db.gearMark = nil
	registered = before
end

print("settings: ok")
