---@type string, TFNamespace
local _, ns = ...

-- Public addon-to-addon interface. It answers with the facts whether or not the spellbook shows Future Spells: a
-- caller such as Adventure Guide Forever plans a trainer visit from them, and turning the display off shouldn't
-- hide the visit. Trainer rows are recorded only while the feature is on, so with it off the answer is the baked
-- list's.
---@class TFPublicAPI
local API = { version = 1 }

function API.TrainableSpells()
	local trainable = {}
	for _, entry in ipairs(ns.FutureSpells.Choose(ns.TrainerSpells(), nil, UnitLevel("player"), ns.KnownSpell)) do
		if entry.ready then
			local spell = entry.spell
			trainable[#trainable + 1] = {
				spellID = entry.id,
				name = spell.name,
				level = spell.level,
				cost = spell.cost,
				line = spell.line,
			}
		end
	end
	return trainable
end

TweaksForever = TweaksForever or {}
TweaksForever.API = API
