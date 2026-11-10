-- UI/Nameplates.lua marks the target and focus the way Blizzard's own non-Classic nameplate styles do: a white or gold
-- outline and the bar's deselected overlay on every other plate. It never touches a unit frame's alpha, which the
-- engine fades by distance and occlusion on its own.

-- A region or frame with every setter the file calls on it, remembering the state the spec reads back.
local function Region(fields)
	local region = fields or {}
	function region.SetAtlas() end
	function region.SetDrawLayer() end
	function region.ClearAllPoints() end
	function region.SetPoint() end
	function region.SetSize() end
	function region.SetHeight() end
	function region.SetFontObject() end
	function region.SetTextHeight() end
	function region.SetJustifyH() end
	function region.GetLineHeight()
		return 14
	end
	function region:SetVertexColor(red, green, blue)
		self.red, self.green, self.blue = red, green, blue
	end
	function region:SetAlpha(alpha)
		self.alpha = alpha
	end
	function region:SetAlphaFromBoolean(value, whenTrue, whenFalse)
		self.fromBoolean = { value, whenTrue, whenFalse }
	end
	function region:Show()
		self.shown = true
	end
	function region:Hide()
		self.shown = false
	end
	function region:HookScript(event, handler)
		self.handlers = self.handlers or {}
		self.handlers[event] = handler
	end
	return region
end

