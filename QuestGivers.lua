---@type string, TFNamespace
local _, ns = ...

local KEY = "giverTooltips"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Quests on minimap givers",
	tooltip = "Pointing at a quest giver on the minimap lists the quests they have for you, coloured by level, "
		.. "and the quests in your log they take back, with a gold ? once one is ready to hand in. Needs the QuestieDB "
		.. "addon, which works on its own: Questie itself isn't needed.",
	default = true,
	needs = {
		title = "QuestieDB",
		check = function()
			return ns.QuestieDB() ~= nil
		end,
	},
})

-- QuestieDB, read at runtime only: its public API (contract 2) for the Forever flavour. QuestProgress.lua reads it too.
local ADDON, CONTRACT = "QuestieDB", 2
-- Yards from you a giver can stand and still be on the minimap, whose widest view is about 233 yards across its radius.
local RANGE = 250
-- Quests this many levels above you still show, greyed, with the level they open at.
local SOON = 3
local QUEST_FIELDS = {
	"name",
	"questLevel",
	"requiredLevel",
	"requiredRaces",
	"requiredClasses",
	"preQuestGroup",
	"preQuestSingle",
	"exclusiveTo",
	"requiredSkill",
	"requiredMinRep",
	"requiredMaxRep",
	"requiredSpell",
}
local NPC_FIELDS = { "spawns", "questStarts", "questEnds" }
local OFFER = "|TInterface\\GossipFrame\\AvailableQuestIcon:0|t "
local READY = "|TInterface\\GossipFrame\\ActiveQuestIcon:0|t "
local UNREADY = "|A:SideInProgressquesticon:14:14|a "

---@class TFQuestGivers
local Model = {}
ns.QuestGivers = Model

local lib ---@type TFQuestieDB
-- QuestieDB's area-to-map tables, read from its ZoneDB support source.
local areaMap, areaOverride, parentZone
-- [name] = the quest NPCs of that name with their spawns in world yards.
---@type table<string, TFGiverCandidate[]>
local candidates = {}

-- One of ZoneDB's tables, which QuestieDB keeps as Lua source returning a table literal: run with no globals.
---@param source any
---@return table?
local function Table(source)
	local chunk = type(source) == "string" and loadstring(source)
	if not chunk then
		return nil
	end
	setfenv(chunk, {})
	local ok, value = pcall(chunk)
	return ok and type(value) == "table" and value or nil
end

-- The loaded QuestieDB, if it is the Forever build of a contract this addon was written against.
---@return TFQuestieDB?
function ns.QuestieDB()
	local db = LibQuestieDB
	if type(db) ~= "table" or C_AddOns.GetAddOnMetadata(ADDON, "X-Flavor") ~= "Forever" then
		return nil
	end
	local ok, fits = pcall(db.RequireContract, CONTRACT)
	return ok and fits and db or nil
end

---@return boolean
function Model.Attach()
	candidates = {}
	local db = ns.QuestieDB()
	if not db or not (db.Npc and db.Npc.IdsByName and db.Quest and db.Support) then
		return false
	end
	local zones = db.Support.Get("ZoneDB")
	local private = type(zones) == "table" and zones.private
	if type(private) ~= "table" then
		return false
	end
	areaMap, areaOverride, parentZone =
		Table(private.areaIdToUiMapId), Table(private.areaIdToUiMapIdOverride) or {}, Table(private.subZoneToParentZone)
	if not areaMap or not parentZone then
		return false
	end
	lib = db
	return true
end

-- An area's map, or its parent zone's; an override of 0 means the area has no map.
---@param area integer
---@return integer?
local function MapOf(area)
	local map = areaOverride[area] or areaMap[area]
	if map == nil and parentZone[area] then
		local parent = parentZone[area]
		map = areaOverride[parent] or areaMap[parent]
	end
	return type(map) == "number" and map ~= 0 and map or nil
end

