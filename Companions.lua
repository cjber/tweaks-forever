---@type string, TFNamespace
local _, ns = ...

ns.Feature({
	key = "companionHints",
	category = "Interface",
	name = "Suggest companion addons",
	tooltip = "Where another Forever addon would help, such as Shortest Path Forever on a dungeon entrance, a grey "
		.. "line in the tooltip says so.",
	default = true,
})

-- A grey hint line for a companion addon: `install` while it isn't there, `enable` while it is but hasn't loaded,
-- nothing once it has or with the setting off. Whole sentences, so each reads right in any language.
---@param addon string its folder name
---@param install string
---@param enable string
---@return string?
function ns.Suggestion(addon, install, enable)
	if not ns.Active("companionHints") or C_AddOns.IsAddOnLoaded(addon) then
		return nil
	end
	return C_AddOns.DoesAddOnExist(addon) and enable or install
end
