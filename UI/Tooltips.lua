---@type string, TFNamespace
local addonName, ns = ...

local KEY, STYLE = "retailTooltips", "tooltipStyle"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Modern tooltips",
	tooltip = "Tooltips get a thin grey border with rounded corners in place of the beige one. A player's name "
		.. "is in their class colour with their race and class on one line, and a unit's health bar sits inside "
		.. "its tooltip, with the health as numbers for players and as a percentage for others.",
	default = true,
	conflicts = {
		{ addon = "Aurora" },
		{ addon = "ElvUI" },
		{ addon = "TinyTooltip" },
		{ addon = "TipTac" },
	},
})

ns.Feature({
	key = STYLE,
	category = "Interface",
	name = "Tooltip style",
	tooltip = "Modern is a neutral charcoal that keeps the text crisp over any scenery. Retail is the retail "
		.. "game's navy, a little see-through. Forever keeps the game's own beige border.",
	default = "modern",
	options = {
		{ "modern", "Modern" },
		{ "retail", "Retail" },
		{ "forever", "Forever" },
	},
	parent = KEY,
})

-- WoW: Forever resolves the Tooltip-NineSlice atlases to its own beige art. The whole tooltip is drawn instead from
-- media/TooltipBorder<Style>.tga (tools/tooltip_border.py): the line and the background inside it, cut into all nine
-- pieces, Center included, with 7-unit corners and a 2-unit middle the edges and Center stretch. Blizzard's own
-- Center starts 3 units in, exactly where the line ends; two textures placed separately and meeting edge to edge
-- open a gap on whichever side a sub-pixel falls the wrong way, so the background comes from the same file.
local FILES = {
	modern = "Interface\\AddOns\\" .. addonName .. "\\media\\TooltipBorderModern",
	retail = "Interface\\AddOns\\" .. addonName .. "\\media\\TooltipBorderRetail",
}
local PIECES = { -- [piece] = { left, right, top, bottom } in sixteenths of the file
	TopLeftCorner = { 0, 7, 0, 7 },
	TopRightCorner = { 9, 16, 0, 7 },
	BottomLeftCorner = { 0, 7, 9, 16 },
	BottomRightCorner = { 9, 16, 9, 16 },
	TopEdge = { 7, 9, 0, 7 },
	BottomEdge = { 7, 9, 9, 16 },
	LeftEdge = { 0, 7, 7, 9 },
	RightEdge = { 9, 16, 7, 9 },
	Center = { 7, 9, 7, 9 },
}
-- The NineSlice layouts drawn with that border.
local LAYOUTS = { TooltipDefaultLayout = true, TooltipDefaultDarkLayout = true }
local GUILD = { 0.6, 0.6, 0.6 }

-- The health bar's fill: this far in from the tooltip's sides and bottom, this tall, and this far below the
-- last line. The tooltip's own margin under its lines is 10. The track under the fill is its colour at this shade.
local EDGE, BOTTOM, HEIGHT, GAP = 10, 11, 12, 10
local PADDING = BOTTOM + HEIGHT + GAP - 10
local TRACK = 0.3
local OBJECT = { 0, 0.6, 0.1 }
-- Room at the top of a comparison tooltip for its "Equipped" header.
local HEADER = 16

-- Taint: only engine calls on the NineSlice's own textures, from a hooksecurefunc hook after Blizzard styled it.
-- Every restyle puts Blizzard's atlases, Center's anchors and its colour back, so there is nothing to undo.
---@param file string
local function Paint(tooltip, file)
	local frame = tooltip.NineSlice
	for name, piece in pairs(PIECES) do
		local texture = frame[name]
		texture:SetTexture(file)
		-- The atlases tile; the file stretches. Tiling first, as NineSliceUtil does, then the coordinates.
		texture:SetHorizTile(false)
		texture:SetVertTile(false)
		texture:SetTexCoord(piece[1] / 16, piece[2] / 16, piece[3] / 16, piece[4] / 16)
		-- The file's colours are final; this clears SetCenterColor's tint.
		texture:SetVertexColor(1, 1, 1)
	end
	-- Center fills the middle between the corners, where the file's middle is background only.
	local center = frame.Center
	center:ClearAllPoints()
	center:SetPoint("TOPLEFT", frame.TopLeftCorner, "BOTTOMRIGHT")
	center:SetPoint("BOTTOMRIGHT", frame.BottomRightCorner, "TOPLEFT")
end

local function Restyle(tooltip, style)
	-- Forever's own style is Blizzard's, which it has just drawn.
	local file = FILES[ns.db[STYLE]]
	if
		file
		and ns.Active(KEY)
		and LAYOUTS[style and style.layoutType or "TooltipDefaultLayout"]
		-- An embedded tooltip hides its border.
		and tooltip.NineSlice:IsShown()
	then
		Paint(tooltip, file)
	end
