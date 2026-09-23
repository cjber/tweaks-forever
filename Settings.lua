local _, ns = ...

-- Options → AddOns → Tweaks Forever: a short index page, then a stock subpage per category so no page grows
-- tall. A feature another addon already handles is greyed out, its tooltip naming that addon.

local function Tooltip(feature)
	return function()
		local conflict = ns.ConflictOf(feature.key)
		if not conflict then
			return feature.tooltip
		end
		local note = RED_FONT_COLOR:WrapTextInColorCode(conflict .. " already does this, so it is off here.")
		return feature.tooltip and feature.tooltip .. "\n\n" .. note or note
	end
end

local function AddSetting(category, feature, initializers)
	local options = feature.options
	local setting = Settings.RegisterAddOnSetting(
		category,
		"TweaksForever_" .. feature.key,
		feature.key,
		ns.db,
		options and Settings.VarType.String or Settings.VarType.Boolean,
		feature.name,
		feature.default
	)
	local initializer
	if options then
		initializer = Settings.CreateDropdown(category, setting, function()
			local container = Settings.CreateControlTextContainer()
			for _, option in ipairs(options) do
				container:Add(option[1], option[2])
			end
			return container:GetData()
		end, Tooltip(feature))
	else
		initializer = Settings.CreateCheckbox(category, setting, Tooltip(feature))
	end
	initializer:AddModifyPredicate(function()
		return not ns.ConflictOf(feature.key)
	end)
	if feature.parent then
		initializer:SetParentInitializer(initializers[feature.parent], function()
			return ns.Active(feature.parent)
		end)
	end
	initializers[feature.key] = initializer
end

ns.Init(function()
	local category, layout = Settings.RegisterVerticalLayoutCategory("Tweaks Forever")
	-- Subpages in the order their first feature loads; several files add to one.
	local sections, bySection = {}, {}
	for _, feature in ipairs(ns.features) do
		if not bySection[feature.category] then
			bySection[feature.category] = {}
			sections[#sections + 1] = feature.category
		end
		table.insert(bySection[feature.category], feature)
	end
	local initializers = {}
	for _, section in ipairs(sections) do
		local subcategory = Settings.RegisterVerticalLayoutSubcategory(category, section)
		for _, feature in ipairs(bySection[section]) do
			AddSetting(subcategory, feature, initializers)
		end
		-- The index is buttons that open each subpage; search finds the settings themselves instead.
		layout:AddInitializer(CreateSettingsButtonInitializer(section, "Open", function()
			Settings.OpenToCategory(subcategory:GetID())
		end, nil, false))
	end
	Settings.RegisterAddOnCategory(category)
	-- Another addon's settings may have changed since login.
	SettingsPanel:HookScript("OnShow", ns.RefreshConflicts)

	local function Open()
		Settings.OpenToCategory(category:GetID())
	end
	SLASH_TWEAKSFOREVER1 = "/tweaks"
	SlashCmdList.TWEAKSFOREVER = Open
	-- The minimap's addon compartment calls this by name (## AddonCompartmentFunc).
	TweaksForever_OnAddonCompartmentClick = Open
end)
