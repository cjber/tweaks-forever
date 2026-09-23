local ns = {
	Feature = function() end,
	Init = function() end,
	Active = function()
		return false
	end,
}
local NAMES = { [403] = "Lightning Bolt", [529] = "Lightning Bolt", [548] = "Lightning Bolt", [915] = "Lightning Bolt" }
local known, level, class, combat = { [403] = true, [529] = true }, 18, "SHAMAN", false
local env = setmetatable({
	InCombatLockdown = function()
		return combat
	end,
	UnitClass = function()
		return "Shaman", class, 7
	end,
	UnitRace = function()
		return "Dwarf", "Dwarf", 3
	end,
	UnitLevel = function()
		return level
	end,
	C_Spell = {
		GetSpellInfo = function(id)
			return { name = NAMES[id] or tostring(id), iconID = id }
		end,
		GetSpellSubtext = function()
			return ""
		end,
	},
	C_SpellBook = {
		IsSpellKnown = function(id)
			return known[id] == true
		end,
	},
	tContains = function(list, value)
		for _, item in ipairs(list) do
			if item == value then
				return true
			end
		end
		return false
	end,
}, { __index = _G })
for _, file in ipairs({ "Data/ClassSpells.lua", "Spellbook.lua", "API.lua" }) do
	setfenv(assert(loadfile(file)), env)("TweaksForever", ns)
end
local API = env.TweaksForever.API
assert(API.version == 1)
assert(API.TrainableSpells() == nil, "before login the spellbook isn't known yet")
ns.db = {}
combat = true
assert(API.TrainableSpells() == nil, "not in combat")
combat = false

local function Find(list, id)
	for _, spell in ipairs(list) do
		if spell.spellID == id then
			return spell
		end
	end
end
local spells = API.TrainableSpells()
assert(#spells > 10, "a level 18 Shaman who has never seen a trainer still has spells to learn")
for _, spell in ipairs(spells) do
	assert(spell.level <= 18 and not known[spell.spellID], "only what your level allows and you haven't learned")
	assert(type(spell.name) == "string" and type(spell.line) == "string" and spell.cost, "every fact filled in")
end
local bolt = Find(spells, 548)
assert(bolt and bolt.name == "Lightning Bolt" and bolt.level == 14 and bolt.cost == 900, "the next rank")
assert(bolt.line == "Elemental Combat")
assert(not Find(spells, 915) and not Find(spells, 8056), "nothing above your level")

bolt.name = "Changed by caller"
assert(Find(API.TrainableSpells(), 548).name == "Lightning Bolt", "fresh copies")
env.TweaksForeverCharDB = {
	trainer = { [548] = { name = "Lightning Bolt", level = 14, cost = 700, icon = 1, line = "Elemental Combat" } },
}
assert(Find(API.TrainableSpells(), 548).cost == 700, "a trainer visit's fee wins")
known[548] = true
assert(not Find(API.TrainableSpells(), 548), "learned")
level = 20
assert(Find(API.TrainableSpells(), 915) and Find(API.TrainableSpells(), 8056), "a level up brings the next ones")
class = "DEATHKNIGHT"
env.TweaksForeverCharDB = nil
assert(#API.TrainableSpells() == 0, "no list, no answer")
print("api: ok")