-- The quest NPCs named `name`, each with its spawns as world positions, once per name.
---@param name string
---@return TFGiverCandidate[]
local function Candidates(name)
	local found = candidates[name]
	if found then
		return found
	end
	found = {}
	for _, id in ipairs(lib.Npc.IdsByName(name) or {}) do
		local values = lib.Npc.GetAll(id, NPC_FIELDS)
		local spawns, starts, ends = values and values[1], values and values[2], values and values[3]
		local gives = type(starts) == "table" and #starts > 0 or type(ends) == "table" and #ends > 0
		if gives and type(spawns) == "table" then
			local points = {}
			for area, spots in pairs(spawns) do
				local map = type(area) == "number" and MapOf(area) or nil
				if map then
					for _, spot in ipairs(spots) do
						local continent, world =
							C_Map.GetWorldPosFromMapPos(map, CreateVector2D(spot[1] / 100, spot[2] / 100))
						if continent and world then
							local x, y = world:GetXY()
							points[#points + 1] = { continent = continent, x = x, y = y }
						end
					end
				end
			end
			found[#found + 1] = { id = id, points = points, starts = starts or {}, ends = ends or {} }
		end
	end
	candidates[name] = found
	return found
end

-- The one quest NPC named `name` with a spawn within minimap range of you, or nil when none is, or several are.
---@param name string
---@param continent integer
---@param x number
---@param y number
---@return TFGiverCandidate?
function Model.Resolve(name, continent, x, y)
	local match
	for _, npc in ipairs(Candidates(name)) do
		for _, point in ipairs(npc.points) do
			if point.continent == continent and (point.x - x) ^ 2 + (point.y - y) ^ 2 <= RANGE * RANGE then
				if match then
					return nil
				end
				match = npc
				break
			end
		end
	end
	return match
end

---@param list any
---@return boolean
local function AllDone(list)
	for _, id in ipairs(type(list) == "table" and list or {}) do
		if not C_QuestLog.IsQuestFlaggedCompleted(id) then
			return false
		end
	end
	return true
end

---@param list any
---@return boolean
local function AnyDone(list)
	if type(list) ~= "table" or #list == 0 then
		return true
	end
	for _, id in ipairs(list) do
		if C_QuestLog.IsQuestFlaggedCompleted(id) then
			return true
		end
	end
	return false
end

-- Whether your race or class is in a mask, where 0 is everyone.
---@param mask any
---@param id integer
---@return boolean
local function InMask(mask, id)
	mask = tonumber(mask) or 0
	return mask == 0 or bit.band(mask, bit.lshift(1, id - 1)) ~= 0
end

-- A quest the data names a requirement for that this file cannot check for you.
---@param v table
---@return boolean
local function Unknowable(v)
	local skill = v.requiredSkill
	return type(skill) == "table" and (tonumber(skill[2]) or 0) > 0
		or type(v.requiredMinRep) == "table" and v.requiredMinRep[1] ~= nil
		or type(v.requiredMaxRep) == "table" and v.requiredMaxRep[1] ~= nil
		or (tonumber(v.requiredSpell) or 0) ~= 0
end

---@param id integer
---@return table?
local function Quest(id)
	local values = lib.Quest.GetAll(id, QUEST_FIELDS)
	if not values or type(values[1]) ~= "string" then
		return nil
	end
	local v = {}
	for index, field in ipairs(QUEST_FIELDS) do
		v[field] = values[index]
	end
	return v
end

---@param a TFGiverQuest
---@param b TFGiverQuest
---@return boolean
local function ByLevel(a, b)
	if a.min ~= b.min then
		return a.min < b.min
	end
	if a.level ~= b.level then
		return a.level < b.level
	end
	return a.title < b.title
end

-- What an NPC has for you: quests you can take now, then the next few levels' (`soon`), and the quests in your log it
-- takes back (`turnIn`, with `ready` once complete).
---@param npc TFGiverCandidate
---@return TFGiverQuest[] offers
---@return TFGiverQuest[] turnIns
function Model.Quests(npc)
	local level = UnitLevel("player")
	local _, _, race = UnitRace("player")
	local _, _, class = UnitClass("player")
	local offers, turnIns = {}, {}
	for _, id in ipairs(npc.starts) do
		local v = not C_QuestLog.IsQuestFlaggedCompleted(id) and not C_QuestLog.IsOnQuest(id) and Quest(id)
		if
			v
			and InMask(v.requiredRaces, race)
			and InMask(v.requiredClasses, class)
			and AllDone(v.preQuestGroup)
			and AnyDone(v.preQuestSingle)
			and not Unknowable(v)
		then
			local open = true
			for _, other in ipairs(type(v.exclusiveTo) == "table" and v.exclusiveTo or {}) do
				open = open and not C_QuestLog.IsQuestFlaggedCompleted(other) and not C_QuestLog.IsOnQuest(other)
			end
			local min = tonumber(v.requiredLevel) or 0
			if open and min <= level + SOON then
				local questLevel = tonumber(v.questLevel) or 0
				offers[#offers + 1] = {
					id = id,
					title = v.name,
					level = questLevel > 0 and questLevel or math.max(min, 1),
					min = min,
					soon = min > level,
				}
			end
		end
	end
	for _, id in ipairs(npc.ends) do
		local v = C_QuestLog.IsOnQuest(id) and Quest(id)
		if v then
			local questLevel = tonumber(v.questLevel) or 0
			turnIns[#turnIns + 1] = {
				id = id,
				title = v.name,
				level = questLevel > 0 and questLevel or level,
				min = 0,
				ready = C_QuestLog.IsComplete(id),
			}
		end
	end
	table.sort(offers, ByLevel)
	table.sort(turnIns, ByLevel)
	return offers, turnIns
end

-- The tooltip lines for an NPC: { text, r, g, b }.
---@param npc TFGiverCandidate
---@return [string, number, number, number][]
function Model.Lines(npc)
	local offers, turnIns = Model.Quests(npc)
	local lines = {}
	for _, quest in ipairs(turnIns) do
		local color = GetQuestDifficultyColor(quest.level)
		local text = (quest.ready and READY or UNREADY) .. ("[%d] %s"):format(quest.level, quest.title)
		lines[#lines + 1] = { text, color.r, color.g, color.b }
	end
	for _, quest in ipairs(offers) do
		local text = OFFER .. ("[%d] %s"):format(quest.level, quest.title)
		if quest.soon then
			local grey = GRAY_FONT_COLOR
			lines[#lines + 1] = { text .. (" (level %d)"):format(quest.min), grey.r, grey.g, grey.b }
		else
			local color = GetQuestDifficultyColor(quest.level)
			lines[#lines + 1] = { text, color.r, color.g, color.b }
		end
	end
	return lines
end

-- The names in a minimap tooltip: one per line, with any icon and colour markup removed.
---@param data TooltipData
---@return string[]
function Model.Names(data)
	local names = {}
	for _, line in ipairs(data.lines or {}) do
		local text = line.leftText
		-- A line's text may be secret, which can't be read.
		if canaccessvalue(text) and type(text) == "string" then
			text = text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
			for name in text:gmatch("[^\n]+") do
				name = strtrim(name)
				if name ~= "" then
					names[#names + 1] = name
				end
			end
		end
	end
	return names
end

-- Your world position, or nil where the map has none (inside instances).
---@return integer?, number?, number?
local function Here()
	local map = C_Map.GetBestMapForUnit("player")
	local position = map and C_Map.GetPlayerMapPosition(map, "player")
	if not map or not position then
		return nil
	end
	local continent, world = C_Map.GetWorldPosFromMapPos(map, position)
	if not continent or not world then
		return nil
	end
	local x, y = world:GetXY()
	return continent, x, y
end

-- The lines to add for a minimap tooltip naming `names`. A name heads its giver's lines when more than one giver
-- has something for you.
---@param names string[]
---@return [string, number, number, number][]
function Model.TooltipLines(names)
	local blocks = {}
	local continent, x, y = Here()
	if not continent or not x or not y then
		return {}
	end
	local seen = {}
	for _, name in ipairs(names) do
		local npc = Model.Resolve(name, continent, x, y)
		if npc and not seen[npc] then
			seen[npc] = true
			local lines = Model.Lines(npc)
			if #lines > 0 then
				blocks[#blocks + 1] = { name = name, lines = lines }
			end
		end
	end
	local out = {}
	for _, block in ipairs(blocks) do
		if #blocks > 1 then
			local white = HIGHLIGHT_FONT_COLOR
			out[#out + 1] = { block.name, white.r, white.g, white.b }
		end
		for _, line in ipairs(block.lines) do
			out[#out + 1] = line
		end
	end
	return out
end

ns.Init(function()
	if not Model.Attach() then
		return
	end
	-- The name index is one pass over every NPC: build it now, behind the loading screen, not on the first hover.
	if ns.Active(KEY) then
		lib.Npc.BuildNameIndex()
	end

	-- The minimap redraws its tooltip every frame the mouse is over it, so the lines are kept until what they depend
	-- on changes: the names, where you stand, and your log and level.
	local generation, lastKey, lastLines = 0, nil, {}
	local function Stale()
		generation = generation + 1
	end
	ns.On("QUEST_LOG_UPDATE", Stale)
	ns.On("QUEST_TURNED_IN", Stale)
	ns.On("PLAYER_LEVEL_UP", Stale)

	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.MinimapMouseover, function(tooltip, data)
		if tooltip ~= GameTooltip or not ns.Active(KEY) then
			return
		end
		local names = Model.Names(data)
		if #names == 0 then
			return
		end
		local _, x, y = Here()
		local key = table.concat(names, "\n")
			.. ("|%d|%d|%d"):format(generation, math.floor((x or 0) / 10), math.floor((y or 0) / 10))
		if key ~= lastKey then
			lastKey, lastLines = key, Model.TooltipLines(names)
		end
		for _, line in ipairs(lastLines) do
			tooltip:AddLine(line[1], line[2], line[3], line[4])
		end
		if #lastLines > 0 then
			tooltip:Show()
		end
	end)
end)
