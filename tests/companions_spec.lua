local loaded, exists = {}, {}
local env = setmetatable({
	C_AddOns = {
		IsAddOnLoaded = function(addon)
			return loaded[addon]
		end,
		DoesAddOnExist = function(addon)
			return exists[addon]
		end,
	},
}, { __index = _G })
local ns = { db = { companionHints = true } }
-- Core's Active, reduced to the setting: no conflict or missing addon applies to the hints.
function ns.Feature() end
function ns.Active(key)
	return ns.db[key]
end
setfenv(assert(loadfile("Companions.lua")), env)("TweaksForever", ns)

local function Hint()
	return ns.Suggestion("ShortestPathForever", "Install it.", "Enable it.")
end

-- Not installed: install it.
assert(Hint() == "Install it.")
-- Installed but switched off, so not loaded: enable it.
exists.ShortestPathForever = true
assert(Hint() == "Enable it.")
-- Loaded: nothing to suggest.
loaded.ShortestPathForever = true
assert(Hint() == nil)
-- With the setting off, never a hint.
loaded.ShortestPathForever, exists.ShortestPathForever, ns.db.companionHints = nil, nil, false
assert(Hint() == nil)

print("companions: ok")
