-- Quest item and target keys (Quests/QuestButtons.lua): two secure buttons of our own, bound by the player, set
-- just before each press out of combat: the nearest quest's item, and a creature the nearest unfinished quest
-- still needs, a different one each press.
local features, initializers = {}, {}
local db = { questButtons = true }
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
	Active = function(key)
		return db[key]
	end,
}
-- Quest 1 (far) has an item; quest 2 (near) has an item and wolves and bears to kill; quest 3 (nearest) is done.
local log = {
	{ questID = 1, title = "Far" },
	{ questID = 2, title = "Near" },
	{ questID = 3, title = "Done" },
	{ questID = 4, title = "Elsewhere" },
}
local distances = { [1] = 900, [2] = 100, [3] = 25 }
local items = { [1] = "|cffffffff|Hitem:111::::|h[Far Item]|h|r", [2] = "|cffffffff|Hitem:222::::|h[Near Item]|h|r" }
local complete = { [3] = true }
local objectives = {
	[2] = {
		{ type = "monster", finished = false, text = "0/5 Wolf slain" },
		{ type = "monster", finished = true, text = "3/3 Boar slain" },
	},
}
local combat = false
local buttons = {}
local env = setmetatable({
	C_QuestLog = {
		GetNumQuestLogEntries = function()
			return #log
		end,
		GetInfo = function(index)
			return log[index]
		end,
		GetDistanceSqToQuest = function(id)
			return distances[id], distances[id] ~= nil
		end,
		IsComplete = function(id)
			return complete[id] or false
		end,
		GetQuestObjectives = function(id)
			return objectives[id]
		end,
	},
	GetQuestLogSpecialItemInfo = function(index)
		return items[log[index].questID]
	end,
	InCombatLockdown = function()
		return combat
	end,
	CreateFrame = function(_, name, _, template)
		assert(template == "SecureActionButtonTemplate", "a secure button of our own")
		local button = { attributes = {}, scripts = {} }
		button.RegisterForClicks = function() end
		function button:SetAttribute(key, value)
			self.attributes[key] = value
		end
		function button:SetScript(script, fn)
			self.scripts[script] = fn
		end
		buttons[name] = button
		return button
	end,
}, { __index = _G })
ns.QuestieDB = function()
	return {
		Npc = {
			GetAll = function(id)
				return { ({ [10] = "Mangy Wolf", [11] = "Timber Wolf", [12] = "Boar" })[id] }
			end,
		},
	}
end
ns.QuestProgress = {
	Targets = function(id)
		if id == 2 then
			return {
				{ kind = "monster", npcs = { [10] = true, [11] = true } },
				{ kind = "monster", npcs = { [12] = true } },
			}
		end
		return {}
	end,
}
setfenv(assert(loadfile("Quests/QuestButtons.lua")), env)("TweaksForever", ns)
assert(features.questButtons.default == true, "inert until the player binds a key")
assert(env.BINDING_HEADER_TWEAKSFOREVER == "Tweaks Forever")
assert(env["BINDING_NAME_CLICK TweaksForeverQuestItemButton:LeftButton"] == "Use the nearest quest item")
initializers[1]()
local item, target = buttons.TweaksForeverQuestItemButton, buttons.TweaksForeverQuestTargetButton
assert(item.attributes.type == "item" and target.attributes.type == "macro")

item.scripts.PreClick(item)
assert(item.attributes.item == "item:222", "the nearest quest with an item")
target.scripts.PreClick(target)
assert(target.attributes.macrotext == "/targetexact Mangy Wolf", "a creature the nearest unfinished quest needs")
target.scripts.PreClick(target)
assert(target.attributes.macrotext == "/targetexact Timber Wolf", "a different one each press")
target.scripts.PreClick(target)
assert(target.attributes.macrotext == "/targetexact Mangy Wolf", "round again; never the finished boars")

combat = true
items[2] = nil
item.scripts.PreClick(item)
assert(item.attributes.item == "item:222", "in combat the button keeps what it had")
combat = false
item.scripts.PreClick(item)
assert(item.attributes.item == "item:111", "out of combat the next nearest")
db.questButtons = false
item.scripts.PreClick(item)
target.scripts.PreClick(target)
assert(item.attributes.item == nil and target.attributes.macrotext == nil, "switched off, the keys do nothing")
print("questbuttons: ok")
