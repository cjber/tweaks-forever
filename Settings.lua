---@type string, TFNamespace
local _, ns = ...
local L = ns.L

-- Options → AddOns → Tweaks Forever: a short index page, then a stock subpage per category so no page grows
-- tall. A feature another addon already handles, or one missing an addon it needs, is greyed out, its tooltip
-- naming that addon.
-- Every row goes in through Settings.RegisterInitializer, which inserts it from Blizzard's secure delegate.
-- Settings.CreateCheckbox/CreateDropdown and layout:AddInitializer insert from our code instead, and the
-- settings search reads every layout, so that tainted it: a restricted button in the results (Social's
-- Discord Sign In) was then blocked and blamed on us.
-- Feature files declare their category, name, tooltip and option labels in English; they are translated here, where
-- they are shown (tools/phrases.py lists them for CurseForge).

---@param feature TFFeature
local function Tooltip(feature)
	return function()
		local conflict, missing = ns.ConflictOf(feature.key), ns.MissingOf(feature.key)
		local tooltip = feature.tooltip and L[feature.tooltip]
		if not conflict and not missing then
			return tooltip
		end
		local note = RED_FONT_COLOR:WrapTextInColorCode(
			conflict and L["%s already does this, so it is off here."]:format(conflict)
				or L["Needs %s, which isn't loaded, so it is off here."]:format(missing)
		)
		return tooltip and tooltip .. "\n\n" .. note or note
	end
end

---@param category SettingsCategoryMixin
---@param feature TFFeature
local function AddSetting(category, feature)
	local options = feature.options
	local setting = Settings.RegisterAddOnSetting(
		category,
		"TweaksForever_" .. feature.key,
		feature.key,
		ns.db,
		options and Settings.VarType.String or Settings.VarType.Boolean,
		L[feature.name],
		feature.default
	)
	local initializer
	if options then
		initializer = Settings.CreateDropdownInitializer(setting, function()
			local container = Settings.CreateControlTextContainer()
			for _, option in ipairs(options) do
				container:Add(option[1], L[option[2]])
			end
			return container:GetData()
		end, Tooltip(feature))
	else
		initializer = Settings.CreateCheckboxInitializer(setting, nil, Tooltip(feature))
	end
	initializer:AddModifyPredicate(function()
		return not ns.ConflictOf(feature.key) and not ns.MissingOf(feature.key)
	end)
	if feature.parent then
		-- Not SetParentInitializer: the settings search reads that link from every row, so ours tainted it and
		-- Social's Discord Sign In in the results was blocked. An indent, a predicate and a re-check on the
		-- parent's value give the same greyed, nested row.
		initializer:Indent()
		initializer:AddModifyPredicate(function()
			return ns.Active(feature.parent)
		end)
		initializer:AddEvaluateStateCVar("TweaksForever_" .. feature.parent)
	end
	Settings.RegisterInitializer(category, initializer)
end

ns.Init(function()
	local category = Settings.RegisterVerticalLayoutCategory("Tweaks Forever")
	-- Subpages in the order their first feature loads; several files add to one.
	local sections, bySection = {}, {}
	for _, feature in ipairs(ns.features) do
		if not bySection[feature.category] then
			bySection[feature.category] = {}
			sections[#sections + 1] = feature.category
		end
		table.insert(bySection[feature.category], feature)
	end
	for _, section in ipairs(sections) do
		local subcategory = Settings.RegisterVerticalLayoutSubcategory(category, L[section])
		for _, feature in ipairs(bySection[section]) do
			AddSetting(subcategory, feature)
		end
		-- The index is buttons that open each subpage; search finds the settings themselves instead.
		Settings.RegisterInitializer(
			category,
			CreateSettingsButtonInitializer(L[section], L["Open"], function()
				Settings.OpenToCategory(subcategory:GetID())
			end, nil, false)
		)
	end
	Settings.RegisterAddOnCategory(category)
	-- Another addon's settings may have changed since login.
	SettingsPanel:HookScript("OnShow", ns.RefreshConflicts)

	local function Open()
		Settings.OpenToCategory(category:GetID())
	end
	SLASH_TWEAKSFOREVER1 = "/tweaks"
	SLASH_TWEAKSFOREVER2 = "/tweaksforever"
	SlashCmdList.TWEAKSFOREVER = Open
	-- The minimap's addon compartment calls this by name (## AddonCompartmentFunc).
	TweaksForever_OnAddonCompartmentClick = Open
end)
