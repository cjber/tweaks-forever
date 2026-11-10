-- Quest XP on the experience bar (UI/QuestXPBar.lua): the XP of the quests ready to hand in from the current fill,
-- then the rest of the log fainter, clamped at the end of the bar, and both totals in the bar's tooltip.
local features, initializers, handlers, db = {}, {}, {}, {}
local changed
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
	Usable = function()
		return true
	end,
	core = {
		SafeCall = function(_, fn, ...)
			return fn(...)
		end,
	},
}

-- A quest log with a header, a quest worth no XP and three rewarded quests, two of them ready to hand in.
local log = {
	{ isHeader = true, questID = 0 },
	{ questID = 101 },
	{ questID = 102 },
	{ questID = 103 },
	{ questID = 104 },
}
local rewards = { [101] = 1200, [102] = 0, [103] = 300, [104] = 500 }
local complete = { [101] = true, [103] = false, [104] = true }
local level, xp, max, maxLevel, combat, tooltipShown = 20, 4000, 10000, 60, false, true

-- Our own frame and textures, so the spec can tell shown from hidden and read the segments' widths.
local overlay = { shown = false, textures = {} }
function overlay.SetScript(_, script, fn)
	overlay[script] = fn
end
function overlay.CreateTexture()
	local texture = { shown = false }
	function texture.SetAtlas() end
	function texture.SetDesaturated() end
	function texture.SetVertexColor() end
	function texture.ClearAllPoints() end
	function texture.SetPoint() end
	function texture.SetWidth(_, width)
		texture.width = width
	end
	function texture.Show()
		texture.shown = true
	end
	function texture.Hide()
		texture.shown = false
	end
	overlay.textures[#overlay.textures + 1] = texture
	return texture
end
function overlay.SetFrameStrata() end
function overlay.SetFrameLevel() end
function overlay.ClearAllPoints() end
function overlay.SetAllPoints() end
function overlay.GetWidth()
	return 1000
end
function overlay.Show()
	overlay.shown = true
end
function overlay.Hide()
	overlay.shown = false
end

local cursorBar = { scripts = {}, StatusBar = {} }
function cursorBar.IsVisible()
	return true
end
function cursorBar.IsProtected()
	return false
end
function cursorBar.GetFrameLevel()
	return 5
end
function cursorBar.HookScript(_, script, fn)
	cursorBar.scripts[script] = fn
end

local added = {}
local env = setmetatable({
	C_QuestLog = {
		GetNumQuestLogEntries = function()
			return #log
		end,
		GetInfo = function(index)
			return log[index]
		end,
		IsComplete = function(id)
			return complete[id] == true
		end,
	},
	GetQuestLogRewardXP = function(id)
		return rewards[id] or 0
	end,
	UnitLevel = function()
		return level
	end,
	UnitXP = function()
		return xp
	end,
	UnitXPMax = function()
		return max
	end,
	GetMaxLevelForPlayerExpansion = function()
		return maxLevel
	end,
	InCombatLockdown = function()
		return combat
	end,
	BreakUpLargeNumbers = function(value)
		return tostring(value)
	end,
	GameTooltip = {
		IsShown = function()
			return tooltipShown
		end,
		GetOwner = function()
			return "UIParent"
		end,
		IsForbidden = function()
			return false
		end,
		AddLine = function(_, text)
			added[#added + 1] = text
		end,
		Show = function() end,
	},
	UIParent = "UIParent",
	hooksecurefunc = function() end,
	C_Timer = {
		After = function(_, fn)
			fn()
		end,
	},
	CreateFrame = function()
		return overlay
	end,
	StatusTrackingBarInfo = { BarsEnum = { Experience = 4 } },
	MainStatusTrackingBarContainer = { bars = { [4] = cursorBar } },
	SecondaryStatusTrackingBarContainer = nil,
}, { __index = _G })
setfenv(assert(loadfile("UI/QuestXPBar.lua")), env)("TweaksForever", ns)

local feature = features.questXPBar
assert(feature.default == false, "off by default")
assert(feature.category == "Interface")
assert(#feature.conflicts == 1 and feature.conflicts[1].addon == "Dominos_Progress", "steps aside for Dominos' XP bar")

local Model = ns.QuestXPBar
-- Completed and pending quests add up apart, and a quest with no reward adds nothing.
local completed, pending = Model.Totals({
	{ xp = 1200, complete = true },
	{ xp = 300, complete = false },
	{ xp = 0, complete = true },
})
assert(completed == 1200 and pending == 300)
completed, pending = Model.Read()
assert(completed == 1700, "the two ready hand-ins: " .. completed)
assert(pending == 300, "the rest of the log, not the no-XP quest: " .. pending)

-- The segments start at the current fill and stop at the bar's end.
local current, completedEnd, allEnd = Model.Segments(9000, 10000, 2000, 3000)
assert(current == 0.9 and completedEnd == 1 and allEnd == 1, "clamped at the bar end")
current, completedEnd, allEnd = Model.Segments(1000, 10000, 2000, 3000)
assert(math.abs(current - 0.1) < 1e-9, "the current fill")
assert(math.abs(completedEnd - 0.3) < 1e-9, "the completed segment follows it")
assert(math.abs(allEnd - 0.6) < 1e-9, "the pending segment follows that")

-- A whole bar and more reaches the next level; the overflow is in the tooltip, not on the bar.
local reached, percent = Model.Reach(1, 0, 500, 60)
assert(reached == 2 and percent == 11, "400 to level 2, then 100 of its 900")
reached, percent = Model.Reach(30, 0, 10000000, 60)
assert(reached == 60 and percent == 100, "the cap")

-- Nothing shows at the level cap or while the bar is hidden.
assert(Model.Hidden(60, 60, true), "at max level")
assert(Model.Hidden(59, 60, false), "bar hidden")
assert(not Model.Hidden(59, 60, true))

-- Off, the overlay stays hidden; on, it shows and the bar's tooltip gains both totals.
initializers[1]()
assert(not overlay.shown, "off at login")
db.questXPBar = true
changed()
assert(overlay.shown, "on, the bar is shaded")
assert(overlay.textures[1].shown and overlay.textures[2].shown, "both segments")
assert(math.abs(overlay.textures[1].width - 170) < 1e-6, "completed: 1700 of 10000")
assert(math.abs(overlay.textures[2].width - 30) < 1e-6, "pending: 300 of 10000")
assert(cursorBar.scripts.OnEnter, "the bar's tooltip hook is registered")
cursorBar.scripts.OnEnter()
assert(added[1] == "Completed quests: 1700 XP", tostring(added[1]))
assert(added[2] == "All quests in log: 2000 XP (reaches level 20, 26%)", tostring(added[2]))

-- A quest log update redraws: the last quest becomes a hand-in, and its segment joins the completed one.
rewards[103], complete[103] = 800, true
handlers.QUEST_LOG_UPDATE()
assert(math.abs(overlay.textures[1].width - 250) < 1e-6, "completed: 2500 of 10000")
assert(not overlay.textures[2].shown, "nothing left pending")
rewards[103], complete[103] = 300, false

-- At the level cap everything goes, including the tooltip lines.
level = 60
changed()
assert(not overlay.shown, "hidden at max level")
added = {}
cursorBar.scripts.OnEnter()
assert(#added == 0, "no lines at max level")
print("questxpbar: ok")
