---@type string, TFNamespace
local _, ns = ...

local KEY = "cursorTooltips"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Tooltip at the cursor",
	tooltip = "The game's own tooltips follow the mouse cursor instead of the game's fixed corner. "
		.. "Tooltips a window places itself, such as a bag item's, stay where it puts them.",
	default = false,
})

-- Blizzard places a tooltip it has no owner anchor for at a fixed corner through GameTooltip_SetDefaultAnchor.
-- Re-anchoring it to the cursor with the client's own cursor anchor moves it with the mouse, with no per-frame work
-- of ours. Only GameTooltip is re-anchored: an owner that places its own tooltip (bags, item buttons) sets that
-- anchor itself and never calls here. The hook is a secure post-hook, and it passes the owner through untouched,
-- so a unit frame or action button it owns is never read or written.
ns.Init(function()
	hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
		if tooltip == GameTooltip and ns.Active(KEY) then
			tooltip:SetOwner(parent, "ANCHOR_CURSOR")
		end
	end)
end)
