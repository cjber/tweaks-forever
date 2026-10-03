---@type string, TFNamespace
local _, ns = ...
local L = ns.L

-- Public addon-to-addon interface. It answers with the facts whether or not the spellbook shows Future Spells: a
-- caller such as Adventure Guide Forever plans a trainer visit from them, and turning the display off shouldn't
-- hide the visit. Trainer rows are recorded only while the feature is on, so with it off the answer is the baked
-- list's. As with Shortest Path Forever's API, nil means ask again later: before login the spellbook isn't known
-- yet, so every rank would look unlearned, and in combat the work waits.
--
-- Trainers() needs version 2 or later. TrainableSpells() and DungeonEntrance() are there from version 1 and behave
-- the same in every version, so a caller checks version only before Trainers(). From version 3 a trainer's name and
-- place are QuestieDB's, so either can be missing, and Trainers() returns a second value.
---@class TFPublicAPI
local API = { version = 3 }

function API.TrainableSpells()
	if not ns.db or InCombatLockdown() then
		return nil
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
-- second value is a line for the player saying what to install.
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
-- combat.
function API.DungeonEntrance(instanceID)
	local entrance = ns.InstanceEntrances[instanceID]
	if entrance then
		return { map = entrance.map, x = entrance.x, y = entrance.y }
	end
end

TweaksForever = TweaksForever or {}
TweaksForever.API = API

-- Books the read of the player's own trainers at login, so the first caller usually finds them placed.
ns.Init(API.Trainers)
