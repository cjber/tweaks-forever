local features, initializers = {}, {}
local ns = {
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
}
local env = setmetatable({
	GREEN_FONT_COLOR = {
		WrapTextInColorCode = function(_, text)
			return "<" .. text .. ">"
		end,
	},
}, { __index = _G })
setfenv(assert(loadfile("Spellbook.lua")), env)("TweaksForever", ns)
local Model = ns.FutureSpells
assert(features.trainableSpells.default and #initializers == 1)

local spells = {
	[1] = { name = "Purge", level = 12, lineID = 373 },
	[2] = { name = "Flame Shock", level = 10, lineID = 375 },
	[3] = { name = "Frost Shock", level = 20, lineID = 375 },
	[4] = { name = "Earth Shock", rank = "Rank 3", level = 14, lineID = 375 },
	[5] = { name = "Earth Shock", rank = "Rank 2", level = 8, lineID = 375 },
	[6] = { name = "Earth Shock", rank = "Rank 4", level = 24, lineID = 375 },
	[7] = { name = "Lightning Bolt", level = 20, lineID = 375 },
	[8] = { name = "Old Save", level = 4 },
	[9] = { name = "Two-Handed Swords", level = 1, line = "Two-Handed Swords" },
	[10] = { name = "Dual Wield", level = 20, lineID = 118, general = true },
}
local known = { [5] = true }
local chosen = Model.Choose(spells, 375, 18, function(id)
	return known[id]
end)
local names = {}
for i, entry in ipairs(chosen) do
	names[i] = entry.spell.name .. ":" .. entry.id .. ":" .. tostring(entry.ready)
end
assert(
	table.concat(names, ",") == "Flame Shock:2:true,Earth Shock:4:true,Frost Shock:3:false,Lightning Bolt:7:false",
	"one lowest unlearned rank per spell, other tabs and unlined saves left out, trainable first: "
		.. table.concat(names, ",")
)
for _, entry in
	ipairs(Model.Choose(spells, nil, 60, function()
		return false
	end))
do
	assert(entry.spell.lineID, "every tab's, never a weapon or unlined row: " .. entry.spell.name)
end
chosen = Model.Choose(spells, Model.GENERAL, 18, function()
	return false
end)
assert(#chosen == 1 and chosen[1].id == 10 and not chosen[1].ready, "the General tab lists its own rows only")

-- The baked trainer list, for a level 18 Dwarf Shaman who has never visited a trainer.
env.tContains = function(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end
setfenv(assert(loadfile("Data/ClassSpells.lua")), env)("TweaksForever", ns)
local DWARF, ORC = 3, 2
local NAMES = {
	[403] = "Lightning Bolt",
	[529] = "Lightning Bolt",
	[548] = "Lightning Bolt",
	[915] = "Lightning Bolt",
	[8056] = "Frost Shock",
	[8058] = "Frost Shock",
	[3599] = "Searing Totem",
	[6363] = "Searing Totem",
}
local unknownToClient = { [2645] = true } -- Ghost Wolf
local function Describe(id)
	if not unknownToClient[id] then
		return { name = NAMES[id] or tostring(id), icon = id }
	end
end
known = { [403] = true, [529] = true, [8042] = true }
local function Known(id)
	return known[id] == true
end
local shaman = Model.Spells(ns.ClassSpells.SHAMAN, nil, DWARF, Describe, Known)
local function Pick(name, list)
	for _, entry in ipairs(Model.Choose(list or shaman, 375, 18, Known)) do
		if entry.spell.name == name then
			return entry
		end
	end
end
local frost = Pick("Frost Shock")
assert(frost and frost.id == 8056 and not frost.ready, "Frost Shock rank 1 comes at 20")
assert(frost.spell.level == 20 and frost.spell.cost == 2200 and frost.spell.lineID == 375)
assert(Pick("Lightning Bolt").id == 548, "the rank after the known ones")
assert(Pick("Lightning Bolt").ready, "level 14 is ready at 18")
assert(not Pick("8042") and shaman[8042], "a known spell is left out")
assert(not shaman[2645], "a spell the client can't describe is left out")
assert(not shaman[6363], "Searing Totem rank 2 waits for the quest's rank 1")
known[3599] = true
assert(Model.Spells(ns.ClassSpells.SHAMAN, nil, DWARF, Describe, Known)[6363], "and shows once it is known")
local live = { [8056] = { name = "Frost Shock", level = 20, cost = 2000, icon = 1, lineID = 375 } }
frost = Pick("Frost Shock", Model.Spells(ns.ClassSpells.SHAMAN, live, DWARF, Describe, Known))
assert(frost.spell.cost == 2000, "a trainer visit's own fee wins")
local mage = ns.ClassSpells.MAGE
assert(Model.Spells(mage, nil, DWARF, Describe, Known)[3561], "Teleport: Stormwind for a Dwarf")
assert(not Model.Spells(mage, nil, ORC, Describe, Known)[3561], "but not for an Orc")
for token, class in pairs(ns.ClassSpells) do
	assert(#class.spells > 50, token .. " has a full list")
	for _, row in ipairs(class.spells) do
		assert(row[4] > 0 and row[2] >= 1 and (row[3] == nil or row[3] >= 0), token .. " " .. row[1])
	end
end

-- A German client: the tabs and the trainer name every line in German, and the baked rows still find their tab.
local TABS = { "Allgemein", "Elementarkampf", "Verstärkung" }
local TAB_OF = { [375] = 2, [373] = 3 } -- no Restoration spell learned yet, so no tab for it
env.UnitClass = function()
	return "Schamane", "SHAMAN", 7
end
env.UnitRace = function()
	return "Zwerg", "Dwarf", DWARF
end
env.C_Spell = {
	GetSpellInfo = function(id)
		return { name = NAMES[id] or tostring(id), iconID = id }
	end,
	GetSpellSubtext = function()
		return ""
	end,
}
env.C_SpellBook = {
	IsSpellKnown = Known,
	GetSkillLineIndexByID = function(lineID)
		return TAB_OF[lineID]
	end,
	GetSpellBookSkillLineInfo = function(index)
		return TABS[index] and { name = TABS[index] }
	end,
}
env.C_TradeSkillUI = {
	GetTradeSkillDisplayName = function(lineID)
		return lineID == 374 and "Wiederherstellung" or ""
	end,
}
local tabs = Model.Tabs(ns.ClassSpells.SHAMAN.lines, env.C_SpellBook.GetSkillLineIndexByID)
assert(tabs[2] == 375 and tabs[3] == 373 and not tabs[1], "each tab's line, by ID")
local german = Model.Choose(ns.TrainerSpells(), tabs[2], 18, Known)
local bolt
for _, entry in ipairs(german) do
	assert(entry.spell.lineID == 375)
	bolt = bolt or entry.id == 548 and entry
end
assert(#german > 3 and bolt and bolt.ready, "the baked rows list on the German Elementarkampf tab")
assert(ns.LineName(375) == "Elementarkampf" and ns.LineName(373, "Other") == "Verstärkung", "the tab's name first")
assert(ns.LineName(374, "Wiederherstellung (Lehrer)") == "Wiederherstellung (Lehrer)", "else the trainer's")
assert(ns.LineName(374) == "Wiederherstellung", "else the client's own")
local Resolve = ns.LineResolver()
assert(Resolve(548, "anything") == 375, "a baked spell's line")
assert(Resolve(99999, "Verstärkung") == 373, "a spell the list lacks, by the tab the trainer names")
assert(Resolve(99999, "Zweihandschwerter") == nil, "a weapon line is no class tab")

-- Saves from before lines were kept by ID.
local saved = {
	[548] = { name = "Blitzschlag", level = 14, icon = 1, line = "Elementarkampf" },
	[99999] = { name = "Neu", level = 16, icon = 1, line = "Verstärkung" },
	[201] = { name = "Einhandschwerter", level = 1, icon = 1, line = "Einhandschwerter" },
	[8056] = { name = "Frostschock", level = 20, icon = 1, lineID = 375 },
	[5] = "not a row",
}
Model.Migrate(saved, Resolve)
assert(saved[548].lineID == 375 and saved[99999].lineID == 373 and saved[8056].lineID == 375, "each gets its ID")
assert(not saved[201] and not saved[5], "weapon rows and junk go")
Model.Migrate(saved, Resolve)
assert(saved[548].lineID == 375, "and a second run changes nothing")

-- Blizzard's grid: two 680x590 views, three 220-wide columns, 60-tall items with 10 padding, 51-tall headers.
local grid =
	{ views = 2, width = 680, height = 590, columns = 3, gap = 15, pad = 10, spacer = 20, header = 51, item = 60 }
local header, slots = Model.Layout(4, 1, 140, grid)
assert(header.page == 0 and header.view == 1 and header.y == 170, "a spacer separates us from the spellbook's group")
assert(#slots == 4 and slots[1].y == 231 and slots[2].y == 301, "rows fill down a column first")
assert(slots[3].x == 650 / 3 + 15 and slots[3].y == 231 and slots[4].x == slots[3].x, "rows balance over the columns")

header, slots = Model.Layout(1, 1, 500, grid)
assert(header.page == 0 and header.view == 2 and header.y == 0, "a header without room for a row moves on")
assert(slots[1].view == 2 and slots[1].y == 61)

header, slots = Model.Layout(30, 2, 400, grid)
assert(header.view == 2 and header.page == 0)
local last = slots[#slots]
assert(#slots == 30 and last.page == 1, "overflow continues onto our own pages")
for _, slot in ipairs(slots) do
	assert(slot.y + grid.item <= grid.height, "every entry fits on its view")
end

-- The stock pager covers the foot of the last view: entries stop above it.
assert(Model.Room(590, 700, 160) == 540, "the pager's top ends the room")
assert(Model.Room(590, 700, 50) == 590 and Model.Room(590, nil, 160) == 590, "else the view's foot")
grid.height = Model.Room(590, 700, 160)
for _, slot in ipairs((select(2, Model.Layout(30, 2, 400, grid)))) do
	assert(slot.y + grid.item <= 540, "no entry reaches the pager")
end
print("spellbook: ok")
