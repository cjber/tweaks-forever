-- Nearest quests first: the client's SortQuestWatches leaves manual watches alone, so the order is worked out here.
local ns = {
	Feature = function() end,
	Init = function() end,
	L = setmetatable({}, {
		__index = function(_, k)
			return k
		end,
	}),
}
setfenv(assert(loadfile("Quests/QuestDistance.lua")), setmetatable({}, { __index = _G }))("TweaksForever", ns)
local Nearest = ns.QuestDistance.Nearest

local function same(a, b)
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

-- Watched in the order the screenshot showed: 531, 276, 28, 573 yards.
local order = Nearest({ 1, 2, 3, 4 }, { [1] = 531 ^ 2, [2] = 276 ^ 2, [3] = 28 ^ 2, [4] = 573 ^ 2 })
assert(order and same(order, { 3, 2, 1, 4 }), "nearest first")
-- Already in order: nothing to move.
assert(Nearest({ 3, 2, 1 }, { [1] = 9, [2] = 4, [3] = 1 }) == nil, "no change when sorted")
-- Quests on another continent go after, in the order they had; ties keep theirs.
order = Nearest({ 5, 1, 6, 2, 7 }, { [1] = 4, [2] = 4, [7] = 1 })
assert(order and same(order, { 7, 1, 2, 5, 6 }), "no distance after, ties stable: " .. table.concat(order or {}, ","))
assert(Nearest({}, {}) == nil)

-- The tracker watcher polls every frame, so it is shown only while the feature is on and the tracker is on screen.
local function Frame()
	local frame = { shown = true, hooks = {} }
	function frame:Hide()
		self.shown = false
	end
	function frame:SetShown(shown)
		self.shown = not not shown
	end
	function frame:IsShown()
		return self.shown
	end
	function frame:SetScript(name, fn)
		self[name] = fn
	end
	function frame:HookScript(name, fn)
		self.hooks[name] = fn
	end
	function frame.SetAllPoints() end
	function frame.SetFillAlpha() end
	function frame.SetBorderAlpha() end
	return frame
end
local active, init, changed, tick = true, nil, nil, nil
local frames, tracker = {}, Frame()
local module = {
	parentContainer = tracker,
	EnumerateActiveBlocks = function() end,
}
local live = {
	Feature = function() end,
	Init = function(fn)
		init = fn
	end,
	Active = function(key)
		assert(key == "questDistance")
		return active
	end,
	OnSettingChanged = function(key, fn)
		assert(key == "questDistance")
		changed = fn
	end,
	L = ns.L,
}
setfenv(
	assert(loadfile("Quests/QuestDistance.lua")),
	setmetatable({
		UIParent = {},
		CreateFrame = function()
			frames[#frames + 1] = Frame()
			return frames[#frames]
		end,
		QuestObjectiveTracker = module,
		CampaignQuestObjectiveTracker = module,
		ObjectiveTrackerFrame = tracker,
		C_Timer = {
			NewTicker = function(_, fn)
				tick = fn
			end,
		},
		C_Map = { GetBestMapForUnit = function() end },
		C_QuestLog = {
			GetNumQuestWatches = function()
				return 0
			end,
		},
		UnitPosition = function() end,
		wipe = function(t)
			for k in pairs(t) do
				t[k] = nil
			end
		end,
		InCombatLockdown = function()
			return false
		end,
	}, { __index = _G })
)("TweaksForever", live)
init()
local watcher = frames[#frames]
assert(watcher.OnUpdate and watcher.shown, "watching while on with the tracker shown")
active = false
changed()
assert(not watcher.shown, "switched off: no polling")
active = true
changed()
assert(watcher.shown, "switched back on")
tracker.shown = false
tracker.hooks.OnHide()
assert(not watcher.shown, "tracker hidden: no polling")
tracker.shown = true
tracker.hooks.OnShow()
assert(watcher.shown, "tracker back")
-- A conflict (Questie's own tracker) turning on sets no setting; the ticker catches it.
active = false
tick()
assert(not watcher.shown, "a conflict stops the polling within a second")
print("questdistance: ok")
