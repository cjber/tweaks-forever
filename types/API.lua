---@meta

-- TweaksForever.API, version 3, minor 2: the contract other addons read (docs/api.md). Core/API.lua implements it.

-- ForeverCore.APIKit's not-ready reasons. "loading" asks again later, "disabled" is the player's choice, "none" is
-- nothing to answer and "invalid" is a bad argument.
---@alias TFAPIReason "loading"|"disabled"|"none"|"invalid"

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

---@class TFDungeonEntrance
---@field map integer UiMapID
---@field x number 0..1
---@field y number 0..1

---@class TFAPITrainer
---@field npc integer
---@field name? string in the client's language, once QuestieDB has been read
---@field map? integer UiMapID, when QuestieDB places the trainer
---@field x? number 0..1
---@field y? number 0..1

---@class TFAPIChanges
---@field trainable? true TrainableSpells()'s answer changed, by the sorted spell IDs it returns
---@field junk? true a junk mark was added or removed
---@field rare? true a rare alert fired
---@field explored? true the player explored a new area

---@class TFAPILevelRange
---@field low number
---@field high number the top of the zone's range

---@class TFAPIXPRate
---@field perHour number XP per hour over the last 15 minutes
---@field toLevel? number seconds to the next level at that pace, missing while the rate is zero

---@class TFAPIRare
---@field name string
---@field map integer UiMapID
---@field x number 0..1
---@field y number 0..1

---@class TFAPIUnexploredArea
---@field left number 0..1
---@field top number 0..1
---@field right number 0..1
---@field bottom number 0..1

---@class TFPublicAPI
---@field version integer 3
---@field minor integer 2 rises with each addition within version 3
---@field TrainableSpells fun(): TFAPITrainableSpell[]?, TFAPIReason? spells your level allows that you haven't learned, each spell's next rank only, on your class's spellbook tabs and the General tab (no weapon skills or riding), in fresh tables; answers whether or not the spellbook shows them; nil, "loading" before login and in combat
---@field DungeonEntrance fun(instanceID: integer): TFDungeonEntrance?, TFAPIReason? instance Map.ID; fresh copy of its unclustered entrance on the first curated zone map; nil, "none" when unknown or unplaced, independent of pin settings and conflicts
---@field Trainers fun(): TFAPITrainer[], string? every class trainer of your class, with the name and one spawn QuestieDB gives it once read; safe before login and in combat; always a table, so it has no not-ready reason; the second value is a line saying what to install when no QuestieDB can be read
---@field Subscribe fun(callback: fun(changes: TFAPIChanges)): fun() call `callback` the frame after a named change, at most once per burst, with a fresh table of the changed names only; returns an unsubscribe function that is safe to call twice
---@field IsJunk fun(itemID: integer): boolean?, TFAPIReason? the player's own junk mark for the item, never a grey; nil, "disabled" while Mark items as junk is off, nil, "loading" before login, nil, "invalid" for a non-integer itemID
---@field JunkMarks fun(): integer[]?, TFAPIReason? fresh sorted list of the player's junk-marked item IDs, never greys; the same not-ready reasons as IsJunk
---@field BestReward fun(): integer?, TFAPIReason? index of the quest reward choice that sells for strictly the most on the reward panel now on screen; nil, "loading" while a price is unknown, nil, "none" with no panel, fewer than two choices or a tie; answers whether or not the marker is on
---@field ZoneLevels fun(map: integer?): TFAPILevelRange?, TFAPIReason? a zone's level range, `map = nil` for the zone you are in; nil, "none" when it has no range, nil, "invalid" for a non-integer map
---@field XPRate fun(): TFAPIXPRate?, TFAPIReason? XP per hour and seconds to the next level at that pace; nil, "loading" before login and in the first five minutes, nil, "disabled" while XP per hour is off
---@field LastRare fun(): TFAPIRare?, TFAPIReason? the most recent rare alert, at its marker's current position; nil, "none" when none has fired, nil, "disabled" while Rare alerts is off, nil, "loading" before login
---@field Unexplored fun(map: integer?): TFAPIUnexploredArea[]?, TFAPIReason? a zone map's unexplored areas as 0..1 rectangles, `map = nil` for the zone you are in; nil, "none" for a map that is not a zone or has no overlay data, nil, "invalid" for a non-integer map

---@class TFPublicAddon
---@field API TFPublicAPI
TweaksForever = {}
