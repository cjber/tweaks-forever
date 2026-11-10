# TweaksForever.API

Other addons can read Tweaks Forever's class trainer spells, the class trainers to visit and a dungeon or raid
entrance through the global `TweaksForever.API`. It is version 3, minor 1: check `version == 3` and that each
function exists before calling it. The full types are in [`types/API.lua`](../types/API.lua).

Every call returns fresh tables that you may keep or change. Trainer names and places, and entrance places, use
UiMapIDs and coordinates from 0 to 1.

## Published functions

`TrainableSpells()`, `Trainers()` and `DungeonEntrance(instanceID)`, each described below.

## Minor history

`version` changes only when a published member breaks. Additions keep it and raise `minor`, so a caller checks the
member it wants with `type(api.Name) == "function"`.

- minor 0: version 3's first members, `TrainableSpells()`, `Trainers()` and `DungeonEntrance(instanceID)`, which
  shipped before minors were counted. Version 1 had `TrainableSpells()` and `DungeonEntrance(instanceID)`; version 2
  added `Trainers()`; version 3 made a trainer's name and place QuestieDB's, so either can be missing and `Trainers()`
  returns a second value.
- minor 1: each read that has nothing to answer returns a second value, the reason, through
  `ForeverCore.APIKit.NotReady`.

## Not ready

A read that has nothing to answer returns `nil, reason`, as `ForeverCore.APIKit.NotReady` builds it. The reason says
whether to ask again. `nil` alone still means the same to callers written before minor 1: the first value is
unchanged.

| reason | meaning |
|---|---|
| `"loading"` | Tweaks Forever is still reading the game, so ask again later |
| `"disabled"` | the player turned the feature off |
| `"none"` | there is nothing to answer, such as an instance with no entrance |

`TrainableSpells()` answers `nil, "loading"` before login, while the spellbook is not known yet, and in combat, when
the work waits. It never answers `"disabled"` or `"none"`: it answers whether or not the spellbook's Future Spells
display is on, and a class with nothing to learn answers `{}`. `DungeonEntrance(instanceID)` answers `nil, "none"` for
an instance the client has no entrance for, or one that has none. `Trainers()` always answers a table, so it has no
not-ready reason; a trainer QuestieDB has not placed yet simply has no name, `map`, `x` or `y`.

## No Subscribe yet

Version 3 minor 1 has no `Subscribe()`. Read a function again when you need a fresh answer; a later minor will add
`Subscribe()` through `ForeverCore.APIKit.Hub` and list its change names here. Until then there are no change names.

## `TrainableSpells() -> TFAPITrainableSpell[]?, TFAPIReason?`

The class trainer spells your level allows that you haven't learned, next rank only, without weapon skills or riding,
as fresh `{spellID, name, level, cost, line, lineID, general}` tables. `line` is the spellbook tab's localised name,
`lineID` its SkillLine ID. A General tab spell (Dual Wield, Parry, Plate Mail) has `general` set and its own skill
line as `lineID`. `cost` is missing when the fee isn't known.

It answers whether or not the spellbook shows Future Spells: a caller such as Adventure Guide Forever plans a
trainer visit from it, and turning the display off shouldn't hide the visit. Trainer rows are recorded only while
the feature is on, so with it off the answer is the baked list's.

It returns `nil, "loading"` before login, while the spellbook isn't known yet, and in combat, when the work waits.
A class with nothing to learn returns `{}`.

## `Trainers() -> TFAPITrainer[], string?`

Your class's trainer NPCs as fresh `{npc, name, map, x, y}` tables: the creature's entry, its name in the client's
language, and where one of it stands as a UiMapID and 0 to 1 coordinates. Every trainer is listed before login and in
combat, and an unknown or unplayable class has none. The name and place are read from the installed
[QuestieDB](https://github.com/Questie/QuestieDB) over the first moments after login, so they can be missing: ask
again later. `map` and the fractions are also missing for a trainer QuestieDB places nowhere.

Without QuestieDB a second value comes back, a line for the player saying what to install. Trainers always answers a
table, so it has no not-ready reason. Versions before 3 always gave a name.

## `DungeonEntrance(instanceID) -> TFDungeonEntrance?, TFAPIReason?`

Takes an instance's Map ID (230 for Blackrock Depths) and returns a fresh `{map, x, y}`: its own entrance as a
UiMapID and 0 to 1 coordinates, not the shared pin for Blackrock Mountain or the Gates of Ahn'Qiraj. It works before
login and in combat, and returns `nil, "none"` for an instance with no entrance in the client, such as Naxxramas, or
one whose entrance the client doesn't place.
