---@type string, TFNamespace
local _, ns = ...
local L = ns.L

local TOOLTIP, PLATES = "questTooltips", "questPlates"

-- Questie shows its own objectives on tooltips and nameplates while these options of its are on.
---@param option string
---@return fun(): boolean?
local function QuestieOption(option)
	return function()
		local profile = Questie and Questie.db and Questie.db.profile
		return profile and profile[option]
	end
end

-- QuestieDB with the quest and item tables these read, or nil.
---@return TFQuestieDB?
local function Library()
	local db = ns.QuestieDB()
	return db and db.Quest and db.Item and db or nil
end
local NEEDS = { title = "QuestieDB", check = Library }

ns.Feature({
	key = TOOLTIP,
	category = "Interface",
	name = "Quest progress on tooltips",
	tooltip = "Pointing at a creature you need for a quest, to kill or for an item it drops, adds the quest and "
		.. 'your progress to its tooltip, such as "Mangy Wolf slain: 3/10", in white until it is done and grey '
		.. "after. Quest items and objects you need show their quest the same way, and an item that starts a quest "
		.. "says so. Needs Questie, or its QuestieDB addon on its own.",
	default = true,
	conflicts = {
		{ addon = "Questie", when = QuestieOption("enableTooltips") },
		-- Polestar draws these only once its load-on-demand quest database is in.
		{ addon = "Polestar_QuestDB", polestar = "qol.questTooltips" },
	},
	needs = NEEDS,
})

ns.Feature({
	key = PLATES,
	category = "Interface",
	name = "Quest icons on nameplates",
	tooltip = "A small quest icon sits beside the nameplate of each creature you still need for a quest in your "
		.. "log, to kill or for an item it drops, and goes once you have enough. Needs Questie, or its QuestieDB addon "
		.. "on its own.",
	default = true,
	conflicts = {
		{ addon = "Questie", when = QuestieOption("nameplateEnabled") },
		{ addon = "Polestar_QuestDB", polestar = "qol.nameplateIcons" },
	},
	needs = NEEDS,
})

-- Your quests, their objectives and your progress are the quest log's, read by quest ID and objective position; a
-- creature is known by the ID in its GUID. Which creatures count toward an objective is QuestieDB's, read at runtime:
-- kills, kill credit and the creatures that drop a quest's items. QuestieDB lists a quest's objectives by kind, and
-- Questie maps that list onto the log's by position, moving a kind to the front for the quests it marks: the same
-- here. The log names each objective's kind, so a position whose kind disagrees is left out rather than guessed.
local QUEST_FIELDS = { "objectives", "triggerEnd" }
local ITEM_FIELDS = { "npcDrops" }
local START_FIELDS = { "startQuest" }
local NAME_FIELDS = { "name" }
-- QuestieDB's objective groups in its order, with the kind the log gives each and its ObjectiveFirst hint.
local GROUPS = {
	{ slot = 1, kind = "monster" },
	{ slot = 2, kind = "object", first = "objectObjectiveFirst" },
	{ slot = 3, kind = "item", first = "itemObjectiveFirst" },
	{ slot = 4, kind = "reputation", single = true },
	{ slot = 5, kind = "monster", first = "killCreditObjectiveFirst", credit = true },
	{ slot = 6, kind = "spell", first = "spellObjectiveFirst" },
}
-- The stock objective marker, this big and this far right of the health bar.
local ICON, SIZE, GAP = "questobjective", 20, 4

---@class TFQuestProgress
local Model = {}
ns.QuestProgress = Model

-- QuestieDB's quests and items, and its hints for the quests that list one kind of objective first.
local quests, items ---@type TFQuestieEntity?, TFQuestieEntity?
---@type table<string, table<integer, true>>
local hints = {}
-- [questID] = its objectives in the log's order by QuestieDB, each { kind, npcs = set of creature IDs }, read once.
---@type table<integer, TFQuestTarget[]>
local targets = {}
-- [creature ID] = [questID] = which of that quest's objectives it counts for; the same for items and objects.
---@type table<integer, table<integer, TFQuestLink>>
local byNpc, byItem, byObject = {}, {}, {}
-- The quests in your log, in its order, with their objectives as of its last change.
---@type TFLogQuest[]
local logQuests = {}

