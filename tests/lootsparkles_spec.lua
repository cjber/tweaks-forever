local features, events, values, writes, timers = {}, {}, {}, {}, {}
local db, changed, initialize, combat, conflict = {}, nil, nil, false, false
local ns = {
	db = db,
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		initialize = fn
	end,
	On = function(event, fn)
		events[event] = fn
	end,
	OnSettingChanged = function(_, fn)
		changed = fn
	end,
	Active = function(key)
		return db[key] and not conflict
	end,
	ConflictOf = function()
		return conflict and "Forever Loot Sparkles" or nil
	end,
}
local env = setmetatable({
	InCombatLockdown = function()
		return combat
	end,
	GetCVar = function(cvar)
		return values[cvar]
	end,
	SetCVar = function(cvar, value)
		assert(not combat, "graphics changes must wait until combat ends")
		values[cvar] = value
		writes[#writes + 1] = cvar
		if events.CVAR_UPDATE then
			events.CVAR_UPDATE(cvar)
		end
	end,
	C_Timer = {
		NewTimer = function(delay, fn)
			local timer = { delay = delay, run = fn }
			function timer:Cancel()
				self.cancelled = true
			end
			timers[#timers + 1] = timer
			return timer
		end,
	},
}, { __index = _G })
local original = {
	outlineModeShowLootEffectWhenDisabled = "0",
	graphicsOutlineMode = "2",
	OutlineEngineMode = "1",
	raidGraphicsOutlineMode = "1",
	RAIDOutlineEngineMode = "2",
}
for key, value in pairs(original) do
	values[key] = value
end
setfenv(assert(loadfile("UI/LootSparkles.lua")), env)("TweaksForever", ns)
assert(features.lootSparkles.default == false)
assert(features.lootSparkles.conflicts[1].addon == "ForeverLootSparkles")
initialize()
assert(#writes == 0 and #timers == 0, "default off leaves graphics alone")

db.lootSparkles = true
changed()
assert(#writes == 5 and #timers == 1, "own writes do not schedule recursive updates")
for key, value in pairs(original) do
	assert(db.lootSparklesSaved[key] == value)
	assert(values[key] == (key == "outlineModeShowLootEffectWhenDisabled" and "1" or "0"))
end
-- Presets can update several CVars together; only the last scheduled callback should run.
values.graphicsOutlineMode = "2"
events.CVAR_UPDATE("GRAPHICSQUALITY")
local previous = timers[#timers]
events.CVAR_UPDATE("graphicsOutlineMode")
assert(previous.cancelled)
timers[#timers].run()
assert(values.graphicsOutlineMode == "0")
assert(db.lootSparklesSaved.graphicsOutlineMode == "2")

combat = true
values.RAIDOutlineEngineMode = "2"
events.CVAR_UPDATE("raidgraphicsquality")
timers[#timers].run()
assert(values.RAIDOutlineEngineMode == "2")
combat = false
events.PLAYER_REGEN_ENABLED()
assert(values.RAIDOutlineEngineMode == "0")

combat = true
db.lootSparkles = false
changed()
assert(db.lootSparklesSaved)
combat = false
events.PLAYER_REGEN_ENABLED()
for key, value in pairs(original) do
	assert(values[key] == value, "restore each player's own value")
end
assert(db.lootSparklesSaved == nil)
local before = #writes
events.CVAR_UPDATE("graphicsQuality")
assert(#writes == before)

-- A reload reuses persisted originals rather than capturing the already forced values.
db.lootSparkles = true
db.lootSparklesSaved = { graphicsOutlineMode = "1" }
initialize()
assert(db.lootSparklesSaved.graphicsOutlineMode == "1")
conflict = true
before = #writes
changed()
assert(#writes == before, "never contend with the companion addon")
conflict = false
db.lootSparkles = false
values.OutlineEngineMode = nil
changed()
assert(values.graphicsOutlineMode == "1")
assert(db.lootSparklesSaved == nil, "missing CVars are left alone")
print("lootsparkles: ok")
