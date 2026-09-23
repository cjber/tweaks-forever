---@type string, TFNamespace
local _, ns = ...

local KEY = "largerNameplates"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Larger, clearer nameplates",
	tooltip = "Nameplates get a taller health bar with the name above its left end and the level, coloured by "
		.. "difficulty, above its right. Your target is outlined in gold and the others fade back while you have one. "
		.. "Casts show in a slimmer bar with the spell's icon and name inside it. Health numbers follow the game's "
		.. "Nameplates options. Switching this on or off takes effect after the next reload.",
	default = true,
	conflicts = {
		{ addon = "Plater" },
		{ addon = "Kui_Nameplates" },
		{ addon = "TidyPlates_ThreatPlates" },
		{ addon = "Platynator" },
		{ addon = "ElvUI" },
	},
})

-- Restyles Blizzard's own nameplate unit frames after Blizzard lays them out, from hooksecurefunc hooks, with engine
-- calls only (anchors, sizes, fonts, colours, alpha). Nothing is written into Blizzard's tables and no Blizzard
-- method is called, so its nameplate code, which handles secret health and cast values, never runs tainted.
-- Forbidden nameplates (friendly units in instances) are never handed to addon code and keep Blizzard's look.
-- Blizzard reserves each plate's height from its own style's sizes; this layout is no taller than Forever's
-- default Thin style, 1 unit shorter, so plates stack as before. Sizes are at Medium and scale with the setting.
local HEALTH, CAST, GAP, NAME_GAP, HEALTH_TEXT, GLOW = 16, 12, 2, 2, 11, 5
local DIMMED, GLOW_ALPHA = 0.6, 0.55
local GOLD = NORMAL_FONT_COLOR
local TROUGH = { 0.07, 0.07, 0.08, 0.92 }

-- [unit frame] = the 1-unit edge drawn around its health bar. Unit frames are pooled, so each is hooked and given
-- its edge once and reused for many units.
---@type table<NamePlateUnitFrame, Texture>
local edges = setmetatable({}, { __mode = "k" })

-- Asks the game rather than the frame's cached isTarget: the frame's own PLAYER_TARGET_CHANGED handler may run
-- after this addon's.
---@param frame NamePlateUnitFrame
local function Dim(frame)
	local unit = frame.unit
	local faded = unit and UnitExists("target") and not UnitIsUnit(unit, "target") and not UnitIsUnit(unit, "focus")
	frame:SetAlpha(faded and DIMMED or 1)
end

-- The target's edge is gold, with Blizzard's selection border as a soft glow outside it, in gold too. The focus
-- keeps Blizzard's focus colour on the glow.
---@param frame NamePlateUnitFrame
local function Border(frame)
	local bar = frame.HealthBarsContainer.healthBar
	local target = bar:IsTarget()
	if target then
		edges[frame]:SetColorTexture(GOLD.r, GOLD.g, GOLD.b)
		bar.selectedBorder:SetVertexColor(GOLD.r, GOLD.g, GOLD.b)
	else
		edges[frame]:SetColorTexture(0, 0, 0)
	end
end

-- A flat fill over a dark trough inside a 1-unit edge, in place of the cooldown-manager bar art.
---@param frame NamePlateUnitFrame
---@param bar NamePlateHealthBar
local function HealthArt(frame, bar)
	bar.barTexture:SetAtlas("widgetstatusbar-fill-white")
	-- The Classic style moves this background above the fill; the trough goes back under it.
	bar.bgTexture:ClearAllPoints()
	bar.bgTexture:SetAllPoints(bar)
	bar.bgTexture:SetDrawLayer("BACKGROUND", 0)
	bar.bgTexture:SetColorTexture(unpack(TROUGH))
	bar.deselectedOverlay:SetAlpha(0)
	local glow = bar.selectedBorder
	glow:ClearAllPoints()
	glow:SetPoint("TOPLEFT", bar, "TOPLEFT", -GLOW, GLOW)
	glow:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", GLOW, -GLOW)
	glow:SetAlpha(GLOW_ALPHA)
	Border(frame)
end

