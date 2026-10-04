---@type string, TFNamespace
local _, ns = ...

local KEY = "auctionItemLevel"

-- Addons that replace the auction house's Browse list with one of their own: the game's column would never show,
-- so this stays off. Auctionator adds tabs beside the game's Browse panel and is left alone.
ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Item level column in the auction house",
	tooltip = "Weapons and armour in the auction house's Browse tab get an Item level column between Name and "
		.. "Available, sorted by clicking its header like the game's own columns. The item level no longer repeats "
		.. "after the name.",
	default = true,
	conflicts = {
		{ addon = "TradeSkillMaster" },
		{ addon = "Auctioneer" },
	},
})

-- The Browse list adds its sortable detail column only when the selected category carries a detail column string.
-- Weapons and Armor carry none, so gear is listed with the item level after the name and can be sorted by name
-- alone. The game gives Containers, Consumables and Recipes their detail column the same way (Blizzard_AuctionData).
local GEAR = {
	[AUCTION_CATEGORY_WEAPONS] = true,
	[AUCTION_CATEGORY_ARMOR] = true,
}

---@class TFAuctionColumn
---@field category AuctionCategoryMixin
---@field detail string? the category's detail column before this feature touched it

---@class TFAuctionHouse
local Model = {}
ns.AuctionHouse = Model

-- The top-level gear categories in the client's tree, with the detail column each carried. A subcategory inherits
-- its parent's detail column, so setting it on the parent covers every piece of gear (GetDetailColumnStringUnsafe).
---@param categories AuctionCategoryMixin[]
---@return TFAuctionColumn[]
function Model.Gear(categories)
	local gear = {}
	for _, category in ipairs(categories) do
		if GEAR[category.name] then
			gear[#gear + 1] = { category = category, detail = category.detailColumnString }
		end
	end
	return gear
end

-- Turn the item level column on or off, putting every other category back as the client made it. The client's own
-- setter is the only thing touched: the header text it holds is read by the Browse layout alone, never by buying
-- or posting.
---@param gear TFAuctionColumn[]
---@param on boolean
function Model.Apply(gear, on)
	for _, entry in ipairs(gear) do
		entry.category:SetDetailColumnString(on and ITEM_LEVEL_ABBR or entry.detail)
	end
end

-- The gear categories and their original detail columns, captured once the auction house addon has built its tree.
---@type TFAuctionColumn[]
local gear = {}
local captured = false

local function Capture()
	if captured or #AuctionCategories == 0 then
		return
	end
	captured = true
	gear = Model.Gear(AuctionCategories --[[@as AuctionCategoryMixin[] ]])
	Model.Apply(gear, ns.Active(KEY))
end

local function Toggle()
	if captured then
		Model.Apply(gear, ns.Active(KEY))
	end
end

ns.Init(function()
	-- Blizzard_AuctionHouseUI loads on demand, when the player first opens the auction house.
	ns.On("ADDON_LOADED", function(addon)
		if addon == "Blizzard_AuctionHouseUI" then
			Capture()
		end
	end)
	if C_AddOns.IsAddOnLoaded("Blizzard_AuctionHouseUI") then
		Capture()
	end
	ns.OnSettingChanged(KEY, Toggle)
end)
