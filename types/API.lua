---@meta

-- Public addon-to-addon interface.
---@class TFAPITrainableSpell
---@field spellID integer the spell you learn
---@field name string
---@field level integer the level the trainer teaches it from
---@field cost? integer the training fee in copper, when known
---@field line string the class skill line (spellbook tab) it goes on, by name in the client's language, for display
---@field lineID integer that class skill line's SkillLine ID, the same in every language: compare this, not `line`

---@class TFPublicAPI
---@field version integer 1
---@field TrainableSpells fun(): TFAPITrainableSpell[]? spells your level allows that you haven't learned, each spell's next rank only, on your class's spellbook tabs only (no weapon skills or riding), in fresh tables; answers whether or not the spellbook shows them; nil before login and in combat

---@class TFPublicAddon
---@field API TFPublicAPI
TweaksForever = {}
