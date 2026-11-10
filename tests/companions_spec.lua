-- Tweaks' Forever family hints (Integrations/Companions.lua) on ForeverCore's family module.
local loaded, exists = {}, {}
local env = setmetatable({
	C_AddOns = {
		IsAddOnLoaded = function(addon)
			return loaded[addon] == true
		end,
		DoesAddOnExist = function(addon)
			return exists[addon] == true
		end,
	},
	-- The client pieces ForeverCore's own files install against.
	CreateFrame = function()
		return { RegisterEvent = function() end, SetScript = function() end }
	end,
	geterrorhandler = function()
		return function() end
	end,
	seterrorhandler = function() end,
	strtrim = function(text)
		return (text:gsub("^%s+", ""):gsub("%s+$", ""))
	end,
	GetTime = function()
		return 0
	end,
	date = function()
		return "2026-11-10 12:00:00"
	end,
}, { __index = _G })
local initializers = {}
local ns = {
	L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}),
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
}
-- ForeverCore first, as the client loads a required dependency, then the addon's own file.
local core = dofile("tests/forever_core.lua")
core.install(env, {
	"Core/SafeCall.lua",
	"Core/Log.lua",
	"UI/Report.lua",
	"UI/MapCanvas.lua",
	"UI/ForeverFamily.lua",
	"Expose.lua",
})
setfenv(assert(loadfile("Integrations/Companions.lua")), env)("TweaksForever", ns)
assert(env.ForeverCore.Family and type(env.ForeverCore.Family.Hint) == "function", "the shared family module")

local MISSING = "With Shortest Path Forever, click to plan the way there."
local MISSING_SHIFT = "With Shortest Path Forever, Shift-click plans the way there."
local ENABLE = "Enable Shortest Path Forever for walked routes and boat times."

assert(ns.EntranceHint() == nil, "nothing before the saved variables load")
ns.db = {}
initializers[1]()
-- Not installed: what it would add, with the setting on by default.
assert(ns.EntranceHint() == MISSING)
assert(ns.EntranceHint(true) == MISSING_SHIFT, "a click that opens a map leaves planning to Shift")
-- Installed but switched off: why the click only sets a waypoint.
exists.ShortestPathForever = true
assert(ns.EntranceHint() == ENABLE)
-- Loaded: nothing to say.
loaded.ShortestPathForever = true
assert(ns.EntranceHint() == nil)
-- The shared setting covers only addons you don't have: off, it hides the suggestion but not the enable line.
loaded.ShortestPathForever, ns.db.suggestFamily = nil, false
assert(ns.EntranceHint() == ENABLE, "installed but off explains the click, whatever the setting")
exists.ShortestPathForever = nil
assert(ns.EntranceHint() == nil, "missing, setting off")
-- A client that won't say whether it exists reads as "off" in the module; that is no reason to tell anyone to
-- enable it.
ns.db.suggestFamily = nil
env.C_AddOns.DoesAddOnExist = function()
	error("secret")
end
assert(ns.EntranceHint() == nil, "an unreadable answer shows nothing")
env.C_AddOns.DoesAddOnExist = function(addon)
	return exists[addon] == true
end
-- Dismissed from the link window: the missing line stays away.
ns.db.suggestFamily, ns.db.familyDismissed = nil, { ["TweaksForever.entrance"] = true }
assert(ns.EntranceHint() == nil, "dismissed")
ns.db.familyDismissed = nil
assert(ns.EntranceHint() == MISSING)

-- The old setting turned off carries over once; turned on, or never set, the shared one keeps its default.
ns.db = { companionHints = false }
initializers[1]()
assert(ns.db.suggestFamily == false and ns.db.companionHints == nil, "an old off turns the shared setting off")
ns.db.suggestFamily = true
initializers[1]()
assert(ns.db.suggestFamily == true, "the migration runs once: turning it back on sticks")
ns.db = { companionHints = true }
initializers[1]()
assert(ns.db.suggestFamily == nil and ns.db.companionHints == nil, "an old on leaves the default")
ns.db = { companionHints = false, suggestFamily = true }
initializers[1]()
assert(ns.db.suggestFamily == true, "a shared setting already chosen wins")

print("companions: ok")
