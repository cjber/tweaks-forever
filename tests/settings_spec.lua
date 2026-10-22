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

local env = setmetatable({
	Settings = {
		VarType = { Boolean = "boolean", String = "string", Number = "number" },
		RegisterVerticalLayoutCategory = function(name)
			return Category(name)
		end,
		RegisterVerticalLayoutSubcategory = function(_, name)
			return Category(name)
		end,
		-- The Forever addons page: the shared module's own frame, on a canvas subpage.
		RegisterCanvasLayoutSubcategory = function(parent, frame, name)
			canvas = { parent = parent, frame = frame, name = name }
			return Category(name)
		end,
		RegisterAddOnSetting = function(category, variable, key, _, varType, name)
			return { category = category, variable = variable, key = key, varType = varType, name = name }
		end,
		CreateCheckboxInitializer = function(setting, _, tooltip)
			assert(setting.varType == "boolean")
			local initializer = Initializer("checkbox", setting)
			initializer.tooltip = tooltip
			return initializer
		end,
		CreateDropdownInitializer = function(setting, options)
			assert(setting.varType == "string" and options)
			return Initializer("dropdown", setting)
		end,
		CreateSliderOptions = function(minValue, maxValue, step)
			return { SetLabelFormatter = function() end, min = minValue, max = maxValue, step = step }
		end,
		CreateSliderInitializer = function(setting, options)
			assert(setting.varType == "number" and options)
			local initializer = Initializer("slider", setting)
			initializer.options = options
			return initializer
		end,
		RegisterInitializer = function(category, initializer)
			registered[#registered + 1] = { category = category, initializer = initializer }
		end,
		RegisterAddOnCategory = function() end,
		OpenToCategory = function(id)
			opened = id
		end,
	},
	CreateSettingsButtonInitializer = function(name, _, _, _, addSearchTags)
		assert(addSearchTags == false, "index buttons stay out of search")
		return { kind = "button", name = name }
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
		{ key = "repair", category = "Merchants", name = "Repair", tooltip = "Repairs." },
		{ key = "guildRepair", category = "Merchants", name = "Guild repair", parent = "repair" },
		{ key = "gearMark", category = "Bags", name = "Mark", options = { { "strip", "Strip" } } },
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
}
assert(loadfile("Locales/enUS.lua"))("TweaksForever", ns)
-- A packaged German client: features declare English, and the settings show the translation where there is one.
ns.L["Bags"], ns.L["Repair"], ns.L["Repairs."] = "Taschen", "Reparieren", "Repariert."
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

-- A failing shared panel (another addon's newer copy) leaves the rest of the settings and /tweaks working.
do
	local before, family = #registered, ns.Family
	local addOnCategories = 0
	env.Settings.RegisterAddOnCategory = function()
		addOnCategories = addOnCategories + 1
	end
	ns.Family = {
		CreatePanel = function()
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
assert(Modifiable(guildRepair), "a child row is modifiable while its parent is on")
ns.db.repair = false
assert(not Modifiable(guildRepair) and Modifiable(repair), "a child row greys out with its parent off")
ns.db.repair = nil
missing.repair = "QuestieDB"
assert(not Modifiable(repair), "a row missing an addon it needs is greyed out")
assert(repair.tooltip():find("Needs QuestieDB, which isn't loaded", 1, true), "and says so")
missing.repair = nil
assert(registered[4].initializer.setting.variable == "TweaksForever_gearMark")
local size = registered[6].initializer
assert(
	size.setting.variable == "TweaksForever_iconSize" and size.setting.varType == "number",
	"a slider is a number setting"
)
assert(size.options.min == 50 and size.options.max == 200 and size.options.step == 5, "the slider takes its bounds")

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

print("settings: ok")
