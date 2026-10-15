-- Defaults and the shared namespace must be ready before any feature initializer runs.
local function Load(saved)
	local frames, errors, callbacks = {}, {}, {}
	local env = setmetatable({
		TweaksForeverDB = saved,
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
		geterrorhandler = function()
			return function(message)
				errors[#errors + 1] = message
			end
		end,
	}, { __index = _G })
	local ns = {}
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
	local changed = function() end
	ns.OnSettingChanged("gearMark", changed)
	assert(callbacks.TweaksForever_gearMark == changed and ns.SettingVariable("gearMark") == "TweaksForever_gearMark")
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
	setfenv(assert(loadfile("Core/Core.lua")), env)("TweaksForever", ns)
	local function Polestar(path)
		return { addon = "Polestar", title = "Polestar", polestar = path }
	end
	ns.Feature({ key = "repair", default = true, conflicts = { Polestar("qol.autoRepair") } })
	ns.Feature({ key = "reveal", default = false, conflicts = { Polestar("maps.reveal") } })
	frames[2].callback()
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
	env.Polestar = nil
	ns.RefreshConflicts()
	assert(not ns.ConflictOf("reveal"), "a Polestar without its namespace is no conflict")
	env.Polestar = { Get = error }
	ns.RefreshConflicts()
	assert(not ns.ConflictOf("reveal"), "a failing Polestar.Get is no conflict")
end

print("core: ok")
