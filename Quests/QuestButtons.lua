---@type string, TFNamespace
local _, ns = ...
local L = ns.L

local KEY = "questButtons"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Quest item and target keys",
	tooltip = "Two keys you can bind under Key Bindings > AddOns: one uses the quest item of your nearest quest, "
		.. "the other targets a creature your nearest quest still needs, a different one each press. In combat "
		.. "they keep what they had at your last press before it.",
	default = true,
	conflicts = { { polestar = "qol.itemButton" } },
})

local ITEM, TARGET = "TweaksForeverQuestItemButton", "TweaksForeverQuestTargetButton"
local NAME_FIELDS = { "name" }

BINDING_HEADER_TWEAKSFOREVER = "Tweaks Forever"
_G["BINDING_NAME_CLICK " .. ITEM .. ":LeftButton"] = L["Use the nearest quest item"]
_G["BINDING_NAME_CLICK " .. TARGET .. ":LeftButton"] = L["Target a creature for the nearest quest"]

---@class TFQuestButtons
local Model = {}
ns.QuestButtons = Model

---@class TFQuestEntry
---@field id integer
---@field index integer its place in the quest log
---@field distance number? squared yards, when on this continent

-- The quests in your log, with their log index and distance.
---@return TFQuestEntry[]
function Model.Quests()
	local list = {}
	for index = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(index)
		if info and not info.isHeader and not info.isHidden and info.questID and info.questID ~= 0 then
			local distance, onContinent = C_QuestLog.GetDistanceSqToQuest(info.questID)
			list[#list + 1] = { id = info.questID, index = index, distance = onContinent and distance or nil }
		end
	end
	return list
end

-- The nearest of `quests` that `fits`, and what `fits` returned for it.
---@generic T
---@param quests TFQuestEntry[]
---@param fits fun(quest: TFQuestEntry): T?
---@return T?
function Model.Nearest(quests, fits)
	local best, bestDistance
	for _, quest in ipairs(quests) do
		if quest.distance and (not bestDistance or quest.distance < bestDistance) then
			local value = fits(quest)
			if value then
				best, bestDistance = value, quest.distance
			end
		end
	end
	return best
end

-- The quest item of a quest, as "item:ID".
---@param quest TFQuestEntry
---@return string?
local function QuestItem(quest)
	local link = GetQuestLogSpecialItemInfo(quest.index)
	local id = type(link) == "string" and link:match("item:(%d+)")
	return id and "item:" .. id or nil
end

-- The names of the creatures a quest still needs killed, by QuestieDB, in a stable order.
---@param quest TFQuestEntry
---@return string[]?
local function KillNames(quest)
	local db = ns.QuestieDB()
	if C_QuestLog.IsComplete(quest.id) or not (db and db.Npc and ns.QuestProgress) then
		return nil
	end
	local objectives = C_QuestLog.GetQuestObjectives(quest.id) or {}
	local names, seen = {}, {}
	for position, target in ipairs(ns.QuestProgress.Targets(quest.id)) do
		local objective = objectives[position]
		if target.kind == "monster" and objective and objective.type == "monster" and not objective.finished then
			for npc in pairs(target.npcs) do
				local values = db.Npc.GetAll(npc, NAME_FIELDS)
				local name = values and values[1]
				if type(name) == "string" and not seen[name] then
					seen[name] = true
					names[#names + 1] = name
				end
			end
		end
	end
	table.sort(names)
	return #names > 0 and names or nil
end

-- The next of `names` after `last`, wrapping.
---@param names string[]
---@param last string?
---@return string
function Model.Next(names, last)
	for index, name in ipairs(names) do
		if name == last then
			return names[index % #names + 1]
		end
	end
	return names[1]
end

ns.Init(function()
	-- Our own secure buttons, clicked by their key bindings. Their attributes are set out of combat only, just
	-- before each press, so the item and target are the nearest at that moment.
	local item = CreateFrame("Button", ITEM, UIParent, "SecureActionButtonTemplate")
	item:RegisterForClicks("AnyDown", "AnyUp")
	item:SetAttribute("type", "item")
	local target = CreateFrame("Button", TARGET, UIParent, "SecureActionButtonTemplate")
	target:RegisterForClicks("AnyDown", "AnyUp")
	target:SetAttribute("type", "macro")
	local lastName

	item:SetScript("PreClick", function(self)
		if InCombatLockdown() then
			return
		end
		local found = ns.Active(KEY) and Model.Nearest(Model.Quests(), QuestItem)
		self:SetAttribute("item", found or nil)
	end)
	target:SetScript("PreClick", function(self)
		if InCombatLockdown() then
			return
		end
		local names = ns.Active(KEY) and Model.Nearest(Model.Quests(), KillNames)
		lastName = names and Model.Next(names, lastName) or nil
		self:SetAttribute("macrotext", lastName and "/targetexact " .. lastName or nil)
	end)
end)
