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
	SafeCall = function(_, fn, ...)
		return assert(pcall(fn, ...))
	end,
}
-- Quest 1 (far) has an item; quest 2 (near) has an item and wolves and bears to kill; quest 3 (nearest) is done.
local log = {
	{ questID = 1, title = "Far" },
	{ questID = 2, title = "Near" },
	{ questID = 3, title = "Done" },
	{ questID = 4, title = "Elsewhere" },
}
local distances = { [1] = 900, [2] = 100, [3] = 25, [4] = 1600 }
local items = { [1] = "|cffffffff|Hitem:111::::|h[Far Item]|h|r", [2] = "|cffffffff|Hitem:222::::|h[Near Item]|h|r" }
local complete = { [3] = true }
local objectives = {
	[2] = {
		{ type = "monster", finished = false, text = "0/5 Wolf slain" },
		{ type = "monster", finished = true, text = "3/3 Boar slain" },
	},
}
local combat, keyDown = false, true
-- Quest 4 (no log item) gave item 333 and needs 444 (no use); you carry both.
local carried = { [333] = 1, [444] = 1 }
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
	GetCVarBool = function(name)
		assert(name == "ActionButtonUseKeyDown")
		return keyDown
	end,
	C_Item = {
		GetItemCount = function(id)
			return carried[id] or 0
		end,
		GetItemSpell = function(id)
			return id ~= 444 and "Use" or nil
		end,
	},
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
		Quest = {
			GetAll = function(id)
				return id == 4 and { 333, { 444 } } or nil
			end,
		},
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

-- A key press: down then up; the secure handler acts on the down with ActionButtonUseKeyDown on.
local function Press(button)
	button.scripts.PreClick(button, "LeftButton", true)
	button.scripts.PreClick(button, "LeftButton", false)
end
Press(item)
assert(item.attributes.item == "item:222", "the nearest quest with an item")
Press(target)
assert(target.attributes.macrotext == "/targetexact Mangy Wolf", "a creature the nearest unfinished quest needs")
Press(target)
assert(target.attributes.macrotext == "/targetexact Timber Wolf", "a different one each press")
Press(target)
assert(target.attributes.macrotext == "/targetexact Mangy Wolf", "round again; never the finished boars")

combat = true
items[2] = nil
Press(item)
assert(item.attributes.item == "item:222", "in combat the button keeps what it had")
combat = false
Press(item)
assert(item.attributes.item == "item:111", "out of combat the next nearest")
items[1] = nil
Press(item)
assert(item.attributes.item == "item:333", "else an item QuestieDB says the quest gave you, when it has a use")
keyDown = false
target.attributes.macrotext = nil
target.scripts.PreClick(target, "LeftButton", true)
assert(target.attributes.macrotext == nil, "with keys acting on release, the down press doesn't pick")
target.scripts.PreClick(target, "LeftButton", false)
assert(target.attributes.macrotext ~= nil, "the release does")
db.questButtons = false
Press(item)
Press(target)
assert(item.attributes.item == nil and target.attributes.macrotext == nil, "switched off, the keys do nothing")
print("questbuttons: ok")