end

-- A tooltip takes its style as it hides, so a hidden one already wears the old style for its next show: redraw
-- those now, Forever's with Blizzard's own default layout and colour. A shown one takes the new style as it hides.
local function Repaint(tooltips)
	for _, tooltip in ipairs(tooltips) do
		if not tooltip:IsShown() and tooltip.NineSlice:IsShown() then
			if FILES[ns.db[STYLE]] then
				Restyle(tooltip)
			else
				NineSliceUtil.ApplyLayout(tooltip.NineSlice, NineSliceUtil.GetLayout("TooltipDefaultLayout"))
				local r, g, b = TOOLTIP_DEFAULT_BACKGROUND_COLOR:GetRGB()
				tooltip.NineSlice:SetCenterColor(r, g, b, 1)
			end
		end
	end
end

-- The retail game's tooltip status bar: TargetingFrame's bar texture, on a track of the same texture in a darker
-- shade, framed by Blizzard's own tooltip bar border as TooltipStatusBarTemplate places it, 2 out on every side.
local FILL = "Interface\\TargetingFrame\\UI-StatusBar"
local FRAME = "Interface\\Tooltips\\UI-StatusBar-Border"
-- The border file is 128x16 and drawn 16 tall, so a texel is a unit. Its 8-texel ends stay at native size and
-- only the flat middle stretches along the bar.
local FRAME_SIZE, FRAME_CAP, FRAME_OUT = 128, 8, 2

-- One piece of the border, cut from texel `from` to `to` of the file.
local function FramePiece(bar, from, to)
	local piece = bar:CreateTexture(nil, "OVERLAY", nil, -1)
	piece:SetTexture(FRAME)
	piece:SetTexCoord(from / FRAME_SIZE, to / FRAME_SIZE, 0, 1)
	piece:SetHeight(HEIGHT + 2 * FRAME_OUT)
	return piece
end

local function HealthBarArt(bar)
	local track = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
	track:SetTexture(FILL)
	track:SetAllPoints()
	local left = FramePiece(bar, 0, FRAME_CAP)
	left:SetWidth(FRAME_CAP)
	left:SetPoint("TOPLEFT", -FRAME_OUT, FRAME_OUT)
	local right = FramePiece(bar, FRAME_SIZE - FRAME_CAP, FRAME_SIZE)
	right:SetWidth(FRAME_CAP)
	right:SetPoint("TOPRIGHT", FRAME_OUT, FRAME_OUT)
	local middle = FramePiece(bar, FRAME_CAP, FRAME_SIZE - FRAME_CAP)
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("TOPRIGHT", right, "TOPLEFT")
	-- The Arial Narrow outline Blizzard puts on its own bars' numbers (the profession rank bar, retail's damage meter).
	local text = bar:CreateFontString(nil, "OVERLAY", "Number12FontOutline")
	text:SetPoint("CENTER")
	return { track, left, middle, right, text }, track, text
end

local function HealthBarStyle(tooltip, bar, art, Update, Fit)
	local function Style()
		local retail = ns.Active(KEY)
		bar:ClearAllPoints()
		if retail then
			bar:SetPoint("BOTTOMLEFT", EDGE, BOTTOM)
			bar:SetPoint("BOTTOMRIGHT", -EDGE, BOTTOM)
			bar:SetHeight(HEIGHT)
			bar:SetStatusBarTexture(FILL)
		else
			-- GameTooltip.xml's own placement and art.
			bar:SetPoint("TOPLEFT", tooltip, "BOTTOMLEFT", 2, -1)
			bar:SetPoint("TOPRIGHT", tooltip, "BOTTOMRIGHT", -2, -1)
			bar:SetHeight(8)
			bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
			bar:SetStatusBarColor(0, 1, 0)
		end
		for _, region in ipairs(art) do
			region:SetShown(retail)
		end
		Update()
		Fit()
	end

	return Style
end