-- Read QuestieDB, when it is installed.
---@return boolean
function Model.Attach()
	targets = {}
	quests, items, hints = nil, nil, {}
	local db = Library()
	if not db then
		return false
	end
	quests, items, hints = db.Quest, db.Item, db.ObjectiveFirst or {}
	return true
end

-- The object ID in a game object's GUID, or nil for anything else or a GUID addon code can't read.
---@param guid any
---@return integer?
function Model.ObjectId(guid)
	if not canaccessvalue(guid) or type(guid) ~= "string" then
		return nil
	end
	local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$")
	if kind == "GameObject" then
		return tonumber(id)
	end
end

-- The creature ID in a unit's GUID, or nil for a player, an object or a GUID addon code can't read.
---@param guid any
---@return integer?
function Model.NpcId(guid)
	if not canaccessvalue(guid) or type(guid) ~= "string" then
		return nil
	end
	local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$")
	if kind == "Creature" or kind == "Vehicle" then
		return tonumber(id)
	end
end

---@param npcs table<integer, true>
---@param list any
local function AddAll(npcs, list)
	for _, id in ipairs(type(list) == "table" and list or {}) do
		npcs[id] = true
	end
end

-- The creatures that count toward one QuestieDB objective entry.
---@param group table
---@param entry any
---@return table<integer, true>
local function Npcs(group, entry)
	local npcs = {}
	if type(entry) ~= "table" then
		return npcs
	end
	if group.credit then
		AddAll(npcs, entry[1])
		if type(entry[2]) == "number" and entry[2] ~= 0 then
			npcs[entry[2]] = true
		end
	elseif group.slot == 1 then
		npcs[entry[1]] = true
	elseif group.slot == 3 and items then
		local values = items.GetAll(entry[1], ITEM_FIELDS)
		AddAll(npcs, values and values[1])
	end
	return npcs
end

