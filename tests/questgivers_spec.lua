local features, initializers = {}, {}
local ns = {
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
}

-- A synthetic QuestieDB: two maps 1000 yards square side by side on continent 0, and a handful of made-up NPCs and
-- quests. Area 10 is map 100, area 11 is a subzone of area 10, and area 12 has its map switched off.
local npcs = {
	[1] = { name = "Ada", spawns = { [10] = { { 50, 50 } } }, starts = { 101, 102, 103, 104, 105, 106 }, ends = {} },
	[2] = { name = "Ada", spawns = { [10] = { { 70, 70 } } }, starts = { 107 }, ends = {} }, -- 283 yd off
	[3] = { name = "Bo", spawns = { [11] = { { 52, 50 } } }, starts = {}, ends = { 201, 202, 203 } },
	[4] = { name = "Cy", spawns = { [10] = { { 51, 50 } } }, starts = {}, ends = {} }, -- gives nothing
	[5] = { name = "Di", spawns = { [10] = { { 49, 50 } }, [12] = { { 50, 50 } } }, starts = { 108 }, ends = {} },
	[6] = { name = "Di", spawns = { [10] = { { 50, 49 } } }, starts = { 108 }, ends = {} },
}
local quests = {
	[101] = { name = "Dry Times", questLevel = 15, requiredLevel = 10 },
	[102] = { name = "Done Before", questLevel = 12, requiredLevel = 8 },
	[103] = { name = "Orcs Only", questLevel = 12, requiredLevel = 8, requiredRaces = 2 },
	[104] = { name = "Next Step", questLevel = 16, requiredLevel = 14, preQuestGroup = { 102 } },
	[105] = { name = "Far Off", questLevel = 20, requiredLevel = 18 },
	[106] = { name = "Crafty", questLevel = 14, requiredLevel = 10, requiredSkill = { 164, 50 } },
	[107] = { name = "Elsewhere", questLevel = 14, requiredLevel = 10 },
	[108] = { name = "Twin", questLevel = 14, requiredLevel = 10 },
	[201] = { name = "Bring Back", questLevel = 14, requiredLevel = 10 },
	[202] = { name = "Half Way", questLevel = 13, requiredLevel = 10 },
	[203] = { name = "Not Taken", questLevel = 13, requiredLevel = 10 },
	[301] = { name = "Either", questLevel = 10, requiredLevel = 10, preQuestSingle = { 900, 102 } },
	[302] = { name = "Or", questLevel = 10, requiredLevel = 10, exclusiveTo = { 102 } },
	[303] = { name = "Mages", questLevel = 10, requiredLevel = 10, requiredClasses = 128 },
	[304] = { name = "Neither", questLevel = 10, requiredLevel = 10, preQuestSingle = { 900, 901 } },
}
local NPC_FIELD = { spawns = "spawns", questStarts = "starts", questEnds = "ends" }
local indexBuilt = false
local function Entity(rows, fieldOf)
	return {
		GetAll = function(id, keys)
			local row = rows[id]
			if not row then
				return nil
			end
			local values = { n = #keys }
			for i, key in ipairs(keys) do
				values[i] = row[fieldOf and fieldOf[key] or key]
			end
			return values
		end,
		IdsByName = function(name)
			local ids = {}
			for id, row in pairs(rows) do
				if row.name == name then
					ids[#ids + 1] = id
				end
			end
			table.sort(ids)
			return ids[1] and ids or nil
		end,
		BuildNameIndex = function()
			indexBuilt = true
		end,
	}
end
local library = {
	RequireContract = function(required)
		return required == 2
	end,
	Npc = Entity(npcs, NPC_FIELD),
	Quest = Entity(quests),
	Support = {
		Get = function(name)
			assert(name == "ZoneDB")
			return {
				private = {
					areaIdToUiMapId = "return { [10] = 100, [12] = 200 }",
					areaIdToUiMapIdOverride = "return { [12] = 0 }",
					subZoneToParentZone = "return { [11] = 10 }",
				},
			}
		end,
	},
}

local flavour = "Forever"
local completed, onQuest, complete = { [102] = true }, { [201] = true, [202] = true }, { [201] = true }
local player = { map = 100, x = 0.5, y = 0.5, level = 12, race = 1, class = 1 }
local postCalls = {}
local function Vector(x, y)
	return {
		GetXY = function()
			return x, y
		end,
	}
end
local env = setmetatable({
	LibQuestieDB = library,
	C_AddOns = {
		GetAddOnMetadata = function(addon, field)
			assert(addon == "QuestieDB" and field == "X-Flavor")
			return flavour
		end,
	},
	C_Map = {
		GetBestMapForUnit = function()
			return player.map
		end,
		GetPlayerMapPosition = function()
			return player.x and Vector(player.x, player.y)
		end,
		-- Map 100 spans x 0-1000 and map 200 spans x 1000-2000.
		GetWorldPosFromMapPos = function(map, position)
			local x, y = position:GetXY()
			return 0, Vector((map == 200 and 1000 or 0) + x * 1000, y * 1000)
		end,
	},
	CreateVector2D = Vector,
	C_QuestLog = {
		IsQuestFlaggedCompleted = function(id)
			return completed[id] or false
		end,
		IsOnQuest = function(id)
			return onQuest[id] or false
		end,
		IsComplete = function(id)
			return complete[id] or false
		end,
	},
	UnitLevel = function()
		return player.level
	end,
	UnitRace = function()
		return "Human", "Human", player.race
	end,
	UnitClass = function()
		return "Warrior", "WARRIOR", player.class
	end,
	GetQuestDifficultyColor = function(level)
		return { r = level, g = 0, b = 0 }
	end,
	GRAY_FONT_COLOR = { r = -1, g = -1, b = -1 },
	HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 },
	canaccessvalue = function(value)
		return value ~= "secret"
	end,
	strtrim = function(text)
		return (text:gsub("^%s+", ""):gsub("%s+$", ""))
	end,
	TooltipDataProcessor = {
		AddTooltipPostCall = function(kind, fn)
			postCalls[kind] = fn
		end,
	},
	Enum = { TooltipDataType = { MinimapMouseover = 21 } },
}, { __index = _G })
setfenv(assert(loadfile("QuestGivers.lua")), env)("TweaksForever", ns)
local Model = ns.QuestGivers
assert(features.giverTooltips.default == true and #initializers == 1)

-- Without the Forever build of a contract-2 QuestieDB there is nothing to read, and the option is greyed out.
local needs = features.giverTooltips.needs
assert(needs.title == "QuestieDB")
flavour = "Vanilla"
assert(not Model.Attach() and not needs.check())
flavour = "Forever"
env.LibQuestieDB = nil
assert(not Model.Attach() and not needs.check())
env.LibQuestieDB = library
assert(Model.Attach() and needs.check())

-- Names: one per line, icons and colours stripped, and secret text skipped.
local names = Model.Names({
	lines = {
		{ leftText = "|TInterface\\Minimap\\Blip:0|t |cffffd200Ada|r\nBo" },
		{ leftText = "secret" },
		{ leftText = "  " },
	},
})
assert(#names == 2 and names[1] == "Ada" and names[2] == "Bo")

-- The NPC is the one of that name within minimap range; a subzone's spawn is placed on its parent's map.
assert(Model.Resolve("Ada", 0, 500, 500).id == 1, "the other Ada is 283 yd away")
assert(Model.Resolve("Ada", 0, 600, 600) == nil, "both Adas are within range of this point")
assert(Model.Resolve("Ada", 1, 500, 500) == nil, "another continent")
assert(Model.Resolve("Bo", 0, 500, 500).id == 3)
assert(Model.Resolve("Cy", 0, 500, 500) == nil, "an NPC without quests is not a giver")
assert(Model.Resolve("Nobody", 0, 500, 500) == nil)
assert(Model.Resolve("Di", 0, 500, 500) == nil, "two givers of one name in range stay ambiguous")
assert(#Model.Resolve("Ada", 0, 500, 500).points == 1)

-- Offers: only what this character can take, by level, then the next few levels' greyed.
local ada = Model.Resolve("Ada", 0, 500, 500)
local offers, turnIns = Model.Quests(ada)
assert(#turnIns == 0)
assert(#offers == 2, "done, other race, unmet prerequisite, too high and unknowable skill are left out")
assert(offers[1].id == 101 and offers[1].level == 15 and not offers[1].soon)
assert(offers[2].id == 104 and offers[2].soon and offers[2].min == 14, "a prerequisite done, two levels up")
player.level = 20
offers = Model.Quests(ada)
assert(#offers == 3 and offers[3].id == 105 and not offers[3].soon)
player.level = 12
player.race = 2
offers = Model.Quests(ada)
assert(offers[1].id == 103, "Orcs Only opens at 8")

-- Prerequisites: one of the singles, no exclusive quest done, and the class mask.
ada.starts = { 301, 302, 303, 304 }
player.class = 8
offers = Model.Quests(ada)
assert(#offers == 2 and offers[1].id == 301 and offers[2].id == 303)
player.race, player.class = 1, 1

-- Turn-ins: the quests in your log this NPC takes, ready ones marked.
local bo = Model.Resolve("Bo", 0, 500, 500)
offers, turnIns = Model.Quests(bo)
assert(#offers == 0 and #turnIns == 2)
assert(turnIns[1].id == 202 and not turnIns[1].ready)
assert(turnIns[2].id == 201 and turnIns[2].ready)

-- Lines: turn-ins first with their state's icon, then offers in level colour or grey with the level they open at.
local lines = Model.Lines(bo)
assert(lines[1][1]:find("SideInProgressquesticon", 1, true) and lines[1][1]:find("[13] Half Way", 1, true))
assert(lines[2][1]:find("ActiveQuestIcon", 1, true) and lines[2][2] == 14)
ada.starts = { 101, 104 }
lines = Model.Lines(ada)
assert(lines[1][1]:find("AvailableQuestIcon", 1, true) and lines[1][1]:find("[15] Dry Times", 1, true))
assert(lines[1][2] == 15)
assert(lines[2][1]:find("[16] Next Step (level 14)", 1, true) and lines[2][2] == -1)

-- The tooltip: one giver's lines alone, several under their names, nothing outside the map.
lines = Model.TooltipLines({ "Ada" })
assert(#lines == 2 and lines[1][1]:find("Dry Times", 1, true))
lines = Model.TooltipLines({ "Ada", "Bo", "Cy" })
assert(#lines == 6 and lines[1][1] == "Ada" and lines[4][1] == "Bo")
player.x = nil
assert(#Model.TooltipLines({ "Ada" }) == 0, "no map position, as in an instance")
player.x = 0.5

-- Wired up: the name index is built at login, and the minimap tooltip gains the lines.
ns.db = { giverTooltips = true }
ns.Active = function(key)
	return ns.db[key]
end
ns.On = function() end
initializers[1]()
assert(indexBuilt)
local added, shown = {}, false
local tooltip = {
	AddLine = function(_, text)
		added[#added + 1] = text
	end,
	Show = function()
		shown = true
	end,
}
env.GameTooltip = tooltip
postCalls[21](tooltip, { lines = { { leftText = "Ada" } } })
assert(#added == 2 and shown)
ns.db.giverTooltips = false
postCalls[21](tooltip, { lines = { { leftText = "Ada" } } })
assert(#added == 2, "switched off")
print("questgivers: ok")
