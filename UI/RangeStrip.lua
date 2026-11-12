---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end
local L = ns.L

local KEY = "rangeStrip"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Hunter range strip",
	tooltip = "For hunters, a strip on top of the game's swing timers that names the range band your target is in: "
		.. "Melee, Dead zone (too close to shoot, too far to strike), Shoot, or Too far. It shows while the swing "
		.. "timers show, with the game's own Interface option and Edit Mode.",
	default = true,
})

-- The four bands, as the English keys behind the text above them. Too far has no lit segment.
local MELEE, DEAD_ZONE, SHOOT, TOO_FAR = "Melee", "Dead zone", "Shoot", "Too far"
local NAMES = {
	[MELEE] = L["Melee"],
	[DEAD_ZONE] = L["Dead zone"],
	[SHOOT] = L["Shoot"],
	[TOO_FAR] = L["Too far"],
}
local BANDS = { MELEE, DEAD_ZONE, SHOOT }
local COLOURS = {
	[MELEE] = { 1, 0.82, 0 },
	[DEAD_ZONE] = { 1, 0.13, 0.13 },
	[SHOOT] = { 0.25, 0.75, 0.25 },
	[TOO_FAR] = { 0.55, 0.55, 0.55 },
}
local UNLIT_R, UNLIT_G, UNLIT_B = 0.5, 0.5, 0.5

-- The strip's shape, from the game's swing timer bars: a 20-high band label above three 13-high segments with
-- 3-wide gaps, and 6 between the strip and the timer below it.
local LABEL_HEIGHT, SEGMENT_HEIGHT, SEGMENT_GAP, DOCK_GAP = 20, 13, 3, 6
local SEGMENT_INSET_X, SEGMENT_INSET_Y = 4, 3
-- The game's own swing timer art, stretched by design as the game stretches its timer bars.
local BACKGROUND_ATLAS, BORDER_ATLAS = "ui-swingtimerbar-background", "ui-swingtimerbar-frame"
local FILL_ATLAS = "UI-HUD-CoolDownManager-Bar"

local TICK_INTERVAL = 0.2

---@class TFRangeStrip
local Model = {}
ns.RangeStrip = Model

-- The band for the two swing checks and the 8-yard (interact distance 3) check between them: melee reach first,
-- then ranged. Both out of reach is dead zone inside 8 yards and too far beyond it. Nil answers mean the check
-- could not be made, so they decide nothing: no band rather than a wrong one.
---@param melee boolean?
---@param ranged boolean?
---@param interact boolean? whether the target is within 8 yards, when both checks failed
---@return string?
function Model.Band(melee, ranged, interact)
	if melee == true then
		return MELEE
	end
	if ranged == true then
		return SHOOT
	end
	if melee == false and ranged == false then
		if interact == true then
			return DEAD_ZONE
		elseif interact == false then
			return TOO_FAR
		end
	end
end

-- Whether the current target is within auto attack range for one swing type. Nil is no answer, never out of range.
---@param swingType Enum.PlayerSwingType
---@return boolean?
function Model.Reach(swingType)
	if not (C_SwingTimer and C_SwingTimer.IsTargetWithinSwingRange) then
		return nil
	end
	local ok, inRange = pcall(C_SwingTimer.IsTargetWithinSwingRange, swingType)
	if not ok then
		return nil
	end
	return ns.Readable(inRange)
end

-- Whether the target is within 8 yards, the point where a shot stops reaching but a strike still does. Nil when the
-- game cannot answer, and a call that raises answers nothing either.
---@return boolean?
function Model.Interact()
	if type(CheckInteractDistance) ~= "function" then
		return nil
	end
	local ok, within = pcall(CheckInteractDistance, "target", 3)
	if not ok then
		return nil
	end
	return ns.Readable(within)
end

