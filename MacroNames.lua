---@type string, TFNamespace
local _, ns = ...

ns.Feature({
	key = "hideMacroNames",
	category = "Interface",
	name = "Hide macro names",
	tooltip = "Action buttons show a macro's icon without its name across the bottom.",
	default = false,
	conflicts = { { addon = "Dominos" }, { addon = "Bartender4" }, { addon = "ElvUI" } },
})

-- Buttons whose name this has faded, so switching off touches only those.
---@type table<Frame, boolean>
local faded = {}

-- Blizzard sets the name's text on every update but never its alpha, so fading it survives those updates, and a
-- font string on a secure button can change in combat without taint.
local function Apply(button)
	local name = button.Name
	if not name then
		return
	end
	if ns.Active("hideMacroNames") then
		name:SetAlpha(0)
		faded[button] = true
	elseif faded[button] then
		name:SetAlpha(1)
		faded[button] = nil
	end
end

-- Every button that shows action text registers here as it loads: the main bar, the multibars (5-7 too), the
-- override bar and the gamepad bars. Stance, pet and possess buttons never get a name.
local function ApplyAll()
	ActionBarButtonEventsFrame:ForEachFrame(Apply)
end

ns.Init(function()
	-- The bars' buttons exist before login; a load-on-demand bar (the gamepad bars) makes its own as it loads.
	-- Never hooksecurefunc on the events frame's RegisterFrame: that writes into the action bars' secure code.
	ns.On("ADDON_LOADED", ApplyAll)
	ApplyAll()
	Settings.SetOnValueChangedCallback("TweaksForever_hideMacroNames", ApplyAll)
end)
