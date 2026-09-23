---@type string, TFNamespace
local _, ns = ...

local KEY = "largerNameplates"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Larger, clearer nameplates",
	tooltip = "Nameplates get a taller health bar in the retail frame, with the full name centred above it and the "
		.. "level, coloured by difficulty, after the name. Your target is outlined and the others fade back while you "
		.. "have one. "
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
local HEALTH, CAST, GAP, NAME_GAP, HEALTH_TEXT = 16, 12, 2, 4, 11
local DIMMED = 0.6

-- Unit frames already hooked. They are pooled, so each is hooked once and reused for many units.
---@type table<NamePlateUnitFrame, true>
local styled = setmetatable({}, { __mode = "k" })

-- Asks the game rather than the frame's cached isTarget: the frame's own PLAYER_TARGET_CHANGED handler may run
-- after this addon's.
---@param frame NamePlateUnitFrame
local function Dim(frame)
	local unit = frame.unit
	local faded = unit and UnitExists("target") and not UnitIsUnit(unit, "target") and not UnitIsUnit(unit, "focus")
	frame:SetAlpha(faded and DIMMED or 1)
end

-- Retail's selection outline, which Blizzard switches off for the Classic style: white round the target, gold round
-- the focus. Asks the game, as Dim does.
---@param frame NamePlateUnitFrame
local function Border(frame)
	local unit = frame.unit
	local target = unit and UnitIsUnit(unit, "target")
	local focus = unit and UnitIsUnit(unit, "focus")
	local border = frame.HealthBarsContainer.healthBar.selectedBorder
	border:SetShown(target or focus)
	if focus and not target then
		border:SetVertexColor(NORMAL_FONT_COLOR:GetRGB())
	else
		border:SetVertexColor(1, 1, 1)
	end
end

-- Retail's own bar art, as its default style lays it out: the cooldown-manager fill inside its bronze-rimmed trough,
-- in place of the Classic style's border.
---@param frame NamePlateUnitFrame
---@param bar NamePlateHealthBar
local function HealthArt(frame, bar)
	bar.barTexture:SetAtlas("UI-HUD-CoolDownManager-Bar")
	local trough = bar.bgTexture
	trough:ClearAllPoints()
	trough:SetAtlas("UI-HUD-CoolDownManager-Bar-BG")
	trough:SetDrawLayer("BACKGROUND")
	trough:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 3)
	trough:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 6, -6)
	local border = bar.selectedBorder
	border:ClearAllPoints()
	border:SetPoint("TOPLEFT", trough, "TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", trough, "BOTTOMRIGHT", -3, 3)
	-- The others fade back as a whole instead, so the darkening would dim them twice.
	bar.deselectedOverlay:SetAlpha(0)
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

	-- Blizzard's plain nameplate font: it notes an outline is harder to read outside the bar. Anchored at one point
	-- so the name is never cut short, however long.
	local name = frame.name
	name:SetFontObject("SystemFont_NamePlate")
	name:SetTextHeight(NamePlateSetupOptions.healthBarFontHeight)
	name:ClearAllPoints()
	name:SetJustifyH("CENTER")
	name:SetPoint("BOTTOM", health, "TOP", 0, NAME_GAP * scale)

	-- Blizzard's level box after the name, which colours the level by difficulty and shows a skull for ??, without
	-- its box.
	local level = frame.PlayerLevelDiffFrame
	level:ClearAllPoints()
	level:SetPoint("LEFT", name, "RIGHT", -4, 0)
	level:SetHeight(name:GetLineHeight())
	level.playerLevelDiffIcon:SetAlpha(0)
	if level.selectedBorder then
		level.selectedBorder:SetAlpha(0)
	end
	-- The Classic style's own level, set into its bar border, would repeat it.
	frame.LevelFrame:SetAlpha(0)

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
	if not styled[frame] then
		styled[frame] = true
		hooksecurefunc(frame, "UpdateAnchors", Layout)
		hooksecurefunc(frame.HealthBarsContainer.healthBar, "UpdateSelectionBorder", function()
			Border(frame)
		end)
	end
	Layout(frame)
end

---@param frame NamePlateUnitFrame
local function Highlight(frame)
	if styled[frame] then
		Border(frame)
		Dim(frame)
	end
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
		if styled[frame] then
			Dim(frame)
		end
	end)
	ns.On("PLAYER_TARGET_CHANGED", function()
		ForEachPlate(Highlight)
	end)
	ns.On("PLAYER_FOCUS_CHANGED", function()
		ForEachPlate(Highlight)
	end)
	ForEachPlate(Style)
end)