-- The unit health bar Blizzard hangs under GameTooltip, moved inside it. Blizzard still watches the unit and sets the
-- bar's value, which can be secret; this file never reads it. It only anchors, sizes, textures and colours the bar
-- (engine calls) and adds a track, border and text of its own.
local function HealthBar()
	local tooltip = GameTooltip
	local bar = tooltip.StatusBar
	local art, track, text = HealthBarArt(bar)
	-- The unit shown, as the token the tooltip was given, whether it is a player, and the bar's colour.
	local unit, player
	local r, g, b = OBJECT[1], OBJECT[2], OBJECT[3]

	local function Update()
		if not ns.Active(KEY) then
			return
		end
		bar:SetStatusBarColor(r, g, b)
		track:SetVertexColor(r * TRACK, g * TRACK, b * TRACK)
		-- UnitHealth may always return a secret, UnitHealthMax does for units that aren't player-controlled, and
		-- UnitHealthPercent does whenever its inputs are. Each goes straight to an API documented to take secrets
		-- (BreakUpLargeNumbers, SetFormattedText): no arithmetic or comparison on any of them. The percentage is
		-- scaled to 0-100 by Blizzard's curve inside UnitHealthPercent.
		if not unit or not UnitExists(unit) then
			text:Hide()
			return
		end
		if player then
			text:SetFormattedText(
				"%s / %s",
				BreakUpLargeNumbers(UnitHealth(unit)),
				BreakUpLargeNumbers(UnitHealthMax(unit))
			)
		else
			-- ScaleTo100 is numeric; the API's return union also covers colour curves.
			local percent = UnitHealthPercent(unit, true, CurveConstants.ScaleTo100) --[[@as number]]
			text:SetFormattedText("%.0f%%", percent)
		end
		text:Show()
	end

	-- Room under the last line for the bar, made with the tooltip's padding, which GameTooltip clears as it shows.
	local function Fit()
		if ns.Active(KEY) and bar:IsShown() then
			local right, _, left, top = tooltip:GetPadding()
			tooltip:SetPadding(right, PADDING, left, top)
		end
	end

	local Style = HealthBarStyle(tooltip, bar, art, Update, Fit)

	-- The token comes from the tooltip's caller, or is the mouseover for a world tooltip, never from the tooltip's
	-- GUID: UnitTokenFromGUID returns a secret token for an NPC under addon restrictions, and no unit API takes one
	-- from addon code. Players take their class colour (UnitClass is only secret for units that aren't
	-- player-controlled), others the colour of their reaction, as the name above does. A health bar with no unit is
	-- a destructible object's.
	local function Watch(token)
		unit = UnitExists(token) and token or nil
		player = unit and UnitIsPlayer(unit)
		r, g, b = OBJECT[1], OBJECT[2], OBJECT[3]
		local color
		if player then
			-- UnitClass also returns the class ID, which GetClassColor would take as its tint colour.
			local _, classFile = UnitClass(unit)
			color = C_ClassColor.GetClassColor(classFile)
		elseif unit then
			color = FACTION_BAR_COLORS[UnitReaction(unit, "player")]
		end
		if color then
			r, g, b = color.r, color.g, color.b
		end
		Update()
		Fit()
	end

	ns.OnTooltip(Enum.TooltipDataType.Unit, { GetUnit = true, GetWorldCursor = true }, function(_, getter, token)
		Watch(getter == "GetUnit" and token or "mouseover")
	end)
	-- Blizzard colours the bar green on every change.
	bar:HookScript("OnValueChanged", Update)
	bar:HookScript("OnShow", Fit)
	bar:HookScript("OnHide", function()
		if ns.Active(KEY) and tooltip:IsShown() then
			local right, _, left, top = tooltip:GetPadding()
			tooltip:SetPadding(right, 0, left, top)
		end
	end)
	tooltip:HookScript("OnShow", Fit)
	return Style
end

