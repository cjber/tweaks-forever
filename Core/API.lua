---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end
local L = ns.L

-- Public addon-to-addon interface. It answers with the facts whether or not the spellbook shows Future Spells: a
-- caller such as Adventure Guide Forever plans a trainer visit from them, and turning the display off shouldn't
-- hide the visit. Trainer rows are recorded only while the feature is on, so with it off the answer is the baked
-- list's. A read with nothing to answer returns nil and a reason from ForeverCore.APIKit.NotReady, so a caller can
-- tell "ask again later" from "there is nothing to ask about"; docs/api.md lists which reason each read returns.
--
-- Trainers() needs version 2 or later. TrainableSpells() and DungeonEntrance() are there from version 1 and behave
-- the same in every version, so a caller checks version only before Trainers(). From version 3 a trainer's name and
-- place are QuestieDB's, so either can be missing, and Trainers() returns a second value. `minor` rises with each
-- addition within version 3 (1: each read's not-ready reason); a caller checks a member before using it.
---@class TFPublicAPI
local API = { version = 3, minor = 1 }

-- The shared shape every Forever addon's API follows: the not-ready answer a read gives while there is nothing to
-- answer (ForeverCore's docs/api-conventions.md). Core/Require.lua stops the addon before this file on an older
-- ForeverCore, so the kit is always here.
local APIKit = assert(ForeverCore.APIKit)

-- A read with nothing to answer, as the kit builds it: `nil, reason`. docs/api.md lists which reasons each read can
-- return, so a caller can tell "ask again later" from "there is nothing to ask about".
---@param reason TFAPIReason
---@return nil, TFAPIReason
local function NotReady(reason)
	local _, answer = APIKit.NotReady(reason)
	return nil, answer --[[@as TFAPIReason]]
end

---@return TFAPITrainableSpell[]?
---@return TFAPIReason?
function API.TrainableSpells()
	if not ns.db or InCombatLockdown() then
		return NotReady("loading")
	end
	local trainable = {}
	for _, entry in ipairs(ns.FutureSpells.Choose(ns.TrainerSpells(), nil, UnitLevel("player"), ns.KnownSpell)) do
		if entry.ready then
			local spell = entry.spell
			local lineID = spell.lineID --[[@as integer]] -- Choose lists only rows with a line
			trainable[#trainable + 1] = {
				spellID = entry.id,
				name = spell.name,
				level = spell.level,
				cost = spell.cost,
				line = spell.general and ns.GeneralName() or ns.LineName(lineID, spell.line),
				lineID = lineID,
				general = spell.general == true,
			}
		end
	end
	return trainable
end

-- The class trainers to visit, for the player's class, and where one of each stands. Which NPCs train a class is
-- baked, so every trainer is listed before login, in combat and with the spellbook's Future Spells off; an unknown
-- or unplayable class has none. A trainer's name and place are read from the installed QuestieDB a little each
-- frame, so they fill in over the first moments after login: ask again later. Without a QuestieDB to read, the
-- second value is a line for the player saying what to install. It always answers a table, so it has no not-ready
-- reason.
---@return TFAPITrainer[]
---@return string? install
function API.Trainers()
	local _, class = UnitClass("player")
	local baked = ns.ClassSpells[class]
	local trainers = {}
	if not baked then
		return trainers
	end
	local places, state = ns.QuestieSource.Places(baked.trainers)
	for _, npc in ipairs(baked.trainers) do
		local place = places[npc]
		trainers[#trainers + 1] = place and { npc = npc, name = place.name, map = place.map, x = place.x, y = place.y }
			or { npc = npc }
	end
	if state == "absent" then
		return trainers, L["Install Questie, or its QuestieDB addon on its own, to see where your class trainers are."]
	end
	return trainers
end

-- An instance's own door, never a merged pin's centre: Blackrock Mountain draws one pin for four doors, and a caller
-- routing to Blackwing Lair wants its own. Baked, so it answers with pins off or suppressed, before login and in
-- combat; an instance with no entrance in the client has nothing to answer.
---@param instanceID integer
---@return TFDungeonEntrance?
---@return TFAPIReason?
function API.DungeonEntrance(instanceID)
	local entrance = ns.InstanceEntrances[instanceID]
	if entrance then
		return { map = entrance.map, x = entrance.x, y = entrance.y }
	end
	return NotReady("none")
end

TweaksForever = TweaksForever or {}
TweaksForever.API = API

-- Books the read of the player's own trainers at login, so the first caller usually finds them placed.
ns.Init(API.Trainers)