ns.Init(function()
	if UnitClassBase("player") ~= "HUNTER" then
		return
	end
	if not (C_SwingTimer and Enum.PlayerSwingType) then
		return
	end

	local timers = {}
	if SwingTimerMainHandFrame then
		timers[#timers + 1] = SwingTimerMainHandFrame
	end
	if SwingTimerRangedFrame then
		timers[#timers + 1] = SwingTimerRangedFrame
	end
	if #timers == 0 then
		return
	end

	-- Our own frame over Blizzard's own timers: theirs is only read and hooked, never written to (WFA-38).
	local strip = CreateFrame("Frame", nil, UIParent)
	strip:SetFrameStrata("MEDIUM")
	strip:SetFrameLevel(10)
	strip:SetHeight(LABEL_HEIGHT + SEGMENT_HEIGHT)
	strip:Hide()

	-- The game's own font objects, as its swing timers use: they carry the font this locale can render, and its
	-- shadow, so no glyph comes out missing.
	local label = strip:CreateFontString(nil, "OVERLAY")
	label:SetFontObject(GameFontNormal)
	label:SetJustifyH("CENTER")
	label:SetJustifyV("MIDDLE")
	label:SetPoint("TOPLEFT", strip, "TOPLEFT", 0, 0)
	label:SetPoint("TOPRIGHT", strip, "TOPRIGHT", 0, 0)
	label:SetHeight(LABEL_HEIGHT)
	label:Hide()

	---@class TFRangeSegment
	---@field band string
	---@field text FontString
	---@field fill Texture
	---@field background Texture
	---@field border Texture
	---@type TFRangeSegment[]
	local segments = {}
	for _, band in ipairs(BANDS) do
		local background = strip:CreateTexture(nil, "BACKGROUND")
		-- art-ok: the game's swing timer bar background, stretched across a segment as the game stretches its bar
		background:SetAtlas(BACKGROUND_ATLAS)
		local fill = strip:CreateTexture(nil, "ARTWORK")
		-- art-ok: a bar fill stretched across its segment, as the game draws the bar
		fill:SetAtlas(FILL_ATLAS)
		fill:Hide()
		local border = strip:CreateTexture(nil, "OVERLAY")
		-- art-ok: the game's swing timer bar border, stretched across a segment as the game stretches its bar
		border:SetAtlas(BORDER_ATLAS)
		local text = strip:CreateFontString(nil, "OVERLAY")
		text:SetFontObject(GameFontHighlightSmall)
		text:SetJustifyH("CENTER")
		text:SetJustifyV("MIDDLE")
		text:SetText(NAMES[band])
		text:SetTextColor(UNLIT_R, UNLIT_G, UNLIT_B)
		segments[#segments + 1] = { band = band, background = background, fill = fill, border = border, text = text }
	end

	-- Three equal segments across the timer's width, each with its fill inset 4 x 3.
	local function Layout()
		local width = strip:GetWidth()
		if not width or width <= 0 then
			return
		end
		local segmentWidth = (width - 2 * SEGMENT_GAP) / 3
		for index, segment in ipairs(segments) do
			local left = (index - 1) * (segmentWidth + SEGMENT_GAP)
			for _, texture in ipairs({ segment.background, segment.border }) do
				texture:ClearAllPoints()
				texture:SetPoint("TOPLEFT", strip, "TOPLEFT", left, -LABEL_HEIGHT)
				texture:SetPoint("BOTTOMRIGHT", strip, "BOTTOMLEFT", left + segmentWidth, 0)
			end
			segment.fill:ClearAllPoints()
			segment.fill:SetPoint("TOPLEFT", segment.background, "TOPLEFT", SEGMENT_INSET_X, -SEGMENT_INSET_Y)
			segment.fill:SetPoint("BOTTOMRIGHT", segment.background, "BOTTOMRIGHT", -SEGMENT_INSET_X, SEGMENT_INSET_Y)
			segment.text:ClearAllPoints()
			segment.text:SetAllPoints(segment.background)
		end
	end

	-- The band named above the strip, and its segment lit: white when lit, grey otherwise, and no segment at all
	-- for Too far or when the game gave no answer.
	---@param band string?
	local function Apply(band)
		local colour = band and COLOURS[band]
		if not colour then
			label:Hide()
		else
			label:SetText(NAMES[band])
			label:SetTextColor(colour[1], colour[2], colour[3])
			label:Show()
		end
		for _, segment in ipairs(segments) do
			if colour and segment.band == band then
				segment.fill:SetVertexColor(colour[1], colour[2], colour[3])
				segment.fill:Show()
				segment.text:SetTextColor(1, 1, 1)
			else
				segment.fill:Hide()
				segment.text:SetTextColor(UNLIT_R, UNLIT_G, UNLIT_B)
			end
		end
	end

	-- The shown timer higher on screen, which the strip sits on top of.
	local function ShownTimer()
		local highest
		for _, timer in ipairs(timers) do
			if timer:IsShown() then
				if not highest or (timer:GetTop() or 0) > (highest:GetTop() or 0) then
					highest = timer
				end
			end
		end
		return highest
	end

	local docked
	local ticker
	local Update

	local function StopTicker()
		if ticker then
			ticker:Cancel()
			ticker = nil
		end
	end

	local function StartTicker()
		if ticker then
			return
		end
		ticker = C_Timer.NewTicker(TICK_INTERVAL, function()
			ns.core.SafeCall("range strip", Update)
		end)
	end

	local function Hide()
		strip:Hide()
		docked = nil
		StopTicker()
	end

	-- The band, plus the two swing answers the ticker follows.
	local function ReadBand()
		local melee = Model.Reach(Enum.PlayerSwingType.MainHand)
		local rangedReach = Model.Reach(Enum.PlayerSwingType.Ranged)
		local interact
		if melee == false and rangedReach == false then
			interact = Model.Interact()
		end
		return Model.Band(melee, rangedReach, interact), melee, rangedReach
	end

	function Update()
		if not ns.Active(KEY) or not ns.Readable(UnitCanAttack("player", "target")) then
			Hide()
			return
		end
		local timer = ShownTimer()
		if not timer then
			Hide()
			return
		end
		if docked ~= timer then
			docked = timer
			strip:ClearAllPoints()
			strip:SetPoint("BOTTOMLEFT", timer, "TOPLEFT", 0, DOCK_GAP)
			strip:SetPoint("BOTTOMRIGHT", timer, "TOPRIGHT", 0, DOCK_GAP)
		end
		-- The timer's own scale, relative to the strip's parent.
		local parentScale = UIParent:GetEffectiveScale()
		if parentScale and parentScale > 0 then
			strip:SetScale(timer:GetEffectiveScale() / parentScale)
		end
		local band, melee, rangedReach = ReadBand()
		Apply(band)
		strip:Show()
		Layout()
		-- No swing event fires while both checks fail, so the ticker catches the step from dead zone to too far.
		if melee == false and rangedReach == false then
			StartTicker()
		else
			StopTicker()
		end
	end

	strip:SetScript("OnSizeChanged", Layout)

	for _, timer in ipairs(timers) do
		timer:HookScript("OnShow", Update)
		timer:HookScript("OnHide", Update)
		timer:HookScript("OnSizeChanged", Update)
	end

	Update()
	ns.OnSettingChanged(KEY, Update)
	ns.On("PLAYER_SWING_RANGE_UPDATE", Update)
	ns.On("PLAYER_TARGET_CHANGED", Update)
	ns.On("PLAYER_EQUIPMENT_CHANGED", Update)
end)
