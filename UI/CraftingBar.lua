---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end

local KEY = "hideCraftingBar"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Hide the crafting bar in the Professions window",
	tooltip = "Hides the cast bar the Professions window draws over the recipe while you craft. "
		.. "The game turns the player cast bar off while the window has its own, so crafts there show no bar.",
	default = false,
})

-- The Professions crafting page moves the player cast bar into an empty 1x1 anchor of its own while you craft
-- (OverlayPlayerCastingBarFrame:StartReplacingPlayerBarAt). The bar sets its own alpha at every cast and fades
-- with an animation, so it is the anchor that fades: nothing else draws there, and an alpha is an engine call
-- that leaves Blizzard's state alone (WFA-38).
local function Apply()
	local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
	if page and page.OverlayCastBarAnchor then
		page.OverlayCastBarAnchor:SetAlpha(ns.Active(KEY) and 0 or 1)
	end
end

ns.Init(function()
	ns.OnSettingChanged(KEY, Apply)
	ns.On("ADDON_LOADED", function(name)
		if name == "Blizzard_Professions" then
			Apply()
		end
	end)
	Apply()
end)
