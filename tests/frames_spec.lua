local features, initializers = {}, {}
local ns = {
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
}
local env = setmetatable({
	Enum = { EditModeLayoutType = { Preset = 0, Account = 1, Character = 2 } },
}, { __index = _G })
setfenv(assert(loadfile("Frames.lua")), env)("TweaksForever", ns)
local Model = ns.Frames
assert(features.moveWindows.default and #initializers == 1)
assert(features.moveWindows.conflicts[1].addon == "BlizzMove")
assert(features.moveWindows.conflicts[2].addon == "MoveAnything")

local account = { layoutName = "Solo", layoutType = 1 }
local character = { layoutName = "Solo", layoutType = 2 }
local first = Model.LayoutKey(account, 3, "Player-A")
assert(first == Model.LayoutKey(account, 4, "Player-B"), "account layouts survive index shifts and characters")
local own = Model.LayoutKey(character, 4, "Player-A")
local other = Model.LayoutKey(character, 4, "Player-B")
assert(own ~= other and own ~= first, "character layouts must be isolated")
assert(Model.LayoutKey({ layoutName = "Modern", layoutType = 0 }, 1, "A") == "preset:1")
assert(Model.LayoutKey({ layoutName = "Localized", layoutType = 0 }, 1, "B") == "preset:1")
assert(not Model.LayoutKey(nil))

local db = {}
assert(not Model.Layout(db, first) and not db.windowLayouts, "reads must not initialize saved data")
assert(not Model.Layout(db, nil, true))
Model.Layout(db, first, true).CharacterFrame = { x = 0.4, y = 0.6, scale = 1.25 }
Model.Layout(db, own, true).CharacterFrame = { x = 0.8, y = 0.2, scale = 0.75 }
Model.Layout(db, other, true).CharacterFrame = { x = 0.1, y = 0.9, scale = 1 }
local second = Model.LayoutKey({ layoutName = "Raid", layoutType = 1 }, 4, "Player-A")
assert(not next(Model.Layout(db, second, true)), "new layouts start with Blizzard defaults")
assert(Model.Layout(db, first).CharacterFrame.scale == 1.25)
local renamed = Model.LayoutKey({ layoutName = "Renamed", layoutType = 1 }, 3, "Player-A")
Model.Rename(db, first, renamed)
assert(not Model.Layout(db, first) and Model.Layout(db, renamed).CharacterFrame.x == 0.4)
Model.Rename(db, renamed, renamed)
assert(Model.Layout(db, renamed).CharacterFrame)
Model.Prune(db, { renamed, own }, "Player-A")
assert(not Model.Layout(db, second), "deleted layouts cannot leak settings to a newly created namesake")
assert(Model.Layout(db, other).CharacterFrame, "pruning cannot erase another character's layout")
Model.Layout(db, renamed).CharacterFrame = nil
assert(not Model.Layout(db, renamed).CharacterFrame)
assert(Model.Layout(db, own).CharacterFrame.scale == 0.75, "reset affects only the selected layout")

local function near(actual, expected)
	assert(math.abs(actual - expected) < 0.00001, tostring(actual) .. " ~= " .. tostring(expected))
end

-- GetCenter is in frame coordinates. Saved centers are fractions of the UIParent's visible area.
local position = Model.Serialize(640, 360, 0.8, 0.64, 1600, 900, 1.25)
near(position.x, 0.5)
near(position.y, 0.5)
assert(position.scale == 1.25)
local x, y = Model.Restore(position, 0.8, 0.64, 1600, 900)
near(x, 640)
near(y, 360)
-- Changing resolution, UI scale, parent scale or window scale preserves the screen-relative center.
x, y = Model.Restore(position, 1.5, 0.75, 2560, 1440)
near(x, 640)
near(y, 360)
local roundTrip = Model.Serialize(x, y, 1.5, 0.75, 2560, 1440, 1.5)
near(roundTrip.x, position.x)
near(roundTrip.y, position.y)
local inset = Model.Serialize(740, 460, 0.8, 0.64, 1600, 900, 1, 125, 125)
near(inset.x, 0.5)
near(inset.y, 0.5)
assert(not Model.Serialize(nil, nil, 1, 1, 100, 100, 1))
assert(not Model.Serialize(0, 0, 1, 1, 0, 100, 1))
near(Model.Snap(0.501, 1920, 32), 0.5)
near(Model.Snap(0.52, 1920, 32), (960 + 32) / 1920)
near(Model.Snap(0.48, 1920, 32), (960 - 32) / 1920)

local combat, currentLayout, enabled = true, "A", true
local calls, result = 0, nil
local queue = Model.NewQueue(function()
	return combat
end)
local function apply()
	calls = calls + 1
	result = enabled and currentLayout or "default"
end
queue:Run("panel", apply)
currentLayout = "B"
queue:Run("panel", apply)
queue:Flush()
assert(calls == 0, "combat forbids both moving and restoring")
combat = false
queue:Flush()
assert(calls == 1 and result == "B", "one coalesced application of the current layout")
queue:Flush()
assert(calls == 1, "draining twice must not replay work")
combat = true
queue:Run("panel", apply)
enabled = false
combat = false
queue:Flush()
assert(result == "default", "disabling in combat must queue a restore, not an obsolete move")
combat = true
queue:Run("panel", function()
	error("superseded work")
end)
combat = false
queue:Run("panel", apply)
queue:Flush()
assert(calls == 3, "immediate work cancels stale queued work for the same frame")
print("frames_spec: ok")
