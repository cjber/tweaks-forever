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

print("core: ok")
