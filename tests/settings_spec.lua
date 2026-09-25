-- Settings rows must reach their layouts only through Settings.RegisterInitializer, which inserts them from
-- Blizzard's secure attribute delegate. A row inserted from addon code (layout:AddInitializer, or
-- Settings.CreateCheckbox/CreateDropdown, which insert from the caller) taints the settings search, and a
-- restricted button in its results (Social's Discord Sign In) is then blocked and blamed on this addon.
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
		AddModifyPredicate = function(self, predicate)
			self.modify = predicate
		end,
		SetParentInitializer = function(self, parent, predicate)
			self.parent, self.parentPredicate = assert(parent), predicate
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
		RegisterAddOnSetting = function(category, variable, key, _, varType)
			return { category = category, variable = variable, key = key, varType = varType }
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

local ns = {
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
	Active = function()
		return true
	end,
}
setfenv(assert(loadfile("Settings.lua")), env)("TweaksForever", ns)

-- Rows per page, in order: each subpage's settings, then the index's button to it.
local kinds = {}
for index, entry in ipairs(registered) do
	kinds[index] = entry.initializer.kind .. "@" .. entry.category.name
end
assert(
	table.concat(kinds, " ")
		== "checkbox@Merchants checkbox@Merchants button@Tweaks Forever dropdown@Bags button@Tweaks Forever",
	table.concat(kinds, " ")
)
local repair, guildRepair = registered[1].initializer, registered[2].initializer
assert(guildRepair.parent == repair and guildRepair.parentPredicate(), "a child row is tied to its parent")
assert(repair.modify and repair.modify(), "conflict-free rows stay modifiable")
missing.repair = "QuestieDB"
assert(not repair.modify(), "a row missing an addon it needs is greyed out")
assert(repair.tooltip():find("Needs QuestieDB, which isn't loaded", 1, true), "and says so")
missing.repair = nil
assert(registered[4].initializer.setting.variable == "TweaksForever_gearMark")
print("settings: ok")
