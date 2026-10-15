-- The best-selling reward marker (Quests/BestReward.lua): among a quest's reward choices, a gold coin on the one
-- that sells for strictly the most, once every price is known; nothing chosen.
local features, handlers, db, initializers, hooks, settingCallbacks = {}, {}, {}, {}, {}, {}
local ns = {
	Feature = function(feature)
		features[feature.key] = feature
	end,
	On = function(event, fn)
		handlers[event] = fn
	end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
	Active = function(key)
		return db[key]
	end,
	OnSettingChanged = function(key, fn)
		settingCallbacks[key] = fn
	end,
}

local function Region()
	local region = { shown = true, points = {} }
	region.SetSize = function() end
	region.SetAllPoints = function() end
	function region:SetTexture(file)
		self.file = file
	end
	function region:SetParent(parent)
		self.parent = parent
	end
	function region:SetFrameLevel(level)
		self.level = level
	end
	function region:GetFrameLevel()
		return self.level or 1
	end
	function region:ClearAllPoints()
		self.points = {}
	end
	function region:SetPoint(...)
		self.points[#self.points + 1] = { ... }
	end
	function region:Show()
		self.shown = true
	end
	function region:Hide()
		self.shown = false
	end
	function region:IsShown()
		return self.shown
	end
	function region:CreateTexture()
		self.texture = Region()
		return self.texture
	end
	return region
end

local made, marker = 0, nil
local items, cached = {}, {}
local panel = Region()
local buttons = {}
local env = setmetatable({
	QuestFrameRewardPanel = panel,
	QuestInfoRewardsFrame = { RewardButtons = buttons },
	CreateFrame = function()
		made = made + 1
		marker = Region()
		return marker
	end,
	hooksecurefunc = function(name, fn)
		hooks[name] = fn
	end,
	GetNumQuestChoices = function()
		return #items
	end,
	GetQuestItemLink = function(_, index)
		return items[index] and items[index].link
	end,
	GetQuestItemInfo = function(_, index)
		return "name", 0, items[index].count
	end,
	C_Item = {
		GetItemInfo = function(link)
			if cached[link] == false then
				return nil
			end
			for _, item in ipairs(items) do
				if item.link == link then
					return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, item.price
				end
			end
		end,
	},
}, { __index = _G })
setfenv(assert(loadfile("Quests/BestReward.lua")), env)("TweaksForever", ns)
local feature = features.bestReward
assert(feature.default == true, "a marker, not an automation: on by default")
assert(feature.conflicts[1].polestar == "qol.rewardHighlight", "Polestar's own reward highlight")
initializers[1]()

-- Model.Best on its own.
local Best = ns.BestReward.Best
local function choices(...)
	local list = {}
	for index, value in ipairs({ ... }) do
		list[index] = { index = index, value = value ~= false and value or nil }
	end
	return list
end
assert(Best(choices(10, 50, 20)) == 2, "the highest value")
assert(Best(choices(50, 50, 20)) == nil, "a tie at the top marks none")
assert(Best(choices(0, 0)) == nil, "nothing worth selling marks none")
local best, pending = Best(choices(10, false, 20))
assert(best == nil and pending, "an uncached item waits")
assert(Best(choices(30)) == nil, "a lone reward is no choice")

-- On the quest frame.
local function Button(id, icon)
	local button = Region()
	button.type, button.Icon = "choice", icon and Region() or nil
	button.GetID = function()
		return id
	end
	return button
end
local function Show(list)
	items = list
	for index = #buttons, 1, -1 do
		buttons[index] = nil
	end
	-- One reward that isn't a choice comes first, as the game lays them out.
	local fixed = Region()
	fixed.type = "reward"
	buttons[1] = fixed
	for index = 1, #list do
		buttons[index + 1] = Button(index, true)
	end
	hooks.QuestInfo_Display()
end
-- The button the coin sits on, or nil when none shows.
local function Marked()
	if not (marker and marker.shown) then
		return nil
	end
	local anchor = marker.points[1][2]
	for _, button in ipairs(buttons) do
		if button == anchor or button.Icon == anchor then
			return button:GetID()
		end
	end
end

db.bestReward = true
Show({
	{ link = "item:1", price = 100, count = 1 },
	{ link = "item:2", price = 30, count = 5 },
	{ link = "item:3", price = 120, count = 1 },
})
assert(Marked() == 2, "five at 30 outsell one at 120")
assert(marker.texture.file == "Interface\\MoneyFrame\\UI-GoldIcon", "the game's gold coin")
assert(marker.level > buttons[3]:GetFrameLevel(), "drawn over the button")
for _, button in ipairs(buttons) do
	assert(button.texture == nil, "nothing is drawn on the game's buttons")
end

Show({ { link = "item:1", price = 100 }, { link = "item:2", price = 100 } })
assert(Marked() == nil, "a tie marks none")
assert(made == 1, "the marker frame is made once")

cached["item:2"] = false
Show({ { link = "item:1", price = 100 }, { link = "item:2", price = 300 } })
assert(Marked() == nil, "an uncached price waits")
cached["item:2"] = nil
handlers.GET_ITEM_INFO_RECEIVED()
assert(Marked() == 2, "and marks once it arrives")

Show({ { link = "item:1", price = 100 } })
assert(Marked() == nil, "a lone reward is no choice")

Show({ { link = "item:1", price = 100 }, { link = "item:2", price = 300 } })
panel.shown = false
hooks.QuestInfo_Display()
assert(Marked() == nil, "the quest log's details aren't the reward panel")
panel.shown = true

hooks.QuestInfo_Display()
assert(Marked() == 2)
db.bestReward = false
settingCallbacks.bestReward()
assert(Marked() == nil, "turning it off hides the coin at once")
print("bestreward: ok")
