---@type string, TFNamespace
local addonName, ns = ...

if ns.broken then
	return
end
local L = ns.L

-- Options → AddOns → Tweaks Forever: a short index page, then a stock subpage per category so no page grows
-- tall. A feature another addon already handles, or one missing an addon it needs, is greyed out, its tooltip
-- naming that addon.
-- Every row goes in through Settings.RegisterInitializer, which inserts it from Blizzard's secure delegate.
-- Settings.CreateCheckbox/CreateDropdown and layout:AddInitializer insert from our code instead, and the
-- settings search reads every layout, so that tainted it: a restricted button in the results (Social's
-- Discord Sign In) was then blocked and blamed on us.
-- Feature files declare their category, name, tooltip and option labels in English; they are translated here, where
-- they are shown (tools/phrases.py lists them for translators).

-- Blizzard's row data, built in secure execution. CreateSecureDelegate wraps a client function so a call from our
-- code runs as the client, not as the addon: without it, what we hand Blizzard to read in its secure row build
-- carries our taint, and the gamepad navigation fields the build then writes taint the binding stack when the panel
-- closes (#433). The delegate is absent on some Forever builds (cjber/adventure-guide-forever#592); there the direct
-- call is all there is, as in ForeverCore's OpenSettings.
local delegates = setmetatable({}, { __mode = "k" })
---@param fn function
---@return function
local function Secure(fn)
	if type(CreateSecureDelegate) ~= "function" then
		return fn
	end
	local delegate = delegates[fn]
	if not delegate then
		delegate = CreateSecureDelegate(fn)
		delegates[fn] = delegate
	end
	return delegate
end

-- A row that can never carry a note gets its text, not a function. Under the gamepad interface the cursor shows a
-- row's tooltip and then, in the same call, a dropdown or slider row pushes its footer bindings, so a tooltip function
-- of ours there taints the binding stack the gamepad action bar reads before a protected call (#168). With the
-- gamepad interface on every row gets its text, read here as it registers; otherwise only a feature with a conflict
-- or a needed addon keeps a function, read as it shows; tests/sim/gamepad_settings_scenario.lua.
--
-- A on a dropdown row runs the menu generator, and so our options function and the setting's value, before the menu
-- opens; the menu then takes the gamepad focus and SmartNavigation's binding set comes off the input stack in that
-- same tainted call, so the action bar's next protected call is blocked and blamed on us (#168). With the gamepad
-- interface on, a feature with options is a slider instead, which never opens a menu; the mouse and keyboard keep the
-- dropdown.
--
-- The choice slider has no label formatter of ours. A formatter runs inside Blizzard's secure row build, and a
-- function of ours there taints the row's gamepad fields the same way (#433). The option names go in the row's
-- tooltip instead, in slider order, which the cursor shows; players still see Modern, Retail and the rest, never
-- just a number.
---@param feature TFFeature
---@return string|fun(): string?|nil
local function Tooltip(feature)
	local text = feature.tooltip and L[feature.tooltip]
	local gamepad = InputUtil.IsGamepadUIEnabled()
	if gamepad and feature.options then
		local labels = {}
		for _, option in ipairs(feature.options) do
			labels[#labels + 1] = L[option[2]]
		end
		local choices = L["The choices, in order: %s."]:format(table.concat(labels, ", "))
		text = text and text .. "\n\n" .. choices or choices
	end
	local function Note()
		local conflict, missing = ns.ConflictOf(feature.key), ns.MissingOf(feature.key)
		if not conflict and not missing then
			return text
		end
		local note = RED_FONT_COLOR:WrapTextInColorCode(
			conflict and L["%s already does this, so it is off here."]:format(conflict)
				or L["Needs %s, which isn't loaded, so it is off here."]:format(missing)
		)
		return text and text .. "\n\n" .. note or note
	end
	if gamepad or #(feature.conflicts or {}) == 0 and not feature.needs then
		return Note()
	end
	return Note
end

-- Indent a row under a feature and grey it out while that feature is off. Not SetParentInitializer: the settings
-- search reads that link from every row, so ours tainted it and Social's Discord Sign In in the results was blocked.
-- Indent writes data.indent, which Blizzard's secure row build reads, so it runs as the client (#433).
---@param initializer any
---@param key string
local function Nest(initializer, key)
	Secure(initializer.Indent)(initializer)
	if not InputUtil.IsGamepadUIEnabled() then
		initializer:AddModifyPredicate(function()
			return ns.Active(key)
		end)
		initializer:AddEvaluateStateCVar(ns.SettingVariable(key))
	end
end

---@param category SettingsCategoryMixin
---@param feature TFFeature
local function AddSetting(category, feature)
	local options, slider = feature.options, feature.slider
	local gamepadOptions = options and InputUtil.IsGamepadUIEnabled()
	-- ns.db keeps the option's string; only the row and its setting speak in indexes, so every reader and
	-- OnSettingChanged callback sees what it did before.
	local function IndexOf(value)
		for index, option in ipairs(options or {}) do
			if option[1] == value then
				return index
			end
		end
	end
	local function Option(value)
		assert(options, "a choice feature needs options")
		local index = math.max(1, math.min(#options, math.floor((value or 1) + 0.5)))
		return options[index]
	end
	local defaultIndex = IndexOf(feature.default) or 1
	local setting
	if gamepadOptions then
		setting = Settings.RegisterProxySetting(
			category,
			ns.SettingVariable(feature.key),
			Settings.VarType.Number,
			L[feature.name],
			defaultIndex,
			function()
				return IndexOf(ns.db[feature.key]) or defaultIndex
			end,
			function(value)
				ns.db[feature.key] = Option(value)[1]
			end
		)
	else
		setting = Settings.RegisterAddOnSetting(
			category,
			ns.SettingVariable(feature.key),
			feature.key,
			ns.db,
			options and Settings.VarType.String or slider and Settings.VarType.Number or Settings.VarType.Boolean,
			L[feature.name],
			feature.default
		)
	end
	local initializer
	if gamepadOptions then
		-- The D-pad steps the same list the dropdown's arrows did. The option names are in the row's tooltip
		-- (Tooltip above): a label formatter of ours would run inside Blizzard's row build (#433).
		local sliderOptions = Secure(Settings.CreateSliderOptions)(1, #options, 1)
		initializer = Secure(Settings.CreateSliderInitializer)(setting, sliderOptions, Tooltip(feature))
	elseif options then
		initializer = Secure(Settings.CreateDropdownInitializer)(setting, function()
			local container = Settings.CreateControlTextContainer()
			for _, option in ipairs(options) do
				container:Add(option[1], L[option[2]])
			end
			return container:GetData()
		end, Tooltip(feature))
	elseif slider then
		-- A number the player drags, in the stock slider style, shown as a percentage. Under the gamepad interface a
		-- formatter of ours would run inside Blizzard's row build (#433), so there the client's own label shows the
		-- number; the mouse and keyboard keep the percentage.
		local sliderOptions = Secure(Settings.CreateSliderOptions)(slider.min, slider.max, slider.step or 1)
		if not InputUtil.IsGamepadUIEnabled() then
			Secure(sliderOptions.SetLabelFormatter)(
				sliderOptions,
				MinimalSliderWithSteppersMixin.Label.Right,
				function(value)
					return string.format("%d%%", math.floor(value + 0.5))
				end
			)
		end
		initializer = Secure(Settings.CreateSliderInitializer)(setting, sliderOptions, Tooltip(feature))
	else
		initializer = Secure(Settings.CreateCheckboxInitializer)(setting, nil, Tooltip(feature))
	end
	if not InputUtil.IsGamepadUIEnabled() then
		initializer:AddModifyPredicate(function()
			return not ns.ConflictOf(feature.key) and not ns.MissingOf(feature.key)
		end)
	end
	if feature.parent then
		Nest(initializer, feature.parent)
	end
	Settings.RegisterInitializer(category, initializer)
	-- A button opening a panel the feature needs, indented under it and greyed while it is off.
	if feature.button then
		local button =
			Secure(CreateSettingsButtonInitializer)(L["Spells to track"], L["Choose"], feature.button, nil, false)
		Nest(button, feature.key)
		Settings.RegisterInitializer(category, button)
	end
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
		-- The index is buttons that open each subpage; search finds the settings themselves instead. Pages open
		-- through the shared secure opener: Settings.OpenToCategory is Blizzard's own Lua around a restricted
		-- client call, which the client refuses when addon code makes it (cjber/forever-core#333).
		Settings.RegisterInitializer(
			category,
			Secure(CreateSettingsButtonInitializer)(L[section], L["Open"], function()
				ForeverCore.OpenSettingsPanel(subcategory:GetID())
			end, nil, false)
		)
	end
	-- The Forever addons page is ForeverCore's, with the hint setting on it. With the gamepad interface on it is the
	-- client's own rows so the Options navigation can enter it (#382); otherwise its canvas frame, and nothing of
	-- ours goes into the settings search. A failure there is caught and leaves the rest of the settings and /tweaks
	-- working.
	ns.core.SafeCall("Forever addons page", function()
		local family = ForeverCore.Family.Register(category, ns.db, addonName, ns.core.SafeCall)
		Settings.RegisterInitializer(
			category,
			Secure(CreateSettingsButtonInitializer)(L["Forever addons"], L["Open"], function()
				ForeverCore.OpenSettingsPanel(family:GetID())
			end, nil, false)
		)
	end)
	Settings.RegisterAddOnCategory(category)
	-- Another addon's settings may have changed since login. Not with the gamepad UI on (#168): its navigation
	-- pushes and pops input bindings as this panel and its rows show and hide, and a blocked
	-- SetPreferredGamepadInteractTarget has been reported after backing out of the AddOns settings. Skipping the
	-- conflict check, and everything hooked on it, keeps most of our code out of that path; conflicts are still read
	-- at login and as addons load. The rows' own tooltips and predicates still run, as every addon's do.
	SettingsPanel:HookScript("OnShow", function()
		if not InputUtil.IsGamepadUIEnabled() then
			ns.RefreshConflicts()
		end
	end)

	local function Open()
		ForeverCore.OpenSettingsPanel(category:GetID())
	end
	SLASH_TWEAKSFOREVER1 = "/tweaks"
	SLASH_TWEAKSFOREVER2 = "/tweaksforever"
	-- `/tweaks report` shows the report to copy into a bug report; anything else opens the settings.
	local function Slash(message)
		local command = strtrim(message or ""):lower()
		if ns.core.Report.Command(command) then
			return
		elseif command == "help" then
			ns.Print(L["/tw report - show a report to copy into a bug report"])
			ns.Print(L["/tw issue - report a bug or request a feature with a ready-made GitHub issue link"])
		else
			Open()
		end
	end
	SlashCmdList.TWEAKSFOREVER = function(message)
		ns.core.SafeCall("slash command", Slash, message)
	end
	-- The minimap's addon compartment calls this by name (## AddonCompartmentFunc).
	TweaksForever_OnAddonCompartmentClick = Open
end)