-- A player's lines as the retail game writes them: the name in the class colour, the guild in brackets, race and
-- class on the level line, and the faction in its colour. Forever gives the class a line of its own; a line
-- pre-call drops it before it is added, which Blizzard's TooltipDataProcessor allows insecure callers, and the
-- post-call edits GameTooltip's own left-line font strings in place with SetText and SetTextColor.
--
-- Secret values: only a player's tooltip is touched. GetPlayerInfoByGUID takes a secret GUID and returns
-- nothing for a unit that isn't a player; its returns are not documented as secret, and a player's identity (name,
-- race, class) is exempt from the identity restriction, so the class and race it returns are ordinary strings and
-- so are the player's lines. An NPC's lines are left exactly as Blizzard wrote them.
local function UnitLines()
	-- The player tooltip being built: its data, class and race, level, whether the level line has gone by, and
	-- whether the class line was dropped.
	local building, className, classFile, race, level, passed, dropped

	TooltipDataProcessor.AddTooltipPreCall(Enum.TooltipDataType.Unit, function(tooltip, data)
		building = nil
		if tooltip ~= GameTooltip or not ns.Active(KEY) then
			return
		end
		local _
		className, classFile, race, _, _, _, _, level = GetPlayerInfoByGUID(data.guid)
		if classFile then
			building, passed, dropped = data, false, false
		end
	end)

	TooltipDataProcessor.AddLinePreCall(TooltipDataProcessor.AllTypes, function(tooltip, line)
		if not building or tooltip ~= GameTooltip or dropped then
			return
		end
		local info = tooltip:GetProcessingTooltipInfo()
		if not info or info.tooltipData ~= building then
			return
		end
		local text = line.leftText
		if type(text) ~= "string" then
			return
		end
		if not passed then
			passed = text:find(race, 1, true) ~= nil
		elseif text == className and not line.rightText then
			dropped = true
			return true
		end
	end)

	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
		if not building or data ~= building then
			return
		end
		building = nil
		local color = C_ClassColor.GetClassColor(classFile)
		if color then
			_G.GameTooltipTextLeft1:SetTextColor(color.r, color.g, color.b)
		end
		local levelLine
		for i = 2, tooltip:NumLines() do
			local line = _G["GameTooltipTextLeft" .. i]
			local text = line:GetText()
			-- A line's text may be secret; nothing past it is read.
			if not canaccessvalue(text) or not text then
				break
			end
			if not levelLine and text:find(race, 1, true) and (not level or text:find(tostring(level), 1, true)) then
				levelLine = i
				if dropped and not text:find(className, 1, true) then
					local _, stop = text:find(race, 1, true)
					line:SetText(text:sub(1, stop) .. " " .. className .. text:sub(stop + 1))
				end
			elseif levelLine and (text == FACTION_ALLIANCE or text == FACTION_HORDE) then
				local factionColor = PLAYER_FACTION_COLORS[text == FACTION_ALLIANCE and 1 or 0]
				line:SetTextColor(factionColor.r, factionColor.g, factionColor.b)
			end
		end
		-- One line between the name and the level line is the guild.
		if levelLine == 3 then
			local line = _G.GameTooltipTextLeft2
			local text = line:GetText()
			if canaccessvalue(text) and text and text:sub(1, 1) ~= "<" then
				line:SetText("<" .. text .. ">")
			end
			line:SetTextColor(GUILD[1], GUILD[2], GUILD[3])
		end
	end)
end

-- A comparison tooltip's "Equipped" header, moved from the tab above the tooltip to a grey line inside its top,
-- with room made by the tooltip's top padding. Blizzard shows the header before it adds the item's lines, sets its
-- text and width each time, and hides it when the tooltip clears; it never sets the label's colour or anchors.
local function CompareHeader(tooltip)
	local header = tooltip.CompareHeader
	local label = header.Label
	local tab
	for _, region in ipairs({ header:GetRegions() }) do
		if region:IsObjectType("Texture") then
			tab = region
		end
	end
	local below = header:GetFrameLevel() - tooltip:GetFrameLevel()

	local function Pad(top)
		local right, bottom, left = tooltip:GetPadding()
		tooltip:SetPadding(right, bottom, left, top)
	end

	local function Fit()
		if ns.Active(KEY) and header:IsShown() then
			-- The tooltip's background shares its frame level; the label has to draw above it.
			header:SetFrameLevel(tooltip:GetFrameLevel() + 1)
			Pad(HEADER)
		end
	end

	local function Style()
		local retail = ns.Active(KEY)
		label:ClearAllPoints()
		if retail then
			label:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 10, -10)
			label:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
			Fit()
		else
			label:SetPoint("CENTER")
			label:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
			header:SetFrameLevel(tooltip:GetFrameLevel() + below)
			if header:IsShown() then
				Pad(0)
			end
		end
		tab:SetShown(not retail)
	end

	header:HookScript("OnShow", Fit)
	tooltip:HookScript("OnShow", Fit)
	header:HookScript("OnHide", function()
		if ns.Active(KEY) then
			Pad(0)
		end
	end)
	return Style
end

ns.Init(function()
	-- Blizzard restyles a tooltip every time it hides, so turning the setting off or on shows on the next one.
	hooksecurefunc("SharedTooltip_SetBackdropStyle", Restyle)
	local styles = { HealthBar() }
	-- These were styled on load, before the hook, and could be shown before they first hide.
	local tooltips = {
		GameTooltip,
		ItemRefTooltip,
		ShoppingTooltip1,
		ShoppingTooltip2,
		ItemRefShoppingTooltip1,
		ItemRefShoppingTooltip2,
	}
	for _, tooltip in ipairs(tooltips) do
		Restyle(tooltip)
		if tooltip.CompareHeader then
			styles[#styles + 1] = CompareHeader(tooltip)
		end
	end
	UnitLines()
	local function Style()
		for _, style in ipairs(styles) do
			style()
		end
	end
	ns.OnSettingChanged(KEY, Style)
	ns.OnSettingChanged(STYLE, function()
		Repaint(tooltips)
	end)
	Style()
end)
