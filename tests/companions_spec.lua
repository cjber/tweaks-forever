-- Tweaks' Forever family hints (Integrations/Companions.lua) on the shared module (UI/ForeverFamily.lua).
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
setfenv(assert(loadfile("UI/ForeverFamily.lua")), env)("TweaksForever", ns)
setfenv(assert(loadfile("Integrations/Companions.lua")), env)("TweaksForever", ns)
assert(ns.Family and env.ForeverFamily == ns.Family, "the shared module is ns.Family")

local MISSING = "With Shortest Path Forever, click to plan the way there."
local ENABLE = "Enable Shortest Path Forever for walked routes and boat times."

assert(ns.EntranceHint() == nil, "nothing before the saved variables load")
ns.db = {}
initializers[1]()
-- Not installed: what it would add, with the setting on by default.
assert(ns.EntranceHint() == MISSING)
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
