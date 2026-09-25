-- Settings rows must reach their layouts only through Settings.RegisterInitializer, which inserts them from
-- Blizzard's secure attribute delegate. A row inserted from addon code (layout:AddInitializer, or
-- Settings.CreateCheckbox/CreateDropdown, which insert from the caller) taints the settings search, and a
-- restricted button in its results (Social's Discord Sign In) is then blocked and blamed on this addon. The
-- search also reads each row's parent link, so SetParentInitializer from addon code taints it the same way.
local registered = {}
-- [key] = the addon a feature needs and can't find.
local missing = {}

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

local categories = 0
local function Category(name, parent)
	categories = categories + 1
	local id = categories
	return {
		name = name,
		parent = parent,
		GetID = function()
			return id
		end,
	}, Layout()
end

local env = setmetatable({
	Settings = {
		VarType = { Boolean = "boolean", String = "string" },
		RegisterVerticalLayoutCategory = function(name)
			return Category(name)
		end,
		RegisterVerticalLayoutSubcategory = function(parent, name)
			return Category(name, parent)
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
		RegisterInitializer = function(category, initializer)
			registered[#registered + 1] = { category = category, initializer = initializer }
		end,
		RegisterAddOnCategory = function() end,
		OpenToCategory = function() end,
	},
	CreateSettingsButtonInitializer = function(name, _, _, _, addSearchTags)
		assert(addSearchTags == false, "index buttons stay out of search")
		return { kind = "button", name = name }
	end,
	SettingsPanel = { HookScript = function() end },
	RED_FONT_COLOR = {
		WrapTextInColorCode = function(_, text)
			return text
		end,
	},
	SlashCmdList = {},
}, { __index = _G })

local ns
ns = {
	db = {},
	features = {
		{ key = "repair", category = "Merchants", name = "Repair", tooltip = "Repairs." },
		{ key = "guildRepair", category = "Merchants", name = "Guild repair", parent = "repair" },
		{ key = "gearMark", category = "Bags", name = "Mark", options = { { "strip", "Strip" } } },
	},
	Init = function(fn)
		fn()
	end,
	ConflictOf = function() end,
	MissingOf = function(key)
		return missing[key]
	end,
	Active = function(key)
		return ns.db[key] ~= false
	end,
}
assert(loadfile("Locales/enUS.lua"))("TweaksForever", ns)
-- A packaged German client: features declare English, and the settings show the translation where there is one.
ns.L["Bags"], ns.L["Repair"], ns.L["Repairs."] = "Taschen", "Reparieren", "Repariert."
setfenv(assert(loadfile("Settings.lua")), env)("TweaksForever", ns)

-- Rows per page, in order: each subpage's settings, then the index's button to it.
local kinds = {}
for index, entry in ipairs(registered) do
	kinds[index] = entry.initializer.kind .. "@" .. entry.category.name
end
assert(
	table.concat(kinds, " ")
		== "checkbox@Merchants checkbox@Merchants button@Tweaks Forever dropdown@Taschen button@Tweaks Forever",
	table.concat(kinds, " ")
)
local repair, guildRepair = registered[1].initializer, registered[2].initializer
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
print("settings: ok")
