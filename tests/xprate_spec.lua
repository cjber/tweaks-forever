-- XP per hour on the experience bar (UI/XPRate.lua): the rate over the last 15 minutes, the time to level at that
-- pace, and about how many kills or quests that is, added after Blizzard's own experience tooltip.
local features, initializers, handlers, db = {}, {}, {}, {}
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
}
local now, xp, max, combat = 1000, 0, 10000, false
local added, shown, hooked = {}, true, nil
local env = setmetatable({
	GetTime = function()
		return now
	end,
	UnitXP = function()
		return xp
	end,
	UnitXPMax = function()
		return max
	end,
	UnitAffectingCombat = function()
		return combat
	end,
	BreakUpLargeNumbers = function(value)
		return tostring(value)
	end,
	SecondsToTime = function(seconds)
		return seconds .. "s"
	end,
	GameTooltip = {
		IsShown = function()
			return shown
		end,
		AddLine = function(_, text)
			added[#added + 1] = text
		end,
		Show = function() end,
	},
	StatusTrackingBarInfo = { BarsEnum = { Experience = 4 } },
	MainStatusTrackingBarContainer = {
		bars = {
			[4] = {
				HookScript = function(_, script, fn)
					assert(script == "OnEnter")
					hooked = fn
				end,
			},
		},
	},
}, { __index = _G })
setfenv(assert(loadfile("UI/XPRate.lua")), env)("TweaksForever", ns)
local feature = features.xpRate
assert(feature.default == true, "a tooltip line, not an automation")
local named = {}
for _, conflict in ipairs(feature.conflicts) do
	named[conflict.addon or conflict.polestar] = true
end
assert(named.XToLevel and named["qol.xpTracker"])

local Model = ns.XPRate
Model.Start(now, 0, 10000)
assert(Model.Rate(now + 30) == nil, "no rate in the first minute")
-- Two kills of 100 in combat, a quest of 1000, then 50 from exploring out of combat.
combat = true
now = now + 60
Model.Update(now, 100, 10000, true)
Model.Update(now + 10, 200, 10000, true)
Model.CombatEnded(now + 11)
Model.QuestXP(1000)
Model.Update(now + 20, 1200, 10000, false)
Model.Update(now + 200, 1250, 10000, false)
local lines = Model.Lines(now + 240, 1250, 10000)
-- 1250 XP over 300 s since start is 15000 per hour; 8750 left is 2100 s.
assert(lines[1] == "XP per hour: 15000", lines[1])
assert(lines[2] == "Time to level: 2100s", lines[2])
assert(lines[3] == "Kills to level: about 88", "kills average 100: " .. lines[3])
assert(lines[4] == "Quests to level: about 9", "quests average 1000: " .. lines[4])

-- A level up wraps through the old level's top.
Model.Update(now + 300, 100, 12000, true)
assert(
	Model.Lines(now + 300, 100, 12000)[3] == "Kills to level: about 4",
	"a kill of 8850 across the level: kills average 3017"
)

-- Only the last 15 minutes count.
local rate = Model.Rate(now + 2000)
assert(rate and rate < 15000, "older gains drop out of the window")

-- Wired: the experience bar's tooltip gains the lines while on.
db.xpRate = true
initializers[1]()
now, xp = now + 120, 500
handlers.QUEST_TURNED_IN(1, 400, 0)
handlers.PLAYER_XP_UPDATE()
hooked()
assert(#added >= 1 and added[#added]:find("Quests to level"), "lines added after Blizzard's tooltip")
added = {}
db.xpRate = false
hooked()
assert(#added == 0, "switched off")
print("xprate: ok")
