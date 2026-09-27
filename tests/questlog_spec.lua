local init, settings, features = {}, {}, {}
local ns = {
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		init[#init + 1] = fn
	end,
	OnSettingChanged = function(key, fn)
		settings[key] = fn
	end,
	Active = function(key)
		return features[key].default
	end,
}
local log = {
	{ isHeader = true, questID = 0 },
	{ title = "First", questID = 101 },
	{ title = "Cannot abandon", questID = 102 },
	{ title = "Hidden", questID = 103, isHidden = true },
	{ title = "Last", questID = 104 },
}
local selected, target, combat, cvar = 102, nil, false, false
local abandoned = {}
local function Find(id)
	for index, info in ipairs(log) do
		if info.questID == id then
			return index
		end
	end
end
local env = setmetatable({
	InCombatLockdown = function()
		return combat
	end,
	GetCVarBool = function()
		return cvar
	end,
	SetCVar = function(name, value)
		assert(name == "showQuestLevel")
		cvar = value == "1"
	end,
	C_QuestLog = {
		GetNumQuestLogEntries = function()
			return #log
		end,
		GetInfo = function(index)
			return log[index]
		end,
		GetLogIndexForQuestID = Find,
		IsQuestDisabledForSession = function(id)
			return id == 105
		end,
		CanAbandonQuest = function(id)
			return id ~= 102
		end,
		GetSelectedQuest = function()
			return selected
		end,
		SetSelectedQuest = function(id)
			selected = id
		end,
		SetAbandonQuest = function()
			target = selected
		end,
		AbandonQuest = function()
			abandoned[#abandoned + 1] = target
			table.remove(log, assert(Find(target)))
		end,
		GetQuestDifficultyLevel = function(id)
			return id == 101 and 19 or 0
		end,
	},
}, { __index = _G })
assert(loadfile("Locales/enUS.lua"))("TweaksForever", ns)
setfenv(assert(loadfile("QuestLevels.lua")), env)("TweaksForever", ns)
setfenv(assert(loadfile("QuestLog.lua")), env)("TweaksForever", ns)
assert(loadfile("Data/ForeverQuests.lua"))("TweaksForever", ns)
assert(ns.ForeverQuests[92750] and not ns.ForeverQuests[455] and not ns.ForeverQuests[9999999])
assert(ns.QuestTitle(101, "First") == "First")
init[1]()
assert(cvar and ns.QuestTitle(101, "First") == "[19] First")
assert(ns.QuestTitle(101, "[19] First") == "[19] First")
assert(ns.QuestTitle(999, "Unknown") == "Unknown", "never manufacture a level")
features.questLevels.default = false
settings.questLevels()
assert(not cvar)
local model = ns.QuestLog
assert(#model.Entries() == 3, "headers and hidden quests never offered")
local ids = model.Selection({ [101] = true, [102] = true, [103] = true, [104] = true, [999] = true })
assert(table.concat(ids, ",") == "101,104", "only current visible abandonable selections")
combat = true
model.Abandon(ids)
assert(#abandoned == 0, "no changes in combat")
combat = false
model.Abandon(ids)
assert(table.concat(abandoned, ",") == "101,104", "stable IDs survive shrinking log indices")
assert(selected == 102, "previous quest selection restored")
model.Abandon(ids)
assert(#abandoned == 2, "stale confirmed IDs never abandon a different quest")
print("questlog: stable batch selection and native quest levels verified")
