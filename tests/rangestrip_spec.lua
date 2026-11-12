-- Hunter range strip (UI/RangeStrip.lua): the band from the game's own swing checks, docked on the shown timer,
-- with the 8-yard check only while both swing checks fail and a ticker only while the strip shows that answer.
local function Load(class)
	local features, initializers, handlers, db = {}, {}, {}, {}
	local changed

	local textures, fontStrings, points = {}, {}, {}
	local strip = { shown = false, scripts = {}, scale = 1, width = 240, points = points }
	function strip.SetFrameStrata() end
	function strip.SetFrameLevel() end
	function strip.SetHeight() end
	function strip.SetScale(_, scale)
		strip.scale = scale
	end
	function strip.Show()
		strip.shown = true
	end
	function strip.Hide()
		strip.shown = false
	end
	function strip.ClearAllPoints()
		points = {}
		strip.points = points
	end
	function strip.SetPoint(_, point, relative, relativePoint, x, y)
		points[#points + 1] = { point, relative, relativePoint, x, y }
	end
	function strip.GetWidth()
		return strip.width
	end
	function strip.SetScript(_, script, fn)
		strip.scripts[script] = fn
	end
	function strip.CreateTexture()
		local texture = { shown = false }
		function texture.SetAtlas(_, atlas)
			texture.atlas = atlas
		end
		function texture.SetVertexColor(_, r, g, b)
			texture.colour = { r, g, b }
		end
		function texture.SetPoint(_, point, relative, relativePoint, x, y)
			points[#points + 1] = { point, relative, relativePoint, x, y }
		end
		function texture.ClearAllPoints() end
		function texture.SetAllPoints() end
		function texture.Show()
			texture.shown = true
		end
		function texture.Hide()
			texture.shown = false
		end
		textures[#textures + 1] = texture
		return texture
	end
	function strip.CreateFontString()
		local text = { shown = false, string = "" }
		function text.SetFontObject(_, object)
			text.fontObject = object
		end
		function text.SetJustifyH() end
		function text.SetJustifyV() end
		function text.SetHeight() end
		function text.SetPoint(_, point, relative, relativePoint, x, y)
			points[#points + 1] = { point, relative, relativePoint, x, y }
		end
		function text.ClearAllPoints() end
		function text.SetAllPoints() end
		function text.SetText(_, value)
			text.string = value
		end
		function text.SetTextColor(_, r, g, b)
			text.colour = { r, g, b }
		end
		function text.Show()
			text.shown = true
		end
		function text.Hide()
			text.shown = false
		end
		fontStrings[#fontStrings + 1] = text
		return text
	end

	local function Timer(top, shown, scale)
		local timer = { top = top, shown = shown, scale = scale or 1, scripts = {} }
		function timer.IsShown()
			return timer.shown
		end
		function timer.GetTop()
			return timer.top
		end
		function timer.GetWidth()
			return 240
		end
		function timer.GetEffectiveScale()
			return timer.scale
		end
		function timer.HookScript(_, script, fn)
			timer.scripts[script] = fn
		end
		return timer
	end

	local mainHand, ranged = Timer(300, true), Timer(200, true)
	local tickers = {}
	local enableRangeChecks, interactCalls = 0, 0
	local melee, rangedReach, interact, target = true, false, true, true
	local uiScale = 1

	local function swingReach(swingType)
		if swingType == 0 then
			return melee
		end
		return rangedReach
	end

	local function interactCheck()
		interactCalls = interactCalls + 1
		return interact
	end

	local ns = {
		L = setmetatable({}, {
			__index = function(_, key)
				return key
			end,
		}),
		Feature = function(feature)
			features[feature.key] = feature
		end,
		Init = function(fn)
			initializers[#initializers + 1] = fn
		end,
		On = function(event, fn)
			handlers[event] = fn
		end,
		Active = function(key)
			return db[key]
		end,
		OnSettingChanged = function(_, fn)
			changed = fn
		end,
		Readable = function(value)
			return value
		end,
		core = {
			SafeCall = function(_, fn, ...)
				return fn(...)
			end,
		},
	}

	local env = setmetatable({
		UnitClassBase = function()
			return class
		end,
		UnitCanAttack = function()
			return target
		end,
		Enum = { PlayerSwingType = { MainHand = 0, Ranged = 2 } },
		C_SwingTimer = {
			IsTargetWithinSwingRange = swingReach,
			EnableRangeCheck = function()
				enableRangeChecks = enableRangeChecks + 1
			end,
		},
		CheckInteractDistance = interactCheck,
		C_Timer = {
			NewTicker = function(interval, fn)
				local ticker = { interval = interval, cancelled = false }
				function ticker.Cancel()
					ticker.cancelled = true
				end
				function ticker.Fire()
					fn()
				end
				tickers[#tickers + 1] = ticker
				return ticker
			end,
		},
		SwingTimerMainHandFrame = mainHand,
		SwingTimerRangedFrame = ranged,
		GameFontNormal = "GameFontNormal",
		GameFontHighlightSmall = "GameFontHighlightSmall",
		UIParent = {
			GetEffectiveScale = function()
				return uiScale
			end,
		},
		CreateFrame = function()
			return strip
		end,
	}, { __index = _G })
	setfenv(assert(loadfile("UI/RangeStrip.lua")), env)("TweaksForever", ns)

	return {
		env = env,
		ns = ns,
		features = features,
		initializers = initializers,
		handlers = handlers,
		db = db,
		changed = function()
			changed()
		end,
		strip = strip,
		textures = textures,
		fontStrings = fontStrings,
		mainHand = mainHand,
		ranged = ranged,
		tickers = tickers,
		swingReach = swingReach,
		interactCheck = interactCheck,
		interactCalls = function()
			return interactCalls
		end,
		enableRangeChecks = function()
			return enableRangeChecks
		end,
		setMelee = function(value)
			melee = value
		end,
		setRanged = function(value)
			rangedReach = value
		end,
		setInteract = function(value)
			interact = value
		end,
		setTarget = function(value)
			target = value
		end,
		setUIScale = function(value)
			uiScale = value
		end,
	}
end

-- Every band the data can answer, and no band where a check could not answer.
local hunter = Load("HUNTER")
local Model = hunter.ns.RangeStrip
assert(Model.Band(true, true, nil) == "Melee", "melee reach wins")
assert(Model.Band(true, false, nil) == "Melee", "melee reach alone")
assert(Model.Band(false, true, nil) == "Shoot", "ranged reach")
assert(Model.Band(false, false, true) == "Dead zone", "both out of reach, inside 8 yards")
assert(Model.Band(false, false, false) == "Too far", "both out of reach, beyond 8 yards")
assert(Model.Band(false, false, nil) == nil, "the 8-yard check answered nothing")
assert(Model.Band(nil, true, nil) == "Shoot", "ranged reach decides even when melee could not be checked")
assert(Model.Band(true, nil, nil) == "Melee", "melee reach decides even when ranged could not be checked")
assert(Model.Band(nil, false, nil) == nil, "ranged unknown, so neither dead zone nor too far")
assert(Model.Band(false, nil, nil) == nil, "melee unknown, so neither dead zone nor too far")
assert(Model.Band(nil, nil, nil) == nil, "neither check could answer")

-- A check that raises answers nothing, and never a wrong band.
hunter.env.C_SwingTimer.IsTargetWithinSwingRange = function()
	error("no range check")
end
assert(Model.Reach(0) == nil and Model.Reach(2) == nil, "a raising swing check answers nothing")
hunter.env.CheckInteractDistance = function()
	error("no interact check")
end
assert(Model.Interact() == nil, "a raising interact check answers nothing")

-- The feature is on by default and lives on the Interface page.
local feature = hunter.features.rangeStrip
assert(feature.default == true, "on by default")
assert(feature.category == "Interface")
assert(feature.name == "Hunter range strip")

-- A hunter registers the strip and its events; off, nothing shows.
hunter.initializers[1]()
assert(hunter.handlers.PLAYER_SWING_RANGE_UPDATE, "swing range updates")
assert(hunter.handlers.PLAYER_TARGET_CHANGED, "target changes")
assert(hunter.handlers.PLAYER_EQUIPMENT_CHANGED, "equipment changes")
assert(not hunter.strip.shown, "off at login")
assert(hunter.mainHand.scripts.OnShow and hunter.mainHand.scripts.OnHide and hunter.mainHand.scripts.OnSizeChanged)
assert(hunter.ranged.scripts.OnShow and hunter.ranged.scripts.OnHide and hunter.ranged.scripts.OnSizeChanged)

-- Restore a live swing check, then turn the feature on: the higher of the two shown timers carries the strip.
hunter.env.C_SwingTimer.IsTargetWithinSwingRange = hunter.swingReach
hunter.env.CheckInteractDistance = hunter.interactCheck
hunter.db.rangeStrip = true
hunter.changed()
assert(hunter.strip.shown, "on, the strip shows")
assert(hunter.strip.points[1][2] == hunter.mainHand, "docked on the timer higher on screen")
assert(hunter.fontStrings[1].string == "Melee", "the band label")
-- The game's own font objects carry a font every locale has glyphs for, and their own shadow.
assert(hunter.fontStrings[1].fontObject == "GameFontNormal", "the band label in the game's normal font")
for index = 2, 4 do
	assert(hunter.fontStrings[index].fontObject == "GameFontHighlightSmall", "segment names in the game's small font")
end
assert(hunter.textures[2].shown, "the Melee segment is lit")
assert(not hunter.textures[5].shown and not hunter.textures[8].shown, "only the Melee segment")
assert(hunter.interactCalls() == 0, "no 8-yard check while a swing reaches")

-- The other shown timer is higher now.
hunter.mainHand.top, hunter.ranged.top = 100, 400
hunter.changed()
assert(hunter.strip.points[1][2] == hunter.ranged, "the higher timer takes the strip")

-- Ranged reach only: Shoot, and the green segment.
hunter.mainHand.top = 400
hunter.setMelee(false)
hunter.setRanged(true)
hunter.changed()
assert(hunter.fontStrings[1].string == "Shoot")
assert(hunter.textures[8].shown and not hunter.textures[2].shown, "the Shoot segment is lit")
assert(#hunter.tickers == 0, "no ticker while a swing reaches")

-- Neither swing reaches: the 8-yard check decides, and a ticker watches the gap it cannot see.
hunter.setRanged(false)
hunter.changed()
assert(hunter.fontStrings[1].string == "Dead zone")
assert(hunter.textures[5].shown and not hunter.textures[2].shown and not hunter.textures[8].shown)
assert(#hunter.tickers == 1 and not hunter.tickers[1].cancelled, "a ticker while both fail")
assert(hunter.tickers[1].interval == 0.2, "every 0.2 s")

-- Walking beyond 8 yards moves to Too far with no new ticker, which the ticker itself catches.
hunter.setInteract(false)
hunter.tickers[1].Fire()
assert(hunter.fontStrings[1].string == "Too far")
assert(not hunter.textures[2].shown and not hunter.textures[5].shown and not hunter.textures[8].shown, "no segment lit")
assert(hunter.fontStrings[1].colour[1] == 0.55, "Too far in grey")
assert(#hunter.tickers == 1, "the same ticker keeps running")

-- A nil answer from the 8-yard check hides the label and every segment rather than claiming Too far.
hunter.env.CheckInteractDistance = function()
	return nil
end
hunter.changed()
assert(not hunter.fontStrings[1].shown, "no label when the check answered nothing")
assert(not hunter.textures[2].shown and not hunter.textures[5].shown and not hunter.textures[8].shown)
hunter.env.CheckInteractDistance = hunter.interactCheck

-- A swing reaches again: the ticker stops.
hunter.setRanged(true)
hunter.changed()
assert(hunter.tickers[1].cancelled, "the ticker stops once a swing reaches")
assert(hunter.fontStrings[1].string == "Shoot")

-- No attackable target hides the strip and stops the ticker.
hunter.setMelee(false)
hunter.setRanged(false)
hunter.changed()
assert(#hunter.tickers == 2 and not hunter.tickers[2].cancelled, "a fresh ticker")
hunter.setTarget(false)
hunter.changed()
assert(not hunter.strip.shown, "no strip without a target")
assert(hunter.tickers[2].cancelled, "no ticker without a target")

-- No shown timer hides it too.
hunter.setTarget(true)
hunter.mainHand.shown, hunter.ranged.shown = false, false
hunter.changed()
assert(not hunter.strip.shown, "no strip without a shown timer")
assert(hunter.tickers[2].cancelled, "still no ticker")

-- The strip takes its timer's scale, relative to its own parent.
hunter.ranged.shown, hunter.ranged.scale = true, 0.7
hunter.setUIScale(0.5)
hunter.changed()
assert(math.abs(hunter.strip.scale - 1.4) < 1e-9, "effective scale matched")

-- Blizzard's own timer keeps ownership of its range check.
assert(hunter.enableRangeChecks() == 0, "never calls EnableRangeCheck")

-- Another class registers nothing: no events, no frames.
local priest = Load("PRIEST")
assert(priest.features.rangeStrip, "the setting still exists for every class")
priest.initializers[1]()
assert(next(priest.handlers) == nil, "no events for another class")
assert(#priest.textures == 0 and #priest.fontStrings == 0, "no strip for another class")

print("rangestrip: ok")
