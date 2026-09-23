local _, ns = ...

ns.Feature({
	key = "retailTooltips",
	category = "Interface",
	name = "Retail-style tooltips",
	tooltip = "Tooltips get a thin grey border like the retail game's, and a unit's health bar sits inside its "
		.. "tooltip in the unit's class or reaction colour, with its health as numbers.",
	default = true,
	conflicts = {
		{ addon = "Aurora" },
		{ addon = "ElvUI" },
		{ addon = "TinyTooltip" },
		{ addon = "TipTac" },
	},
})

-- WoW: Forever resolves an atlas from its own art set first, and that set has a beige "-c60" member for every
-- Tooltip-NineSlice border piece, so SetAtlas never reaches retail's. Retail's sheets still ship, so the pieces are
-- drawn from them by file and texture coordinates. The centre has no Forever member and is already retail's.
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
-- Retail's art is a white line lit brighter along the top; this softens it to the grey of the retail tooltip.
local BORDER = { 0.6, 0.62, 0.66 }

-- The health bar: this far in from the tooltip's edges, this tall, and this far below the last line. The tooltip's
-- own margin under its lines is 10.
local EDGE, HEIGHT, GAP = 9, 12, 8
local PADDING = EDGE + HEIGHT + GAP - 10
local OBJECT = { 0, 0.6, 0.1 }

-- Taint: only engine calls on the NineSlice's own textures, from a hooksecurefunc hook after Blizzard styled it.
-- ApplyLayout leaves vertex colours alone, so every other restyle puts the border's colour back.
local function Paint(tooltip, retail)
	local frame = tooltip.NineSlice
	for name, piece in pairs(PIECES) do
		local texture = frame[name]
		if retail then
			texture:SetTexture(piece[1])
			texture:SetTexCoord(piece[2], piece[3], piece[4], piece[5])
			-- The edge atlases tile; each edge is the same line all along its length, so stretching it draws the
			-- same.
			texture:SetHorizTile(false)
			texture:SetVertTile(false)
			texture:SetVertexColor(BORDER[1], BORDER[2], BORDER[3])
		elseif texture then
			texture:SetVertexColor(1, 1, 1)
		end
	end
end

local function Restyle(tooltip, style)
	local retail = ns.Active("retailTooltips")
		and LAYOUTS[style and style.layoutType or "TooltipDefaultLayout"]
		-- An embedded tooltip hides its border.
		and tooltip.NineSlice:IsShown()
	Paint(tooltip, retail)
end

-- The unit health bar Blizzard hangs under GameTooltip, moved inside it. Blizzard still watches the unit and sets the
-- bar's value, which can be secret; this file never reads it. It only anchors, sizes, textures and colours the bar
-- (engine calls) and adds a track, outline and text of its own.
local function HealthBar()
	local tooltip = GameTooltip
	local bar = tooltip.StatusBar
	local outline = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
	outline:SetColorTexture(0, 0, 0, 0.9)
	outline:SetPoint("TOPLEFT", -1, 1)
	outline:SetPoint("BOTTOMRIGHT", 1, -1)
	local track = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
	track:SetColorTexture(0.08, 0.08, 0.1, 0.9)
	track:SetAllPoints()
	local text = bar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
	text:SetPoint("CENTER")
	-- The unit shown, as the token the tooltip was given, and the bar's colour.
	local unit
	local r, g, b = OBJECT[1], OBJECT[2], OBJECT[3]

	local function Update()
		if not ns.Active("retailTooltips") then
			return
		end
		bar:SetStatusBarColor(r, g, b)
		-- UnitHealth always may return a secret, and UnitHealthMax does for NPCs under addon restrictions.
		-- BreakUpLargeNumbers and SetFormattedText both take secrets, so the numbers go straight to the screen with
		-- no arithmetic or comparison.
		if unit and UnitExists(unit) then
			text:SetFormattedText(
				"%s / %s",
				BreakUpLargeNumbers(UnitHealth(unit)),
				BreakUpLargeNumbers(UnitHealthMax(unit))
			)
			text:Show()
		else
			text:Hide()
		end
	end

	-- Room under the last line for the bar, made with the tooltip's padding, which GameTooltip clears as it shows.
	local function Fit()
		if ns.Active("retailTooltips") and bar:IsShown() then
			tooltip:SetPadding((tooltip:GetPadding()), PADDING, 0, 0)
		end
	end

	local function Style()
		local retail = ns.Active("retailTooltips")
		bar:ClearAllPoints()
		if retail then
			bar:SetPoint("BOTTOMLEFT", EDGE, EDGE)
			bar:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
			bar:SetHeight(HEIGHT)
			bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
		else
			-- GameTooltip.xml's own placement and art.
			bar:SetPoint("TOPLEFT", tooltip, "BOTTOMLEFT", 2, -1)
			bar:SetPoint("TOPRIGHT", tooltip, "BOTTOMRIGHT", -2, -1)
			bar:SetHeight(8)
			bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
			bar:SetStatusBarColor(0, 1, 0)
		end
		outline:SetShown(retail)
		track:SetShown(retail)
		text:SetShown(retail)
		Update()
		Fit()
	end

	-- The token comes from the tooltip's caller, or is the mouseover for a world tooltip, never from the tooltip's
	-- GUID: UnitTokenFromGUID returns a secret token for an NPC under addon restrictions, and no unit API takes one
	-- from addon code. Players take their class colour (UnitClass is only secret for units that aren't
	-- player-controlled), others the colour of their reaction, as the name above does. A health bar with no unit is
	-- a destructible object's.
	local function Watch(token)
		unit = UnitExists(token) and token or nil
		r, g, b = OBJECT[1], OBJECT[2], OBJECT[3]
		local color
		if unit and UnitIsPlayer(unit) then
			color = C_ClassColor.GetClassColor(select(2, UnitClass(unit)))
		elseif unit then
			color = FACTION_BAR_COLORS[UnitReaction(unit, "player")]
		end
		if color then
			r, g, b = color.r, color.g, color.b
		end
		Update()
		Fit()
	end

	hooksecurefunc(tooltip, "SetUnit", function(_, token)
		Watch(token)
	end)
	hooksecurefunc(tooltip, "SetWorldCursor", function()
		Watch("mouseover")
	end)
	-- Blizzard colours the bar green on every change.
	bar:HookScript("OnValueChanged", Update)
	bar:HookScript("OnShow", Fit)
	bar:HookScript("OnHide", function()
		if ns.Active("retailTooltips") and tooltip:IsShown() then
			tooltip:SetPadding((tooltip:GetPadding()), 0, 0, 0)
		end
	end)
	tooltip:HookScript("OnShow", Fit)
	Settings.SetOnValueChangedCallback("TweaksForever_retailTooltips", Style)
	Style()
end

ns.Init(function()
	-- Blizzard restyles a tooltip every time it hides, so turning the setting off or on shows on the next one.
	hooksecurefunc("SharedTooltip_SetBackdropStyle", Restyle)
	-- These were styled on load, before the hook, and could be shown before they first hide.
	for _, tooltip in ipairs({
		GameTooltip,
		ItemRefTooltip,
		ShoppingTooltip1,
		ShoppingTooltip2,
		ItemRefShoppingTooltip1,
		ItemRefShoppingTooltip2,
	}) do
		Restyle(tooltip)
	end
	HealthBar()
end)