---@param frame NamePlateUnitFrame
---@param scale number
local function CastBar(frame, scale)
	local container = frame.CastBarsContainer
	local cast = container.castBar
	container:SetHeight(CAST * scale)
	cast:ClearAllPoints()
	cast:SetPoint("TOPLEFT", container, "TOPLEFT")
	cast:SetPoint("TOPRIGHT", container, "TOPRIGHT")
	cast:SetHeight(CAST * scale)
	cast.Spark:SetHeight(CAST * scale)
	cast.Icon:ClearAllPoints()
	cast.Icon:SetPoint("LEFT", cast, "LEFT")
	cast.Icon:SetSize(CAST * scale, CAST * scale)
	-- Blizzard anchors the spell name to the icon's right, and the cast's target name after it; both stay inside.
	cast.Text:ClearAllPoints()
	cast.Text:SetPoint("LEFT", cast.Icon, "RIGHT", 3, 0)
end

---@param frame NamePlateUnitFrame
local function Layout(frame)
	if frame:IsShowOnlyName() or frame.widgetsOnlyMode then
		return
	end
	local scale = NamePlateSetupOptions.verticalScale
	CastBar(frame, scale)

	local health = frame.HealthBarsContainer
	health:ClearAllPoints()
	health:SetPoint("BOTTOMLEFT", frame.CastBarsContainer, "TOPLEFT", 0, GAP * scale)
	health:SetPoint("BOTTOMRIGHT", frame.CastBarsContainer, "TOPRIGHT", 0, GAP * scale)
	health:SetHeight(HEALTH * scale)

	-- Blizzard's level box, which colours the level by difficulty and shows a skull for ??, without its box.
	local level = frame.PlayerLevelDiffFrame
	level:ClearAllPoints()
	level:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", 0, NAME_GAP * scale)
	level:SetHeight(frame.name:GetLineHeight())
	level.playerLevelDiffIcon:SetAlpha(0)
	if level.selectedBorder then
		level.selectedBorder:SetAlpha(0)
	end
	-- The Classic style's own level, set into its bar border, would repeat it.
	frame.LevelFrame:SetAlpha(0)

	-- Blizzard's plain nameplate font: it notes an outline is harder to read outside the bar.
	local name = frame.name
	name:SetFontObject("SystemFont_NamePlate")
	name:SetTextHeight(NamePlateSetupOptions.healthBarFontHeight)
	name:ClearAllPoints()
	name:SetJustifyH("LEFT")
	name:SetPoint("BOTTOMLEFT", health, "TOPLEFT", 0, NAME_GAP * scale)
	name:SetPoint("RIGHT", level, "LEFT", -4, 0)

	-- Health percent and value, when the game's Nameplates options show them, inside the bar's right end.
	local bar = health.healthBar
	HealthArt(frame, bar)
	for _, text in ipairs({ bar.Text, bar.RightText, bar.LeftText }) do
		text:ClearAllPoints()
		text:SetFontObject("SystemFont_NamePlate_Outlined")
		text:SetTextHeight(HEALTH_TEXT * scale)
	end
	bar.LeftText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
	bar.RightText:SetPoint("RIGHT", bar.LeftText, "LEFT", -3, 0)
	bar.Text:SetPoint("RIGHT", bar.RightText, "LEFT", 2, 0)

	Dim(frame)
end

---@param frame NamePlateUnitFrame
local function Style(frame)
	if not edges[frame] then
		local bar = frame.HealthBarsContainer.healthBar
		local edge = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
		edge:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
		edge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
		edges[frame] = edge
		hooksecurefunc(frame, "UpdateAnchors", Layout)
		hooksecurefunc(frame.HealthBarsContainer.healthBar, "UpdateSelectionBorder", function()
			Border(frame)
		end)
	end
	Layout(frame)
end

---@param fn fun(frame: NamePlateUnitFrame)
local function ForEachPlate(fn)
	for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
		if plate.UnitFrame then
			fn(plate.UnitFrame)
		end
	end
end

ns.Init(function()
	if not ns.Active(KEY) then
		return
	end
	hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", function(_, token)
		local plate = C_NamePlate.GetNamePlateForUnit(token)
		if plate and plate.UnitFrame then
			Style(plate.UnitFrame)
		end
	end)
	-- Blizzard resets a unit frame's alpha here; nameplates never fade for range, so it always sets 1.
	hooksecurefunc("CompactUnitFrame_UpdateCenterStatusIcon", function(frame)
		if edges[frame] then
			Dim(frame)
		end
	end)
	ns.On("PLAYER_TARGET_CHANGED", function()
		ForEachPlate(Dim)
	end)
	ns.On("PLAYER_FOCUS_CHANGED", function()
		ForEachPlate(Dim)
	end)
	ForEachPlate(Style)
end)
