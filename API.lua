---@type string, TFNamespace
local _, ns = ...

-- Public addon-to-addon interface. It answers with the facts whether or not the spellbook shows Future Spells: a
-- caller such as Adventure Guide Forever plans a trainer visit from them, and turning the display off shouldn't
-- hide the visit. Trainer rows are recorded only while the feature is on, so with it off the answer is the baked
-- list's. As with Shortest Path Forever's API, nil means ask again later: before login the spellbook isn't known
-- yet, so every rank would look unlearned, and in combat the work waits.
---@class TFPublicAPI
local API = { version = 1 }

function API.TrainableSpells()
	if not ns.db or InCombatLockdown() then
		return nil
	end
	local trainable = {}
	for _, entry in ipairs(ns.FutureSpells.Choose(ns.TrainerSpells(), nil, UnitLevel("player"), ns.KnownSpell)) do
		if entry.ready then
			local spell = entry.spell
			local lineID = spell.lineID --[[@as integer]] -- Choose lists only rows on a class line
			trainable[#trainable + 1] = {
				spellID = entry.id,
				name = spell.name,
				level = spell.level,
				cost = spell.cost,
				line = ns.LineName(lineID, spell.line),
			}
		end
	end
	return trainable
end

TweaksForever = TweaksForever or {}
TweaksForever.API = API
