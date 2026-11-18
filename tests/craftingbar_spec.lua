-- #617: the option fades the Professions crafting page's cast bar anchor, and only that, once the page loads.
local db, events, changed, initialize = {}, {}, nil, nil
local ns = {
	db = db,
	Feature = function(feature)
		assert(feature.key == "hideCraftingBar" and feature.default == false, "an opt-in Interface option")
	end,
	Init = function(fn)
		initialize = fn
	end,
	On = function(event, fn)
		events[event] = fn
	end,
	OnSettingChanged = function(_, fn)
		changed = fn
	end,
	Active = function(key)
		return db[key] == true
	end,
}
local function Anchor()
	local anchor = { alpha = 1 }
	function anchor:SetAlpha(alpha)
		self.alpha = alpha
	end
	return anchor
end
local env = setmetatable({}, { __index = _G })
setfenv(assert(loadfile("UI/CraftingBar.lua")), env)("TweaksForever", ns)

db.hideCraftingBar = true
initialize()
assert(events.ADDON_LOADED, "waits for the Professions window to load")

local anchor = Anchor()
env.ProfessionsFrame = { CraftingPage = { OverlayCastBarAnchor = anchor } }
events.ADDON_LOADED("Blizzard_Bags")
assert(anchor.alpha == 1, "another addon loading changes nothing")
events.ADDON_LOADED("Blizzard_Professions")
assert(anchor.alpha == 0, "the crafting bar's anchor fades once the window loads")

db.hideCraftingBar = false
changed()
assert(anchor.alpha == 1, "switching off brings the bar back at once")
db.hideCraftingBar = true
changed()
assert(anchor.alpha == 0, "and switching on fades it at once")

print("ok craftingbar_spec")
