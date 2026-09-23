---@meta

-- Public addon-to-addon interface.
---@class TFAPITrainableSpell
---@field spellID integer the spell you learn
---@field name string
---@field level integer the level the trainer teaches it from
---@field cost? integer the training fee in copper, when known
---@field line string the class skill line (spellbook tab) it goes on

---@class TFPublicAPI
---@field version integer 1
---@field TrainableSpells fun(): TFAPITrainableSpell[] spells your level allows that you haven't learned, each spell's next rank only, in fresh tables; answers whether or not the spellbook shows them

---@class TFPublicAddon
---@field API TFPublicAPI
TweaksForever = {}
