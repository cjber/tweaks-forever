---@type string, TFNamespace
local _, ns = ...

-- Public addon-to-addon interface. It answers with the facts whether or not the spellbook shows Future Spells: a
-- caller such as Adventure Guide Forever plans a trainer visit from them, and turning the display off shouldn't
-- hide the visit. Trainer rows are recorded only while the feature is on, so with it off the answer is the baked
-- list's. As with Shortest Path Forever's API, nil means ask again later: before login the spellbook isn't known
-- yet, so every rank would look unlearned, and in combat the work waits.
--
-- v2 adds Trainers(), the class trainers to visit and where they stand, which is baked so it answers before login
-- and in combat. v1's members keep their behavior, so a caller that checks version still gets both.
---@class TFPublicAPI
local API = { version = 2 }

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

-- The class trainers to visit and where one of each stands, for the player's class. Baked from the class
-- trainer data, so it answers before login, in combat and with the spellbook's Future Spells off. An unknown or
-- unplayable class has none; a trainer the dump places nowhere keeps its npc and name and no map.
---@return TFAPITrainer[]
function API.Trainers()
	local _, class = UnitClass("player")
	local baked = ns.ClassSpells[class]
	local trainers = {}
	if not baked then
		return trainers
	end
	for _, row in ipairs(baked.trainers or {}) do
		local trainer = { npc = row[1], name = row[2] }
		if row[3] then
			trainer.map, trainer.x, trainer.y = row[3], row[4], row[5]
		end
		trainers[#trainers + 1] = trainer
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
