---@meta

-- Public addon-to-addon interface.
---@class TFAPITrainableSpell
---@field spellID integer the spell you learn
---@field name string
---@field level integer the level the trainer teaches it from
---@field cost? integer the training fee in copper, when known
---@field line string the spellbook tab it goes on, by name in the client's language, for display
---@field lineID integer its skill line's SkillLine ID, the same in every language: compare this, not `line`. Unless
---`general`, that is a class skill line and the tab's own ID
---@field general boolean it goes on the General tab, which has no skill line: `lineID` is then the spell's own (such as
---118 Dual Wield or 95 Defense), not the tab's

---@class TFPublicAPI
---@field version integer 1
---@field TrainableSpells fun(): TFAPITrainableSpell[]? spells your level allows that you haven't learned, each spell's next rank only, on your class's spellbook tabs and the General tab (no weapon skills or riding), in fresh tables; answers whether or not the spellbook shows them; nil before login and in combat

---@class TFPublicAddon
---@field API TFPublicAPI
TweaksForever = {}
