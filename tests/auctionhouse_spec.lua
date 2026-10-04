local features, initializers, events, changes = {}, {}, {}, {}
local db = { auctionItemLevel = true }
local ns = {
	db = db,
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
		changes[key] = fn
	end,
}

-- A category of the client's own tree, with the setter Blizzard's mixin carries.
local function Category(name, detail)
	return {
		name = name,
		detailColumnString = detail,
		SetDetailColumnString = function(self, value)
			self.detailColumnString = value
		end,
	}
end

-- The client's categories and globals, with a switch for an auction house addon that loaded before login. One gear
-- category already carries the item level column the game gives Containers, the other carries none.
local function Environment(loaded)
	return setmetatable({
		AuctionCategories = {
			Category("Weapons", nil),
			Category("Armor", "iLvl"),
			Category("Containers", "Slots"),
			Category("Miscellaneous", nil),
		},
		AUCTION_CATEGORY_WEAPONS = "Weapons",
		AUCTION_CATEGORY_ARMOR = "Armor",
		ITEM_LEVEL_ABBR = "iLvl",
		C_AddOns = {
			IsAddOnLoaded = function(name)
				return loaded and name == "Blizzard_AuctionHouseUI"
			end,
		},
	}, { __index = _G })
end

local env = Environment(false)
setfenv(assert(loadfile("UI/AuctionHouse.lua")), env)("TweaksForever", ns)

local feature = features.auctionItemLevel
assert(feature and feature.default == true and feature.category == "Interface")
assert(feature.name == "Item level column in the auction house")
local conflicts = {}
for _, conflict in ipairs(feature.conflicts) do
	conflicts[conflict.addon] = true
end
assert(conflicts.TradeSkillMaster and conflicts.Auctioneer, "addons that replace the Browse list are named")
assert(not conflicts.Auctionator, "Auctionator keeps its own tabs beside the game's Browse panel")

local model = assert(ns.AuctionHouse, "the category model is exported for the specs")

-- The tree gives the two gear categories, each with the detail column it had before the feature touched it.
local gear = model.Gear(env.AuctionCategories)
assert(#gear == 2 and gear[1].category == env.AuctionCategories[1] and gear[2].category == env.AuctionCategories[2])
assert(gear[1].detail == nil and gear[2].detail == "iLvl", "each category keeps its own original column")
model.Apply(gear, true)
assert(env.AuctionCategories[1].detailColumnString == "iLvl" and env.AuctionCategories[2].detailColumnString == "iLvl")
model.Apply(gear, false)
assert(env.AuctionCategories[1].detailColumnString == nil and env.AuctionCategories[2].detailColumnString == "iLvl")

-- Nothing happens before the auction house addon loads, and the wiring sets the column when it does.
initializers[1]()
assert(env.AuctionCategories[1].detailColumnString == nil)
events.ADDON_LOADED("Blizzard_AuctionHouseUI")
assert(env.AuctionCategories[1].detailColumnString == "iLvl", "weapons get the item level column")
assert(env.AuctionCategories[3].detailColumnString == "Slots", "another category keeps the column the game gave it")

-- Turning the feature off puts the gear categories back the way the client made them, and on again sets them.
db.auctionItemLevel = false
changes.auctionItemLevel()
assert(env.AuctionCategories[1].detailColumnString == nil, "weapons lose the column")
assert(env.AuctionCategories[2].detailColumnString == "iLvl", "a category that had the column keeps it")
db.auctionItemLevel = true
changes.auctionItemLevel()
assert(env.AuctionCategories[1].detailColumnString == "iLvl")

-- Another addon can have opened the auction house before login, so the addon is already loaded at setup.
initializers = {}
local early = Environment(true)
setfenv(assert(loadfile("UI/AuctionHouse.lua")), early)("TweaksForever", ns)
initializers[1]()
assert(early.AuctionCategories[1].detailColumnString == "iLvl", "a loaded auction house is set up at login")
assert(early.AuctionCategories[3].detailColumnString == "Slots")

print("auctionhouse: ok")
