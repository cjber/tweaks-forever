local _, ns = ...

ns.Feature({
	key = "retailTooltips",
	category = "Interface",
	name = "Retail tooltip border",
	tooltip = "Tooltips get the retail game's thin silver border in place of the beige one.",
	default = true,
	conflicts = {
		{ addon = "Aurora" },
		{ addon = "ElvUI" },
		{ addon = "TinyTooltip" },
		{ addon = "TipTac" },
	},
})

-- WoW: Forever resolves an atlas from its own art set first, and that set has a beige "-c60" member for every
-- Tooltip-NineSlice border piece, so SetAtlas never reaches retail's silver one. Retail's sheets still ship, so
-- the pieces are drawn from them by file and texture coordinates. The centre has no Forever member and is already
-- retail's, as is the health bar hanging under a unit's tooltip.
local SHEET, SIDES = "Interface\\Tooltips\\UIFrameTooltip", "Interface\\Tooltips\\UIFrameTooltipVertical"
-- [piece] = { file, left, right, top, bottom }: the retail atlas members' pixels on the 16x64 and 32x16 sheets.
local PIECES = {
	TopLeftCorner = { SHEET, 1 / 16, 8 / 16, 37 / 64, 44 / 64 },
	TopRightCorner = { SHEET, 1 / 16, 8 / 16, 46 / 64, 53 / 64 },
	BottomLeftCorner = { SHEET, 1 / 16, 8 / 16, 19 / 64, 26 / 64 },
	BottomRightCorner = { SHEET, 1 / 16, 8 / 16, 28 / 64, 35 / 64 },
	TopEdge = { SHEET, 0, 1, 10 / 64, 17 / 64 },
	BottomEdge = { SHEET, 0, 1, 1 / 64, 8 / 64 },
	LeftEdge = { SIDES, 1 / 32, 8 / 32, 0, 1 },
	RightEdge = { SIDES, 10 / 32, 17 / 32, 0, 1 },
}
-- The NineSlice layouts drawn with that border.
local LAYOUTS = { TooltipDefaultLayout = true, TooltipDefaultDarkLayout = true }

-- Taint: only engine calls on the NineSlice's own textures, from a hooksecurefunc hook after Blizzard styled it.
local function Paint(tooltip)
	local frame = tooltip.NineSlice
	-- An embedded tooltip hides its border.
	if not frame:IsShown() then
		return
	end
	for name, piece in pairs(PIECES) do
		local texture = frame[name]
		texture:SetTexture(piece[1])
		texture:SetTexCoord(piece[2], piece[3], piece[4], piece[5])
		-- The edge atlases tile; each edge is the same line all along its length, so stretching it draws the same.
		texture:SetHorizTile(false)
		texture:SetVertTile(false)
	end
end

ns.Init(function()
	-- Blizzard restyles a tooltip every time it hides, so turning the setting off or on shows on the next one.
	hooksecurefunc("SharedTooltip_SetBackdropStyle", function(tooltip, style)
		if ns.Active("retailTooltips") and LAYOUTS[style and style.layoutType or "TooltipDefaultLayout"] then
			Paint(tooltip)
		end
	end)
	-- These were styled on load, before the hook, and could be shown before they first hide.
	if ns.Active("retailTooltips") then
		for _, tooltip in ipairs({
			GameTooltip,
			ItemRefTooltip,
			ShoppingTooltip1,
			ShoppingTooltip2,
			ItemRefShoppingTooltip1,
			ItemRefShoppingTooltip2,
		}) do
			Paint(tooltip)
		end
	end
end)
