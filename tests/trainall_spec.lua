local features, initializers, events, db = {}, {}, {}, {}
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
	On = function(event, fn)
		events[event] = fn
	end,
	OnSettingChanged = function(key, fn)
		assert(key == "trainAll")
		db.changed = fn
	end,
	L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}),
	db = db,
}

local function FakeButton()
	local button = { scripts = {}, enabled = true, shown = false }
	function button.SetSize() end
	function button.SetPoint() end
	function button:SetText(text)
		self.text = text
	end
	function button.SetMotionScriptsWhileDisabled() end
	function button:SetScript(name, fn)
		self.scripts[name] = fn
	end
	function button:SetEnabled(value)
		self.enabled = value
	end
	function button:Show()
		self.shown = true
	end
	function button:Hide()
		self.shown = false
	end
	function button.GetHeight()
		return 22
	end
	return button
end

local made
local hooked
local money, services, bought, tradeskill = 0, {}, {}, false
local lines = {}
local env = setmetatable({
	CreateFrame = function()
		made = FakeButton()
		return made
	end,
	ClassTrainerFrame = {},
	ClassTrainerTrainButton = FakeButton(),
	GetNumTrainerServices = function()
		return #services
	end,
	GetTrainerServiceInfo = function(index)
		return "Spell", services[index].kind
	end,
	GetTrainerServiceCost = function(index)
		return services[index].cost
	end,
	GetMoney = function()
		return money
	end,
	BuyTrainerService = function(index)
		bought[#bought + 1] = index
		money = money - services[index].cost
	end,
	IsTradeskillTrainer = function()
		return tradeskill
	end,
	GetMoneyString = function(amount)
		return amount .. "c"
	end,
	GameTooltip = { SetOwner = function() end, Show = function() end },
	GameTooltip_AddNormalLine = function(_, text)
		lines[#lines + 1] = text
	end,
	GameTooltip_AddErrorLine = function(_, text)
		lines[#lines + 1] = "!" .. text
	end,
	GameTooltip_Hide = function() end,
	hooksecurefunc = function(_, fn)
		hooked = fn
	end,
	C_AddOns = {
		IsAddOnLoaded = function()
			return false
		end,
	},
}, { __index = _G })
setfenv(assert(loadfile("UI/TrainAll.lua")), env)("TweaksForever", ns)
assert(features.trainAll.default == false and features.trainAll.category == "Interface")

initializers[1]()
events.ADDON_LOADED("Blizzard_TrainerUI")
assert(made == nil, "off by default, the trainer keeps the stock buttons alone")

db.trainAll = true
db.changed()
assert(made and made.shown and made.text == "Train all", "the button appears with the feature on")

services = {
	{ kind = "available", cost = 100 },
	{ kind = "used", cost = 0 },
	{ kind = "available", cost = 200 },
}
money = 300
hooked()
assert(made.enabled, "everything is affordable")
assert(made.services == 2 and made.total == 300, "two services costing 300 together")

money = 250
hooked()
assert(not made.enabled, "short of gold disables the button")
lines = {}
made.scripts.OnEnter()
assert(lines[1] == "Train 2 skills for 300c")
assert(lines[2] == "!Not enough gold for all of them.", "the tooltip gives the reason")

money = 300
bought = {}
made.scripts.OnClick()
assert(table.concat(bought, ",") == "1,3", "the available services are bought, the used one is not")

money = 150
bought = {}
made.scripts.OnClick()
assert(table.concat(bought, ",") == "1", "the rest is left when the gold runs out")

tradeskill = true
hooked()
assert(not made.shown, "a profession trainer keeps its own button")
tradeskill = false

db.trainAll = false
db.changed()
assert(not made.shown, "switching off hides the button")
bought = {}
made.scripts.OnClick()
assert(#bought == 0, "the button buys nothing while off")

local leatrix = features.trainAll.conflicts[1].when
assert(not leatrix())
env.LeaPlusDB = { ShowTrainAllButton = "On" }
assert(leatrix())
print("trainall: ok")
