-- Quest levels in quest dialogs (Quests/QuestLevels.lua): the greeting list's buttons and the detail and reward
-- titles gain "[12] " in front of the title, once, while the game shows quest levels.
local features, db, initializers, gossipShow = {}, {}, {}, nil
local ns = {
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
	Active = function(key)
		return db[key]
	end,
	OnSettingChanged = function() end,
	On = function(event, fn)
		assert(event == "GOSSIP_SHOW")
		gossipShow = fn
	end,
}

local function Button(isActive, id, text)
	local button = { isActive = isActive, id = id, text = text, shown = true }
	function button:GetID()
		return self.id
	end
	function button:IsShown()
		return self.shown
	end
	button.IsObjectType = function(_, kind)
		return kind == "Button"
	end
	function button:GetText()
		return self.text
	end
	function button:SetText(value)
		self.text = value
	end
	function button:GetTextHeight()
		return #self.text > 24 and 24 or 12
	end
	function button:SetHeight(height)
		self.height = height
	end
	button.Icon = {
		GetHeight = function()
			return 16
		end,
	}
	return button
end

local DETAIL, REWARD, LOG = {}, {}, {}
local children, hooks = {}, {}
local header = { text = "Wanted: Hogger" }
function header:GetText()
	return self.text
end
function header:SetText(value)
	self.text = value
end
local cvar = true
local env = setmetatable({
	SetCVar = function() end,
	GetCVarBool = function()
		return cvar
	end,
	QuestFrameGreetingPanel = {
		GetChildren = function()
			return unpack(children)
		end,
	},
	hooksecurefunc = function(name, fn)
		hooks[name] = fn
	end,
	QUEST_TEMPLATE_DETAIL = DETAIL,
	QUEST_TEMPLATE_REWARD = REWARD,
	QuestInfoTitleHeader = header,
	GetActiveTitle = function(index)
		return ({ "The Fargodeep Mine" })[index], true
	end,
	GetActiveLevel = function()
		return 7
	end,
	GetActiveQuestID = function()
		return 60
	end,
	GetAvailableQuestInfo = function(index)
		return false, 0, false, false, ({ 7, 8 })[index]
	end,
	C_GossipInfo = {
		GetAvailableQuests = function()
			return { { questID = 33, questLevel = 6 } }
		end,
	},
	GetAvailableTitle = function(index)
		return ({ "Kobold Camp Cleanup", "Unknown" })[index]
	end,
	GetAvailableLevel = function(index)
		return index == 1 and 4 or 0
	end,
	GetQuestID = function()
		return 176
	end,
	C_QuestLog = {
		GetQuestDifficultyLevel = function(id)
			return id == 176 and 10 or 0
		end,
	},
}, { __index = _G })
setfenv(assert(loadfile("Quests/QuestLevels.lua")), env)("TweaksForever", ns)
local feature = features.questLevelsDialogs
assert(feature.default == true and feature.parent == "questLevels")
assert(feature.conflicts[1].polestar == "qol.questLevels", "Polestar's own quest levels in dialogs")
for _, fn in ipairs(initializers) do
	fn()
end
local onShow, display = hooks.QuestFrameGreetingPanel_OnShow, hooks.QuestInfo_Display
local questID = 176
env.GetQuestID = function()
	return questID
end

local function Greeting()
	children = {
		Button(1, 1, "|cff000000The Fargodeep Mine|r"),
		Button(0, 1, "Kobold Camp Cleanup"),
		Button(0, 2, "Unknown"),
		{ -- the panel's other children have no isActive
			IsShown = function()
				return true
			end,
		},
	}
	onShow()
	return children
end

db.questLevelsDialogs = true
local list = Greeting()
assert(list[1].text == "|cff000000[7] The Fargodeep Mine|r", "the game's format kept around the levelled title")
assert(list[2].text == "[4] Kobold Camp Cleanup", "an available quest")
assert(list[3].text == "Unknown", "no level known, no change")
assert(list[1].height == 26 and list[2].height == 16, "resized as Blizzard sizes it, in case the title now wraps")
onShow()
assert(list[2].text == "[4] Kobold Camp Cleanup", "never twice")

display(DETAIL)
assert(header.text == "[10] Wanted: Hogger", "the detail title")
display(REWARD)
assert(header.text == "[10] Wanted: Hogger", "the reward title, once")
-- A quest the log doesn't know yet takes the level its NPC's list gave.
questID, header.text = 7, "Kobold Camp Cleanup"
display(DETAIL)
assert(header.text == "[4] Kobold Camp Cleanup", "the greeting's level for a quest not yet taken")
gossipShow()
questID, header.text = 33, "A Gossip Quest"
display(DETAIL)
assert(header.text == "[6] A Gossip Quest", "the gossip window's level too")
questID = 176
header.text = "Wanted: Hogger"
display(LOG)
assert(header.text == "Wanted: Hogger", "the quest log's own display is left alone")

cvar = false
list = Greeting()
display(DETAIL)
assert(list[2].text == "Kobold Camp Cleanup" and header.text == "Wanted: Hogger", "quest levels off: unchanged")
cvar = true
db.questLevelsDialogs = false
list = Greeting()
display(DETAIL)
assert(list[2].text == "Kobold Camp Cleanup" and header.text == "Wanted: Hogger", "the option off: unchanged")
print("questlevels: ok")
