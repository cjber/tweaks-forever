-- Automatic repair: at the merchant, and again as junk sales there bring in the money it was short of.
local features, handlers, db, printed = {}, {}, {}, {}
local ns = {
	L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}),
	Feature = function(feature)
		features[feature.key] = feature
	end,
	On = function(event, fn)
		assert(not handlers[event], event .. " is handled once")
		handlers[event] = fn
	end,
	Active = function(key)
		assert(features[key], "unknown feature " .. key)
		return db[key]
	end,
	Print = function(message)
		printed[#printed + 1] = message
	end,
}

local money, cost, repairs, merchantRepairs = 0, 0, {}, true
local env = setmetatable({
	CanMerchantRepair = function()
		return merchantRepairs
	end,
	GetRepairAllCost = function()
		return cost, cost > 0
	end,
	GetMoney = function()
		return money
	end,
	RepairAllItems = function(guild)
		repairs[#repairs + 1] = guild and "guild" or "own"
		if not guild then
			money = money - cost
		end
		cost = 0
	end,
	IsInGuild = function()
		return false
	end,
	C_CurrencyInfo = {
		GetCoinTextureString = function(amount)
			return amount .. "c"
		end,
	},
}, { __index = _G })
setfenv(assert(loadfile("Bags/Vendor.lua")), env)("TweaksForever", ns)
assert(features.repair.default == true, "repairs start on")

local function Reset(newMoney, newCost)
	money, cost, repairs, printed = newMoney, newCost, {}, {}
end

db.repair = true
Reset(50, 100)
handlers.MERCHANT_SHOW()
assert(#repairs == 0 and printed[1] == "not enough money to repair (100c).", "short of money: said once")
money = 80
handlers.PLAYER_MONEY()
assert(#repairs == 0 and #printed == 1, "a sale that still falls short stays quiet")
money = 120
handlers.PLAYER_MONEY()
assert(repairs[1] == "own" and printed[2] == "repaired for 100c.", "the sale that covers it pays for the repair")
assert(money == 20)
handlers.PLAYER_MONEY()
assert(#repairs == 1, "the repair's own spend does not repair again")

Reset(500, 100)
handlers.MERCHANT_SHOW()
assert(repairs[1] == "own" and printed[1] == "repaired for 100c.", "enough money repairs at once")
handlers.PLAYER_MONEY()
assert(#repairs == 1)

Reset(10, 100)
handlers.MERCHANT_SHOW()
handlers.MERCHANT_CLOSED()
money = 500
handlers.PLAYER_MONEY()
assert(#repairs == 0, "money after leaving the merchant is not spent on a repair")

Reset(10, 100)
handlers.MERCHANT_SHOW()
db.repair = false
money = 500
handlers.PLAYER_MONEY()
assert(#repairs == 0, "turning repairs off stops the retry")
db.repair = true

Reset(10, 100)
merchantRepairs = false
handlers.MERCHANT_SHOW()
money = 500
handlers.PLAYER_MONEY()
assert(#repairs == 0 and #printed == 0, "a merchant who doesn't repair is left alone")
merchantRepairs = true

Reset(0, 0)
handlers.MERCHANT_SHOW()
assert(#repairs == 0 and #printed == 0, "nothing to repair says nothing")
print("vendor: ok")
