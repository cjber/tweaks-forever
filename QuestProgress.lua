---@type string, TFNamespace
local _, ns = ...

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

ns.Feature({
	key = TOOLTIP,
	category = "Interface",
	name = "Quest progress on tooltips",
	tooltip = "Pointing at a creature you need to kill for a quest adds the quest and your progress to its tooltip, "
		.. 'such as "Mangy Wolf slain: 3/10", in white until it is done and grey after. With QuestieDB installed, '
		.. "creatures that drop an item a quest wants count too.",
	default = true,
	conflicts = { { addon = "Questie", when = QuestieOption("enableTooltips") } },
})

ns.Feature({
	key = PLATES,
	category = "Interface",
	name = "Quest icons on nameplates",
	tooltip = "A small quest icon sits beside the nameplate of each creature you still need to kill for a quest in "
		.. "your log, and goes once you have enough. With QuestieDB installed, creatures that drop an item a quest "
		.. "wants get one too.",
	default = true,
	conflicts = { { addon = "Questie", when = QuestieOption("nameplateEnabled") } },
})

-- Your quests, their objectives and your progress are the quest log's. A kill objective whose text is the one the
-- game writes for a creature (QUEST_MONSTERS_KILLED with that creature's name) is that creature's. With QuestieDB
-- installed, its creature and item IDs add what the text can't show: the creatures that drop a quest's items, kill
-- credit and objectives with text of their own. QuestieDB lists a quest's objectives by kind, and Questie maps that
-- list onto the log's by position, moving a kind to the front for the quests it marks: the same here. The log names
-- each objective's kind, so a position whose kind disagrees is left out rather than guessed.
local QUEST_FIELDS = { "objectives", "triggerEnd" }
local ITEM_FIELDS = { "npcDrops" }
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
local quests, items ---@type TFQuestieEntity, TFQuestieEntity
---@type table<string, table<integer, true>>
local hints = {}
-- [questID] = its objectives in the log's order, each { kind, npcs = set of creature IDs that count }, read once.
---@type table<integer, TFQuestTarget[]>
local targets = {}
-- [creature ID] = [questID] = which of that quest's objectives it counts for, by QuestieDB's IDs.
---@type table<integer, table<integer, TFQuestLink>>
local byNpc = {}
-- The quests in your log, in its order, with their objectives as of its last change.
---@type TFLogQuest[]
local logQuests = {}

-- Read QuestieDB as well, when it is installed.
---@return boolean
function Model.Attach()
	targets = {}
	local db = ns.QuestieDB()
	if not db or not db.Quest or not db.Item then
		return false
	end
	quests, items, hints = db.Quest, db.Item, db.ObjectiveFirst or {}
	return true
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
	elseif group.slot == 3 then
		local values = items.GetAll(entry[1], ITEM_FIELDS)
		AddAll(npcs, values and values[1])
	end
	return npcs
end

-- A quest's objectives in the order the log lists them.
---@param id integer
---@return TFQuestTarget[]
function Model.Targets(id)
	if targets[id] then
		return targets[id]
	end
	local values = quests.GetAll(id, QUEST_FIELDS) or {}
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
				local target = { kind = group.kind, npcs = Npcs(group, entry) }
				if first then
					table.insert(list, 1, target)
				else
					list[#list + 1] = target
				end
			end
		end
		if values[2] ~= nil then
			local event = { kind = "event", npcs = {} }
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

-- Read your quest log, and index its quests by the creatures QuestieDB says count toward them.
function Model.Rebuild()
	logQuests, byNpc = {}, {}
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
			for position, target in ipairs(quests and Model.Targets(id) or {}) do
				for npc in pairs(target.npcs) do
					byNpc[npc] = byNpc[npc] or {}
					local link = byNpc[npc][id] or {}
					byNpc[npc][id] = link
					link[position] = target.kind
				end
			end
		end
	end
end

-- The text the game writes for a kill objective with no text of its own, with a creature's name and the counts.
---@param name string
---@param objective QuestObjectiveInfo
---@return string
local function Slain(name, objective)
	local values = { name, objective.numFulfilled, objective.numRequired }
	-- Numbered ("%2$d") in Forever's strings; taken in turn where a locale leaves them unnumbered.
	local turn = 0
	local text = QUEST_MONSTERS_KILLED:gsub("%%(%d*)%$?[sd]", function(n)
		turn = turn + 1
		return tostring(values[tonumber(n) or turn])
	end)
	return text
end

-- Whether a creature counts for the objective at `position` of a quest: QuestieDB's link, or the game's own text.
---@param objective QuestObjectiveInfo
---@param position integer
---@param link TFQuestLink?
---@param name string?
---@return boolean
local function Counts(objective, position, link, name)
	if link and link[position] == objective.type then
		return true
	end
	return name ~= nil and objective.type == "monster" and objective.text == Slain(name, objective)
end

-- The quests in your log a creature counts for, each with the objectives it counts for, in log order. The creature
-- is known by its ID (for QuestieDB) and its name (for the game's own objective text); either may be missing.
---@param npc integer?
---@param name string?
---@return TFQuestMatch[]
function Model.Matches(npc, name)
	local links = npc and byNpc[npc] or {}
	local matches = {}
	for _, quest in ipairs(logQuests) do
		local found = {}
		for position, objective in ipairs(quest.objectives) do
			if objective.text and objective.text ~= "" and Counts(objective, position, links[quest.id], name) then
				found[#found + 1] = objective
			end
		end
		if #found > 0 then
			matches[#matches + 1] = { quest = quest, objectives = found }
		end
	end
	return matches
end

-- A creature's tooltip lines: each quest's title, then its objectives this creature counts for, white until done.
---@param npc integer?
---@param name string?
---@return [string, number, number, number][]
function Model.Lines(npc, name)
	local lines = {}
	for _, match in ipairs(Model.Matches(npc, name)) do
		local title = NORMAL_FONT_COLOR
		lines[#lines + 1] = { match.quest.title, title.r, title.g, title.b }
		for _, objective in ipairs(match.objectives) do
			local color = objective.finished and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR
			lines[#lines + 1] = { " - " .. objective.text, color.r, color.g, color.b }
		end
	end
	return lines
end

-- Whether a creature still counts toward a quest in your log that isn't complete.
---@param npc integer?
---@param name string?
---@return boolean
function Model.Needed(npc, name)
	for _, match in ipairs(Model.Matches(npc, name)) do
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

-- A readable name, or nil for a secret one.
---@param name any
---@return string?
function Model.Name(name)
	if canaccessvalue(name) and type(name) == "string" and name ~= "" then
		return name
	end
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
			icon:SetAtlas(ICON)
			icon:SetAllPoints()
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
		local need = ns.Active(PLATES) and Model.Needed(Model.NpcId(UnitGUID(unit)), Model.Name(UnitName(unit)))
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
	Model.Attach()
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
	Settings.SetOnValueChangedCallback("TweaksForever_" .. PLATES, UpdatePlates)
	Model.Rebuild()
	UpdatePlates()

	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
		if tooltip ~= GameTooltip or not ns.Active(TOOLTIP) or Model.HasQuestLines(data) then
			return
		end
		local first = data.lines and data.lines[1]
		local lines = Model.Lines(Model.NpcId(data.guid), Model.Name(first and first.leftText))
		for _, line in ipairs(lines) do
			tooltip:AddLine(line[1], line[2], line[3], line[4])
		end
		if #lines > 0 then
			tooltip:Show()
		end
	end)
end)
