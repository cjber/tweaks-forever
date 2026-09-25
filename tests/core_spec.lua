-- Defaults and the shared namespace must be ready before any feature initializer runs.
local function Load(saved)
	local frames, errors = {}, {}
	local env = setmetatable({
		TweaksForeverDB = saved,
		C_AddOns = { IsAddOnLoaded = function() end },
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
	setfenv(assert(loadfile("Core.lua")), env)("TweaksForever", ns)
	ns.Feature({ key = "enabled", default = true })
	ns.Feature({ key = "disabled", default = false })
	ns.Feature({ key = "gearMark", default = "strip" })
	local present = function()
		return true
	end
	ns.Feature({ key = "needsPresent", default = true, needs = { title = "Present", check = present } })
	ns.Feature({ key = "needsMissing", default = true, needs = { title = "Missing", check = function() end } })
	ns.Feature({ key = "needsBroken", default = true, needs = { title = "Broken", check = error } })
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
print("core: ok")