-- A quest's objectives in the order the log lists them; none without QuestieDB.
---@param id integer
---@return TFQuestTarget[]
function Model.Targets(id)
	if targets[id] then
		return targets[id]
	end
	local values = quests and quests.GetAll(id, QUEST_FIELDS) or {}
	local objectives = values[1]
	local list = {}
	if type(objectives) == "table" then
		for _, group in ipairs(GROUPS) do
			local entries = objectives[group.slot]
			if group.single then
				entries = type(entries) == "table" and entries[1] ~= nil and { entries } or nil
			end
			local first = group.first and hints[group.first] and hints[group.first][id]
			for _, entry in ipairs(type(entries) == "table" and entries or {}) do
				local target = { kind = group.kind, npcs = Npcs(group, entry), items = {}, objects = {} }
				local thing = type(entry) == "table" and entry[1]
				if group.slot == 3 and type(thing) == "number" then
					target.items[thing] = true
				elseif group.slot == 2 and type(thing) == "number" then
					target.objects[thing] = true
				end
				if first then
					table.insert(list, 1, target)
				else
					list[#list + 1] = target
				end
			end
		end
		if values[2] ~= nil then
			local event = { kind = "event", npcs = {}, items = {}, objects = {} }
			if hints.eventObjectiveFirst and hints.eventObjectiveFirst[id] then
				table.insert(list, 1, event)
			else
				list[#list + 1] = event
			end
		end
	end
	targets[id] = list
	return list
end

---@param index table<integer, table<integer, TFQuestLink>>
---@param ids table<integer, true>
---@param quest integer
---@param position integer
---@param kind string
local function Link(index, ids, quest, position, kind)
	for id in pairs(ids) do
		index[id] = index[id] or {}
		local link = index[id][quest] or {}
		index[id][quest] = link
		link[position] = kind
	end
end

-- Read your quest log, and index its quests by the creatures, items and objects that count toward them.
function Model.Rebuild()
	logQuests, byNpc, byItem, byObject = {}, {}, {}, {}
	for index = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(index)
		if info and not info.isHeader and not info.isHidden and info.questID and info.questID ~= 0 then
			local id = info.questID
			logQuests[#logQuests + 1] = {
				id = id,
				title = info.title,
				complete = C_QuestLog.IsComplete(id),
				objectives = C_QuestLog.GetQuestObjectives(id) or {},
			}
			for position, target in ipairs(Model.Targets(id)) do
				Link(byNpc, target.npcs, id, position, target.kind)
				Link(byItem, target.items, id, position, target.kind)
				Link(byObject, target.objects, id, position, target.kind)
			end
		end
	end
end

local indexes = {
	npc = function()
		return byNpc
	end,
	item = function()
		return byItem
	end,
	object = function()
		return byObject
	end,
}

-- The quests in your log a creature (or, by `kind`, an item or object) counts for, each with the objectives it
-- counts for, in log order.
---@param id integer?
---@param kind? "npc"|"item"|"object"
---@return TFQuestMatch[]
function Model.Matches(id, kind)
	local index = indexes[kind or "npc"]()
	local links = id and index[id] or {}
	local matches = {}
	for _, quest in ipairs(logQuests) do
		local link = links[quest.id]
		local found = {}
		for position, objective in ipairs(link and quest.objectives or {}) do
			if objective.text and objective.text ~= "" and link[position] == objective.type then
				found[#found + 1] = objective
			end
		end
		if #found > 0 then
			matches[#matches + 1] = { quest = quest, objectives = found }
		end
	end
	return matches
end

-- A creature's tooltip lines (or an item's or object's, by `kind`): each quest's title, then its objectives this one
-- counts for, white until done.
---@param id integer?
---@param kind? "npc"|"item"|"object"
---@return [string, number, number, number][]
function Model.Lines(id, kind)
	local lines = {}
	for _, match in ipairs(Model.Matches(id, kind)) do
		local title = NORMAL_FONT_COLOR
		lines[#lines + 1] = { ns.QuestTitle(match.quest.id, match.quest.title), title.r, title.g, title.b }
		for _, objective in ipairs(match.objectives) do
			local color = objective.finished and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR
			lines[#lines + 1] = { " - " .. objective.text, color.r, color.g, color.b }
		end
	end
	return lines
end

-- The quest an item starts, by QuestieDB, while it is neither in your log nor done: its line for the tooltip.
---@param item integer?
---@return string?
function Model.Starts(item)
	local values = item and items and items.GetAll(item, START_FIELDS)
	local quest = values and values[1]
	if type(quest) ~= "number" or quest == 0 or C_QuestLog.IsQuestFlaggedCompleted(quest) then
		return nil
	end
	for _, logged in ipairs(logQuests) do
		if logged.id == quest then
			return nil
		end
	end
	local names = quests and quests.GetAll(quest, NAME_FIELDS)
	local name = names and names[1]
	return L["Starts a quest: %s"]:format(type(name) == "string" and name or tostring(quest))
end

-- Whether a creature still counts toward a quest in your log that isn't complete.
---@param npc integer?
---@return boolean
function Model.Needed(npc)
	for _, match in ipairs(Model.Matches(npc)) do
		if not match.quest.complete then
			for _, objective in ipairs(match.objectives) do
				if not objective.finished then
					return true
				end
			end
		end
	end
	return false
end

-- Whether the game has already put quest lines in a tooltip.
---@param data TooltipData
---@return boolean
function Model.HasQuestLines(data)
	local types = Enum.TooltipDataLineType
	for _, line in ipairs(data.lines or {}) do
		if line.type == types.QuestObjective or line.type == types.QuestTitle then
			return true
		end
	end
	return false
end

-- One quest icon per nameplate, on a frame of our own parented to the plate, right of Blizzard's health bar; the
-- raid mark and elite dragon sit to its left. Nothing is written into Blizzard's frames.
local function Plates()
	---@type table<NamePlateFrame, Texture>
	local icons = setmetatable({}, { __mode = "k" })
	-- [unit token] = its nameplate, while it has one.
	---@type table<string, NamePlateFrame>
	local shown = {}

	---@param plate NamePlateFrame
	---@return Texture
	local function Icon(plate)
		local icon = icons[plate]
		if not icon then
			local holder = CreateFrame("Frame", nil, plate)
			holder:SetSize(SIZE, SIZE)
			local anchor = plate.UnitFrame and plate.UnitFrame.HealthBarsContainer or plate
			holder:SetPoint("LEFT", anchor, "RIGHT", GAP, 0)
			icon = holder:CreateTexture(nil, "OVERLAY")
			ns.Art.Fit(icon, ICON, SIZE, SIZE)
			icon:SetPoint("CENTER")
			icons[plate] = icon
		end
		return icon
	end

	---@param unit string
	local function Update(unit)
		local plate = shown[unit]
		if not plate then
			return
		end
		local need = ns.Active(PLATES) and Model.Needed(Model.NpcId(UnitGUID(unit)))
		if need then
			Icon(plate):Show()
		elseif icons[plate] then
			icons[plate]:Hide()
		end
	end

	local function UpdateAll()
		for unit in pairs(shown) do
			Update(unit)
		end
	end

	ns.On("NAME_PLATE_UNIT_ADDED", function(unit)
		-- A forbidden plate (a friendly one in an instance) is never handed to addon code.
		shown[unit] = C_NamePlate.GetNamePlateForUnit(unit)
		Update(unit)
	end)
	ns.On("NAME_PLATE_UNIT_REMOVED", function(unit)
		local plate = shown[unit]
		if plate and icons[plate] then
			icons[plate]:Hide()
		end
		shown[unit] = nil
	end)
	-- Plates already up before login, as after a reload.
	for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
		local unit = plate.UnitFrame and plate.UnitFrame.unit
		if unit then
			shown[unit] = plate
		end
	end
	return UpdateAll
end

ns.Init(function()
	if not Model.Attach() then
		return
	end
	local UpdatePlates = Plates()

	-- Progress changes arrive as several events in one frame: rebuild once, on the next.
	local pending = false
	local function Changed()
		if pending then
			return
		end
		pending = true
		C_Timer.After(0, function()
			pending = false
			Model.Rebuild()
			UpdatePlates()
		end)
	end
	ns.On("QUEST_LOG_UPDATE", Changed)
	ns.On("UNIT_QUEST_LOG_CHANGED", function(unit)
		if unit == "player" then
			Changed()
		end
	end)
	ns.OnSettingChanged(PLATES, UpdatePlates)
	Model.Rebuild()
	UpdatePlates()

	---@param tooltip GameTooltip
	---@param data TooltipData
	---@return boolean
	local function Wanted(tooltip, data)
		return tooltip == GameTooltip and ns.Usable(tooltip) and ns.Active(TOOLTIP) and not Model.HasQuestLines(data)
	end
	---@param tooltip GameTooltip
	---@param lines [string, number, number, number][]
	local function Add(tooltip, lines)
		for _, line in ipairs(lines) do
			tooltip:AddLine(line[1], line[2], line[3], line[4])
		end
		if #lines > 0 then
			tooltip:Show()
		end
	end
	local types = Enum.TooltipDataType
	TooltipDataProcessor.AddTooltipPostCall(types.Unit, function(tooltip, data)
		if not ns.Usable(tooltip) then
			return
		end
		if Wanted(tooltip, data) then
			Add(tooltip, Model.Lines(Model.NpcId(data.guid)))
		end
	end)
	TooltipDataProcessor.AddTooltipPostCall(types.Item, function(tooltip, data)
		if not ns.Usable(tooltip) or not Wanted(tooltip, data) then
			return
		end
		local item = ns.Readable(data.id)
		local lines = Model.Lines(type(item) == "number" and item or nil, "item")
		local starts = type(item) == "number" and Model.Starts(item)
		if starts then
			local color = NORMAL_FONT_COLOR
			lines[#lines + 1] = { starts, color.r, color.g, color.b }
		end
		Add(tooltip, lines)
	end)
	-- World objects (a chest, a shrine) where the client sends their tooltips this way.
	if types.Object then
		TooltipDataProcessor.AddTooltipPostCall(types.Object, function(tooltip, data)
			if not ns.Usable(tooltip) then
				return
			end
			if Wanted(tooltip, data) then
				Add(tooltip, Model.Lines(Model.ObjectId(ns.Readable(data.guid)), "object"))
			end
		end)
	end
end)