-- One nameplate unit frame, laid out as Blizzard's BaseNamePlateUnitFrameTemplate holds it. Any alpha the code sets on
-- the unit frame itself lands in `alphas`: the file must never set one.
local function Plate(unit, alphas)
	local bar = {
		barTexture = Region(),
		bgTexture = Region(),
		selectedBorder = Region(),
		deselectedOverlay = Region(),
		Text = Region(),
		RightText = Region(),
		LeftText = Region(),
	}
	local cast = Region({ Spark = Region(), Icon = Region(), Text = Region() })
	local frame = Region({
		unit = unit,
		HealthBarsContainer = Region({ healthBar = bar }),
		CastBarsContainer = Region({ castBar = cast }),
		name = Region(),
		PlayerLevelDiffFrame = Region({ playerLevelDiffIcon = Region(), selectedBorder = Region() }),
		LevelFrame = Region(),
	})
	function frame.IsShowOnlyName(_)
		return false
	end
	function frame.SetAlpha(_, alpha)
		alphas[#alphas + 1] = alpha
	end
	function frame.SetAlphaFromBoolean(_, value, whenTrue, whenFalse)
		alphas[#alphas + 1] = { value, whenTrue, whenFalse }
	end
	return frame
end

-- Loads UI/Nameplates.lua against plates for `units` (false for a frame with no unit), asks `isUnit` for target and
-- focus and `canAccess` whether the answer can be read, then runs the file's initializer. Returns the plates and every
-- alpha the file put on a unit frame.
local function Boot(units, isUnit, canAccess)
	local alphas = {}
	local plates = {}
	local initializer
	local env = setmetatable({
		NamePlateSetupOptions = { verticalScale = 1, healthBarFontHeight = 11 },
		NORMAL_FONT_COLOR = {
			GetRGB = function()
				return 1, 0.82, 0
			end,
		},
		C_NamePlate = {
			GetNamePlates = function()
				return plates
			end,
		},
		C_Timer = {
			After = function(_, fn)
				fn()
			end,
		},
		NamePlateDriverFrame = Region(),
		UnitIsUnit = isUnit,
		UnitExists = function()
			return true
		end,
		canaccessvalue = canAccess or function()
			return true
		end,
		hooksecurefunc = function() end,
		CompactUnitFrame_UpdateCenterStatusIcon = function() end,
	}, { __index = _G })
	local ns = {
		Feature = function(feature)
			env.feature = feature
		end,
		Init = function(fn)
			initializer = fn
		end,
		Active = function()
			return true
		end,
		On = function() end,
	}
	for index = 1, #units do
		plates[index] = { UnitFrame = Plate(units[index] or nil, alphas) }
	end
	setfenv(assert(loadfile("UI/Nameplates.lua")), env)("TweaksForever", ns)
	initializer()
	return { plates = plates, alphas = alphas }
end

local function Bar(env, index)
	return env.plates[index].UnitFrame.HealthBarsContainer.healthBar
end

-- A target, an ordinary enemy and the focus, all in the open.
do
	local env = Boot({ "target", "enemy", "focus" }, function(unit, token)
		return (unit == "target" and token == "target") or (unit == "focus" and token == "focus")
	end)
	local target, enemy, focus = Bar(env, 1), Bar(env, 2), Bar(env, 3)
	assert(#env.alphas == 0, "no unit frame alpha, whatever the target")
	assert(enemy.deselectedOverlay.shown == true, "the enemy's overlay is shown")
	assert(enemy.deselectedOverlay.alpha == 1, "the enemy's bar is darkened")
	assert(target.deselectedOverlay.alpha == 0, "the target's bar is not darkened")
	assert(target.selectedBorder.shown == true and target.selectedBorder.alpha == 1, "the target is outlined")
	assert(
		target.selectedBorder.red == 1 and target.selectedBorder.green == 1 and target.selectedBorder.blue == 1,
		"the target's outline is white"
	)
	assert(focus.deselectedOverlay.alpha == 0, "the focus's bar is not darkened")
	assert(focus.selectedBorder.shown == true and focus.selectedBorder.alpha == 1, "the focus is outlined")
	assert(
		focus.selectedBorder.red == 1 and focus.selectedBorder.green == 0.82 and focus.selectedBorder.blue == 0,
		"the focus's outline is gold"
	)
end

-- With no target, every bar is darkened too, and still no unit frame alpha.
do
	local env = Boot({ "one", "two" }, function()
		return false
	end)
	for index = 1, #env.plates do
		local bar = Bar(env, index)
		assert(bar.deselectedOverlay.shown == true, "every other bar's overlay is shown with no target")
		assert(bar.deselectedOverlay.alpha == 1, "every other bar stays darkened with no target")
		assert(bar.selectedBorder.alpha == 0, "nothing is outlined with no target")
	end
	assert(#env.alphas == 0, "no unit frame alpha with no target")
end

-- In an instance UnitIsUnit answers with a secret boolean: the engine's FromBoolean setters take it as it is.
do
	local secret = {}
	local env = Boot({ "enemy" }, function()
		return secret
	end, function(value)
		return value ~= secret
	end)
	local bar = Bar(env, 1)
	assert(#env.alphas == 0, "secret booleans never reach a unit frame alpha")
	assert(bar.selectedBorder.fromBoolean ~= nil, "the border takes the secret boolean")
	assert(
		bar.selectedBorder.fromBoolean[1] == secret
			and bar.selectedBorder.fromBoolean[2] == 1
			and bar.selectedBorder.fromBoolean[3] == 0,
		"the border is shown on a secret target"
	)
	assert(bar.deselectedOverlay.fromBoolean ~= nil, "the overlay takes the secret boolean")
	assert(
		bar.deselectedOverlay.fromBoolean[1] == secret
			and bar.deselectedOverlay.fromBoolean[2] == 0
			and bar.deselectedOverlay.fromBoolean[3] == 1,
		"the overlay clears on a secret target"
	)
	assert(
		bar.selectedBorder.alpha == nil and bar.deselectedOverlay.alpha == nil,
		"a secret answer sets no plain alpha"
	)
end

-- A refresh before the game hands the frame its unit hides both marks, and still never touches the frame's alpha.
do
	local env = Boot({ false }, function()
		return false
	end)
	local bar = Bar(env, 1)
	assert(bar.selectedBorder.shown == false and bar.deselectedOverlay.shown == false, "no unit, no marks")
	assert(#env.alphas == 0, "no unit, no unit frame alpha")
end

print("nameplates_spec: outline, overlay, both no-target and secret paths passed")
