local features, handlers, db = {}, {}, {}
local ns = {
	Feature = function(feature)
		features[feature.key] = feature
	end,
	On = function(event, fn)
		handlers[event] = fn
	end,
	Active = function(key)
		return db[key]
	end,
	db = db,
}
local rolls, loots, hides = {}, {}, {}
local env = setmetatable({
	ConfirmLootRoll = function(id, roll)
		rolls[#rolls + 1] = id .. "/" .. tostring(roll)
	end,
	ConfirmLootSlot = function(slot)
		loots[#loots + 1] = slot
	end,
	StaticPopup_Hide = function(name)
		hides[#hides + 1] = name
	end,
}, { __index = _G })
setfenv(assert(loadfile("Features/LootConfirm.lua")), env)("TweaksForever", ns)
assert(features.lootConfirm.default == false and features.lootConfirm.category == "Automation")

handlers.CONFIRM_LOOT_ROLL(7, 1)
handlers.CONFIRM_DISENCHANT_ROLL(8, 2)
handlers.LOOT_BIND_CONFIRM(3)
assert(#rolls == 0 and #loots == 0 and #hides == 0, "off by default the warnings stay")

db.lootConfirm = true
handlers.CONFIRM_LOOT_ROLL(7, 1)
assert(rolls[1] == "7/1", "the need roll is confirmed as asked")
assert(hides[1] == "CONFIRM_LOOT_ROLL")

handlers.CONFIRM_DISENCHANT_ROLL(8, 2)
assert(rolls[2] == "8/2", "the disenchant roll is confirmed too")
assert(hides[2] == "CONFIRM_LOOT_ROLL")

handlers.LOOT_BIND_CONFIRM(3)
assert(loots[1] == 3, "the bind on pickup loot is confirmed")
assert(hides[3] == "LOOT_BIND")

local leatrix = features.lootConfirm.conflicts[1].when
assert(not leatrix())
env.LeaPlusDB = { NoConfirmLoot = "On" }
assert(leatrix())
print("lootconfirm: ok")
