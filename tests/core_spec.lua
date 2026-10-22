-- Defaults and the shared namespace must be ready before any feature initializer runs.
local function Load(saved)
	local frames, errors, callbacks = {}, {}, {}
	local env = setmetatable({
		TweaksForeverDB = saved,
		C_AddOns = {
			IsAddOnLoaded = function()
				return false
			end,
		},
		Settings = {
			SetOnValueChangedCallback = function(variable, fn)
				callbacks[variable] = fn
			end,
		},
		CreateFrame = function()
			local frame = {}
			function frame.RegisterEvent() end
			function frame:SetScript(_, fn)
				self.callback = fn
			end
			frames[#frames + 1] = frame
			return frame
		end,
		strtrim = function(text)
			return (text:gsub("^%s+", ""):gsub("%s+$", ""))
		end,
		GetTime = function()
			return 0
		end,
		geterrorhandler = function()
			return function(message)
				errors[#errors + 1] = message
			end
		end,
	}, { __index = _G })
	local ns = {}
	setfenv(assert(loadfile("Core/SafeCall.lua")), env)("TweaksForever", ns)
	setfenv(assert(loadfile("Core/Core.lua")), env)("TweaksForever", ns)
	ns.Feature({ key = "enabled", default = true })
	ns.Feature({ key = "disabled", default = false })
	ns.Feature({ key = "gearMark", default = "strip" })
	local present = function()
		return true
	end
	ns.Feature({ key = "needsPresent", default = true, needs = { title = "Present", check = present } })
	ns.Feature({ key = "needsMissing", default = true, needs = { title = "Missing", check = function() end } })
	ns.Feature({ key = "needsBroken", default = true, needs = { title = "Broken", check = error } })
	-- A setting callback names the variable UI/Settings.lua registers, and only for a declared feature.
	local seen
	local changed = function(_, _, value)
		seen = value
	end
	ns.OnSettingChanged("gearMark", changed)
	assert(ns.SettingVariable("gearMark") == "TweaksForever_gearMark")
	callbacks.TweaksForever_gearMark(nil, nil, "dots")
	assert(seen == "dots", "the callback runs with the setting's arguments")
	assert(not pcall(ns.OnSettingChanged, "gearMarks", changed), "a misspelt key fails loudly")
	-- An event can reach a feature while the world loads, before PLAYER_LOGIN has read the saved settings
	-- (VIGNETTES_UPDATED through Rare alerts, #202): the feature is off until then, never an error.
	local early
	ns.On("VIGNETTES_UPDATED", function()
		early = ns.Active("enabled")
	end)
	frames[1].callback(frames[1], "VIGNETTES_UPDATED")
	assert(early == false and #errors == 0, "a feature is off before login: " .. tostring(errors[1]))
	local ran = false
	ns.Init(function()
		ran = true
		assert(ns.db == env.TweaksForeverDB)
		assert(ns.db.junk and ns.db.gearMark)
		assert(ns.Active("enabled") == (ns.db.enabled == true))
		assert(ns.Active("disabled") == false)
		-- A feature missing an addon it needs is off whatever its setting, and names that addon.
		assert(ns.Active("needsPresent") == (ns.db.needsPresent == true) and not ns.MissingOf("needsPresent"))
		assert(not ns.Active("needsMissing") and ns.MissingOf("needsMissing") == "Missing")
		assert(not ns.Active("needsBroken") and ns.MissingOf("needsBroken") == "Broken")
		assert(not ns.MissingOf("enabled"))
	end)
	assert(not ran)
	frames[2].callback()
	assert(ran and #errors == 0)
	frames[1].callback(frames[1], "VIGNETTES_UPDATED")
	assert(early == (ns.db.enabled == true), "after login the same event reads the saved setting")
	local ready = false
	ns.Init(function()
		ready = true
	end)
	assert(ready, "initializers registered after login run immediately")
	return ns.db
end

local fresh = Load(nil)
assert(fresh.enabled and fresh.gearMark == "strip" and not next(fresh.junk))
local saved = { enabled = false, junk = { [42] = true }, gearMark = "dots" }
assert(Load(saved) == saved, "existing settings keep their identity and player choices")
assert(not saved.enabled and saved.junk[42] and saved.gearMark == "dots")
assert(Load({}).junk, "older settings receive the junk table before initializers")

do -- A `polestar` conflict reads Polestar's own setting: on, or any choice but "off", while Polestar is loaded.
	local loaded, settings = {}, {}
	local frames = {}
	local env = setmetatable({
		strtrim = function(text)
			return (text:gsub("^%s+", ""):gsub("%s+$", ""))
		end,
		GetTime = function()
			return 0
		end,
		geterrorhandler = function()
			return error
		end,
		C_AddOns = {
			IsAddOnLoaded = function(addon)
				return loaded[addon] == true
			end,
		},
		Polestar = {
			Get = function(path)
				return settings[path]
			end,
		},
		CreateFrame = function()
			local frame = { RegisterEvent = function() end }
			function frame:SetScript(_, fn)
				self.callback = fn
			end
			frames[#frames + 1] = frame
			return frame
		end,
	}, { __index = _G })
	local ns = {}
	setfenv(assert(loadfile("Core/SafeCall.lua")), env)("TweaksForever", ns)
	setfenv(assert(loadfile("Core/Core.lua")), env)("TweaksForever", ns)
	local listeners = {}
	env.Polestar.On = function(message, fn)
		listeners[#listeners + 1] = message
		listeners[message] = fn
	end
	ns.Feature({ key = "repair", default = true, conflicts = { { polestar = "qol.autoRepair" } } })
	ns.Feature({ key = "reveal", default = false, conflicts = { { polestar = "maps.reveal" } } })
	ns.Feature({
		key = "tips",
		default = true,
		conflicts = { { addon = "Polestar_QuestDB", polestar = "qol.questTooltips" } },
	})
	frames[2].callback()
	assert(#listeners == 0, "no Polestar loaded at login, nothing to follow")
	settings["qol.autoRepair"], settings["maps.reveal"] = true, "tint"
	ns.RefreshConflicts()
	assert(not ns.ConflictOf("repair"), "Polestar's settings count only while Polestar is loaded")
	loaded.Polestar = true
	ns.RefreshConflicts()
	assert(ns.ConflictOf("repair") == "Polestar" and ns.ConflictOf("reveal") == "Polestar")
	assert(not ns.Active("repair"), "a conflicted feature stands down")
	settings["qol.autoRepair"], settings["maps.reveal"] = false, "off"
	ns.RefreshConflicts()
	assert(not ns.ConflictOf("repair") and not ns.ConflictOf("reveal"), 'off and "off" leave the job here')
	settings["maps.reveal"] = "on"
	ns.RefreshConflicts()
	assert(ns.ConflictOf("reveal") == "Polestar")
	-- Its quest tooltips count once its load-on-demand quest database is in; ADDON_LOADED re-reads them.
	settings["qol.questTooltips"] = true
	ns.RefreshConflicts()
	assert(not ns.ConflictOf("tips"), "Polestar's quest database has not loaded")
	loaded.Polestar_QuestDB = true
	frames[1].callback(frames[1], "ADDON_LOADED", "Polestar_QuestDB")
	assert(ns.ConflictOf("tips") == "Polestar", "a load-on-demand addon loading refreshes conflicts")
	env.Polestar = nil
	ns.RefreshConflicts()
	assert(not ns.ConflictOf("reveal"), "a Polestar without its namespace is no conflict")
	assert(not ns.PolestarOn("maps.reveal"))
	env.Polestar = { Get = error }
	ns.RefreshConflicts()
	assert(not ns.ConflictOf("reveal"), "a failing Polestar.Get is no conflict")
end

do -- An `openmap` conflict reads OpenMap's world map option while OpenMap is loaded; its defaults are on.
	local loaded = {}
	local env = setmetatable({
		strtrim = function(text)
			return (text:gsub("^%s+", ""):gsub("%s+$", ""))
		end,
		GetTime = function()
			return 0
		end,
		geterrorhandler = function()
			return error
		end,
		C_AddOns = {
			IsAddOnLoaded = function(addon)
				return loaded[addon] == true
			end,
			GetAddOnMetadata = function()
				return "|cffe6b85cOpen|rMap"
			end,
		},
		CreateFrame = function()
			local frame = { RegisterEvent = function() end }
			function frame:SetScript(_, fn)
				self.callback = fn
			end
			return frame
		end,
	}, { __index = _G })
	local ns = {}
	setfenv(assert(loadfile("Core/SafeCall.lua")), env)("TweaksForever", ns)
	setfenv(assert(loadfile("Core/Core.lua")), env)("TweaksForever", ns)
	ns.db = { coords = true, reveal = true }
	ns.Feature({ key = "coords", default = true, conflicts = { { openmap = "coords" } } })
	ns.Feature({ key = "reveal", default = false, conflicts = { { openmap = "unexplored" } } })
	ns.RefreshConflicts()
	assert(not ns.ConflictOf("coords"), "OpenMap's settings count only while OpenMap is loaded")
	loaded.OpenMap = true
	ns.RefreshConflicts()
	assert(ns.ConflictOf("coords") == "OpenMap", "no saved settings yet: its defaults, which are on")
	assert(ns.ConflictOf("reveal") == "OpenMap", "named plainly, not by its colour-coded title")
	assert(not ns.Active("coords"), "a conflicted feature stands down")
	env.OpenMapDB = { worldmap = { enabled = true, coords = true, unexplored = "dim" } }
	ns.RefreshConflicts()
	assert(ns.ConflictOf("coords") and ns.ConflictOf("reveal"), '"dim" still reveals the map')
	env.OpenMapDB.worldmap.coords, env.OpenMapDB.worldmap.unexplored = false, "hide"
	ns.RefreshConflicts()
	assert(not ns.ConflictOf("coords"), "its coordinates off leave ours")
	assert(not ns.ConflictOf("reveal"), '"hide" leaves unexplored areas blank, so ours may reveal them')
	env.OpenMapDB.worldmap = { enabled = false, coords = true, unexplored = "show" }
	ns.RefreshConflicts()
	assert(not ns.ConflictOf("coords") and not ns.ConflictOf("reveal"), "its world map turned off runs none of them")
	assert(ns.Active("coords"))
	-- Once it has started, its module's own flag says whether the world map runs: turning it off in OpenMap's
	-- options takes a reload there, and a world map that failed to start draws nothing.
	env.OpenMap = { modules = { worldmap = { enabled = true } } }
	ns.RefreshConflicts()
	assert(ns.ConflictOf("coords") == "OpenMap", "still running until OpenMap reloads")
	env.OpenMap.modules.worldmap.enabled = false
	env.OpenMapDB.worldmap.enabled = true
	ns.RefreshConflicts()
	assert(not ns.ConflictOf("coords"), "a world map that failed to start leaves ours")
	env.OpenMap = nil
	env.OpenMapDB = { worldmap = "broken" }
	assert(ns.OpenMapOn("coords"), "an unreadable table is its defaults")
	loaded.OpenMap = false
	assert(not ns.OpenMapOn("coords"), "nothing is on while OpenMap is not loaded")
end

do -- Loaded at login, Polestar's own setting changes refresh the conflicts at once.
	local settings, frames, listeners = { ["qol.fastLoot"] = false }, {}, {}
	local env = setmetatable({
		C_AddOns = {
			IsAddOnLoaded = function(addon)
				return addon == "Polestar"
			end,
		},
		Polestar = {
			Get = function(path)
				return settings[path]
			end,
			On = function(message, fn)
				listeners[message] = fn
			end,
		},
		CreateFrame = function()
			local frame = { RegisterEvent = function() end }
			function frame:SetScript(_, fn)
				self.callback = fn
			end
			frames[#frames + 1] = frame
			return frame
		end,
	}, { __index = _G })
	local ns = {}
	setfenv(assert(loadfile("Core/SafeCall.lua")), env)("TweaksForever", ns)
	setfenv(assert(loadfile("Core/Core.lua")), env)("TweaksForever", ns)
	ns.Feature({ key = "fastLoot", default = true, conflicts = { { polestar = "qol.fastLoot" } } })
	assert(ns.features[1].conflicts[1].addon == "Polestar" and ns.features[1].conflicts[1].title == "Polestar")
	frames[2].callback()
	assert(ns.Active("fastLoot"))
	settings["qol.fastLoot"] = true
	listeners.SETTING_CHANGED("qol.fastLoot", true)
	assert(not ns.Active("fastLoot") and ns.ConflictOf("fastLoot") == "Polestar", "turned on in Polestar, off here")
	settings["qol.fastLoot"] = false
	listeners.SETTING_CHANGED("qol.fastLoot", false)
	assert(ns.Active("fastLoot"), "turned off in Polestar, back on here")
end

-- A button widens to its label (a translation can run longer than the English) and never shrinks below its width.
do
	local ns = {}
	local env = setmetatable({
		CreateFrame = function()
			return { RegisterEvent = function() end, SetScript = function() end }
		end,
	}, { __index = _G })
	setfenv(assert(loadfile("Core/Core.lua")), env)("TweaksForever", ns)
	local button = { text = 40 }
	function button:GetTextWidth()
		return self.text
	end
	function button:SetWidth(width)
		self.width = width
	end
	ns.FitButton(button, 80)
	assert(button.width == 80, "a short label keeps the button's own width")
	button.text = 101.5
	ns.FitButton(button, 80)
	assert(button.width == 126, "a long label widens the button with room either side")
end

print("core: ok")
