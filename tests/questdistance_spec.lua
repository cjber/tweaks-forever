-- Nearest quests first, driven the way the client drives it: the player moves, the 1 s ticker fires, and the tracker's
-- watch order is what is checked. The client's SortQuestWatches leaves manual watches alone, so the order is the
-- feature's own work.
local ns = {
	Feature = function() end,
	L = setmetatable({}, {
		__index = function(_, k)
			return k
		end,
	}),
}

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

-- A stand-in client as Forever was measured to behave (#80): every watch is manual, AddQuestWatch takes a quest and
-- puts it first, and un-watching the super-tracked quest drops the super-tracking. Quests sit along a line at the
-- yards given in `at`; one missing from `at` is on another continent. `world.x`/`world.y` is the player.
---@param watched integer[] the tracker's order
---@param at table<integer, number>
local function Load(watched, at)
	local world = {
		watches = { unpack(watched) },
		at = at,
		x = 0,
		y = 0,
		super = 0,
		combat = false,
		active = true,
		tracker = Frame(),
		moves = 0, -- watches re-added
		areaChecks = 0,
	}
	local frames = {}
	local module = { parentContainer = world.tracker, EnumerateActiveBlocks = function() end }
	local function IndexOf(id)
		for index, watch in ipairs(world.watches) do
			if watch == id then
				return index
			end
		end
	end
	local init
	ns.Init = function(fn)
		init = fn
	end
	ns.Active = function(key)
		assert(key == "questDistance")
		return world.active
	end
	ns.OnSettingChanged = function(key, fn)
		assert(key == "questDistance")
		world.changed = fn
	end
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
			ObjectiveTrackerFrame = world.tracker,
			C_Timer = {
				NewTicker = function(seconds, fn)
					assert(seconds == 1)
					world.tick = fn
				end,
			},
			C_Map = {
				GetBestMapForUnit = function()
					world.areaChecks = world.areaChecks + 1
				end,
			},
			C_QuestLog = {
				GetNumQuestWatches = function()
					return #world.watches
				end,
				GetQuestIDForQuestWatchIndex = function(index)
					return world.watches[index]
				end,
				GetDistanceSqToQuest = function(id)
					local x = world.at[id]
					if x and world.x then
						return (x - world.x) ^ 2 + world.y ^ 2, true
					end
					return 0, false
				end,
				RemoveQuestWatch = function(id)
					local index = IndexOf(id)
					if index then
						table.remove(world.watches, index)
						if world.super == id then
							world.super = 0
						end
					end
				end,
				AddQuestWatch = function(id)
					if not IndexOf(id) then
						table.insert(world.watches, 1, id)
						world.moves = world.moves + 1
					end
				end,
			},
			C_SuperTrack = {
				GetSuperTrackedQuestID = function()
					return world.super
				end,
				SetSuperTrackedQuestID = function(id)
					world.super = id
				end,
			},
			-- nil inside an instance, where the client keeps the position secret.
			UnitPosition = function()
				return world.y, world.x
			end,
			wipe = function(t)
				for k in pairs(t) do
					t[k] = nil
				end
			end,
			InCombatLockdown = function()
				return world.combat
			end,
		}, { __index = _G })
	)("TweaksForever", ns)
	init()
	world.watcher = frames[#frames]
	return world
end

---@param world table
---@param expected integer[]
---@param message string
local function Order(world, expected, message)
	local got = table.concat(world.watches, ",")
	assert(got == table.concat(expected, ","), message .. ": " .. got)
end

-- Watched in the order the screenshot showed (531, 276, 28, 573 yards): the first tick sorts, the arrow stays put.
local world = Load({ 1, 2, 3, 4 }, { 531, 276, 28, 573 })
world.super = 1
world.tick()
Order(world, { 3, 2, 1, 4 }, "nearest first")
assert(world.super == 1, "the super-tracked quest keeps its arrow")

-- Standing still, or already in order: nothing is re-watched, so the tracker does not flicker.
local moves = world.moves
world.tick()
assert(world.moves == moves, "no movement, no re-watch")
world.x = 100
world.tick()
Order(world, { 3, 2, 1, 4 }, "moved, order still right")
assert(world.moves == moves, "already in order: nothing re-watched")

-- The list re-sorts after 25 yards from where it was last sorted, however many ticks that takes.
world = Load({ 1, 2 }, { 10, 30 })
world.tick()
Order(world, { 1, 2 }, "sorted where you stand")
world.x = 13
world.tick()
world.x = 25
world.tick()
Order(world, { 1, 2 }, "25 yards is not yet enough to re-sort")
world.x = 26
world.tick()
Order(world, { 2, 1 }, "over 25 yards from the last sort, in small steps")

-- Never in combat, when the tracker's item buttons can't be moved; the sort it missed runs once combat ends.
world = Load({ 1, 2 }, { 10, 90 })
world.tick()
world.combat = true
world.x = 100
world.tick()
Order(world, { 1, 2 }, "no re-sort in combat")
world.combat = false
world.tick()
Order(world, { 2, 1 }, "sorted on leaving combat, without moving again")

-- Quests on another continent go after, in the order they had; ties keep theirs.
world = Load({ 5, 1, 6, 2, 7 }, { [1] = 2, [2] = -2, [7] = 1 })
world.super = 6
world.tick()
Order(world, { 7, 1, 2, 5, 6 }, "no distance after, ties stable")
assert(world.super == 6 and world.moves == 3, "quests with no distance are left alone")

-- No position (inside an instance) and nothing watched: nothing to do.
world = Load({ 2, 1 }, { 10, 20 })
world.x, world.y = nil, nil
world.tick()
Order(world, { 2, 1 }, "no position, no sort")
assert(world.areaChecks == 0, "no position, no area check")
Load({}, {}).tick()

-- Quest areas are checked against your position every 5 yards.
world = Load({ 1 }, { 10 })
world.tick()
assert(world.areaChecks == 1, "areas checked on the first tick")
world.x = 5
world.tick()
assert(world.areaChecks == 1, "5 yards is not yet enough to re-check")
world.x = 6
world.tick()
assert(world.areaChecks == 2, "re-checked after more than 5 yards")

-- Switched off (or Questie's tracker taking over) the order is left alone; back on, it sorts without waiting for you
-- to move.
world = Load({ 1, 2 }, { 10, 90 })
world.tick()
world.active = false
world.tick()
world.watches = { 2, 1 }
world.x = 100
world.tick()
Order(world, { 2, 1 }, "off: the order is the player's")
world.x = 0
world.active = true
world.tick()
Order(world, { 1, 2 }, "back on: sorted at once")

-- The tracker watcher polls every frame, so it is shown only while the feature is on and the tracker is on screen.
local watcher, tracker = world.watcher, world.tracker
assert(watcher.OnUpdate and watcher.shown, "watching while on with the tracker shown")
world.active = false
world.changed()
assert(not watcher.shown, "switched off: no polling")
world.active = true
world.changed()
assert(watcher.shown, "switched back on")
tracker.shown = false
tracker.hooks.OnHide()
assert(not watcher.shown, "tracker hidden: no polling")
tracker.shown = true
tracker.hooks.OnShow()
assert(watcher.shown, "tracker back")
-- A conflict (Questie's own tracker) turning on sets no setting; the ticker catches it.
world.active = false
world.tick()
assert(not watcher.shown, "a conflict stops the polling within a second")
print("questdistance: ok")
