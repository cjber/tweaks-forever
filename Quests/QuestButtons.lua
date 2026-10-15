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
local ITEM_FIELDS = { "sourceItemId", "requiredSourceItems" }

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

-- The nearest of `quests` on this continent that `fits`, and what `fits` returned for it: nearest first, stopping
-- at the first that fits.
---@generic T
---@param quests TFQuestEntry[]
---@param fits fun(quest: TFQuestEntry): T?
---@return T?
function Model.Nearest(quests, fits)
	local near = {}
	for _, quest in ipairs(quests) do
		if quest.distance then
			near[#near + 1] = quest
		end
	end
	table.sort(near, function(a, b)
		return a.distance < b.distance
	end)
	for _, quest in ipairs(near) do
		local value = fits(quest)
		if value then
			return value
		end
	end
end

-- An item you carry that has a use (a spell), as "item:ID".
---@param id any
---@return string?
local function Usable(id)
	if type(id) == "number" and C_Item.GetItemCount(id) > 0 and C_Item.GetItemSpell(id) then
		return "item:" .. id
	end
end

-- The quest item of a quest: the log's own quest item where it has one, else an item QuestieDB says the quest gave
-- you or needs, when you carry it and it can be used.
---@param quest TFQuestEntry
---@return string?
local function QuestItem(quest)
	local link = GetQuestLogSpecialItemInfo(quest.index)
	local id = type(link) == "string" and link:match("item:(%d+)")
	if id then
		return "item:" .. id
	end
	local db = ns.QuestieDB()
	local values = db and db.Quest.GetAll(quest.id, ITEM_FIELDS)
	if not values then
		return nil
	end
	local found = Usable(values[1])
	for _, required in ipairs(type(values[2]) == "table" and values[2] or {}) do
		found = found or Usable(required)
	end
	return found
end

-- [NPC ID] = its QuestieDB name, or false; read once.
---@type table<integer, string|false>
local npcNames = {}

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
				if npcNames[npc] == nil then
					local values = db.Npc.GetAll(npc, NAME_FIELDS)
					local name = values and values[1]
					npcNames[npc] = type(name) == "string" and name or false
				end
				local name = npcNames[npc]
				if name and not seen[name] then
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

	-- A key press clicks twice (down and up) and the secure handler acts on one, as ActionButtonUseKeyDown says;
	-- only that one picks, so the target cycle moves once per press.
	---@param down boolean?
	---@return boolean
	local function Acting(down)
		return not InCombatLockdown() and (not not down) == GetCVarBool("ActionButtonUseKeyDown")
	end
	item:SetScript("PreClick", function(self, _, down)
		if Acting(down) then
			ns.SafeCall("quest item key", function()
				local found = ns.Active(KEY) and Model.Nearest(Model.Quests(), QuestItem)
				self:SetAttribute("item", found or nil)
			end)
		end
	end)
	target:SetScript("PreClick", function(self, _, down)
		if Acting(down) then
			ns.SafeCall("quest target key", function()
				local names = ns.Active(KEY) and Model.Nearest(Model.Quests(), KillNames)
				lastName = names and Model.Next(names, lastName) or nil
				self:SetAttribute("macrotext", lastName and "/targetexact " .. lastName or nil)
			end)
		end
	end)
end)
