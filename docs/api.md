# TweaksForever.API

Other addons can read Tweaks Forever's class trainer spells, the class trainers to visit and a dungeon or raid
entrance through the global `TweaksForever.API`, and hear about the moments it watches through `Subscribe()`. It is
version 3, minor 2: check `version == 3` and that each function exists before calling it. The full types are in
[`types/API.lua`](../types/API.lua). On ForeverCore 1.3.2 or later, the API is also listed by
`ForeverCore.APIKit.Addons()`.

Every read that answers with a table returns a fresh one that you may keep or change. Trainer names and places, and
entrance places, use UiMapIDs and coordinates from 0 to 1.

## Published functions

`TrainableSpells()`, `Trainers()`, `DungeonEntrance(instanceID)`, `Subscribe(callback)`, `IsJunk(itemID)`,
`JunkMarks()`, `BestReward()`, `ZoneLevels(map)`, `XPRate()`, `LastRare()` and `Unexplored(map)`, each described
below.

## Minor history

`version` changes only when a published member breaks. Additions keep it and raise `minor`, so a caller checks the
member it wants with `type(api.Name) == "function"`.

- minor 0: version 3's first members, `TrainableSpells()`, `Trainers()` and `DungeonEntrance(instanceID)`, which
  shipped before minors were counted. Version 1 had `TrainableSpells()` and `DungeonEntrance(instanceID)`; version 2
  added `Trainers()`; version 3 made a trainer's name and place QuestieDB's, so either can be missing and `Trainers()`
  returns a second value.
- minor 1: each read that has nothing to answer returns a second value, the reason, through
  `ForeverCore.APIKit.NotReady`.
- minor 2: `Subscribe()` (change names `trainable`, `junk`, `rare` and `explored`), `IsJunk(itemID)`, `JunkMarks()`,
  `BestReward()`, `ZoneLevels(map)`, `XPRate()`, `LastRare()` and `Unexplored(map)`. Version stays 3.

## Not ready

A read that has nothing to answer returns `nil, reason`, as `ForeverCore.APIKit.NotReady` builds it. The reason says
whether to ask again. `nil` alone still means the same to callers written before minor 1: the first value is
unchanged.

| reason | meaning |
|---|---|
| `"loading"` | Tweaks Forever is still reading the game, so ask again later |
| `"disabled"` | the player turned the feature off |
| `"none"` | there is nothing to answer, such as an instance with no entrance |
| `"invalid"` | the argument is not one the read takes, such as a non-integer item or map ID |

`TrainableSpells()` answers `nil, "loading"` before login, while the spellbook is not known yet, and in combat, when
the work waits. It never answers `"disabled"` or `"none"`: it answers whether or not the spellbook's Future Spells
display is on, and a class with nothing to learn answers `{}`. `DungeonEntrance(instanceID)` answers `nil, "none"` for
an instance the client has no entrance for, or one that has none. `Trainers()` always answers a table, so it has no
not-ready reason; a trainer QuestieDB has not placed yet simply has no name, `map`, `x` or `y`.

## `Subscribe(callback) -> unsubscribe`

`callback(changes)` runs on the frame after a change, never inside the call that caused it. One burst sends at most
one call, however many changes it holds, and `changes` is a fresh table each time with only the names that changed
set to `true`. Read the API again rather than replaying the change. A callback added by a callback waits for the next
burst, each callback runs under the addon's own error guard, and the returned unsubscribe function is safe to call
twice. The first subscriber takes the channels' current answers as its baseline, so it hears only later changes.

The change names:

| name | true when |
|---|---|
| `trainable` | the answer `TrainableSpells()` gives changed, by its sorted spell IDs: a level up, or a spell learned |
| `junk` | a junk mark was added or removed, by Alt+Right-click, the bag portrait menu or the click mode |
| `rare` | a rare alert fired and printed its chat line |
| `explored` | the player explored a new area, from the client's `MAP_EXPLORATION_UPDATED` |

An event that changes nothing stays quiet. In particular `trainable` compares the sorted spell IDs, so a level up
that brings no new spell sends nothing, and entering combat is not itself a change. A spell learned during combat is
heard when combat ends, once the read can answer again.

```lua
local unsubscribe = TweaksForever.API.Subscribe(function(changes)
	if changes.junk then
		RedrawBagMarks()
	end
end)
```

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

## `IsJunk(itemID) -> boolean?, TFAPIReason?`

Whether the player marked the item as junk, account-wide, as a boolean. This is their own mark, not a grey: greys
are junk to the game's own Sell All Junk, and a bag addon should keep treating poor quality as junk itself. The mark
is the one the bag's coin is drawn from, so the answer does not depend on the bag frames being open.

It answers `nil, "loading"` before login, `nil, "disabled"` while Mark items as junk is off (there are no marks to
read then), and `nil, "invalid"` for an item ID that is not an integer.

## `JunkMarks() -> integer[]?, TFAPIReason?`

Every item ID the player marked as junk, in a fresh sorted list, for a bag addon that draws the marks itself. Greys
are not in it, for the same reason as `IsJunk`. The not-ready reasons are the same: `nil, "loading"` before login,
`nil, "disabled"` while Mark items as junk is off.

## `BestReward() -> integer?, TFAPIReason?`

The index, among the quest reward choices on the panel now on screen, of the choice that sells to a merchant for
strictly the most. It is the choice the gold coin marks, and it is not chosen for the player. It answers whether or
not Mark the best-selling quest reward is on.

It returns `nil, "loading"` while a choice's price is unknown, and `nil, "none"` when no reward panel is open, the
quest offers fewer than two choices, or the top value is a tie or nothing worth selling.

## `ZoneLevels(map) -> TFAPILevelRange?, TFAPIReason?`

A zone's level range as a fresh `{low, high}`, from the client where it has one and from Tweaks Forever's data
otherwise. `map` is a UiMapID, or `nil` for the zone the player is in. It answers whether or not Zone level ranges on
the map is on.

It returns `nil, "none"` for a map with no range, such as a city or an instance, and `nil, "invalid"` for a map ID
that is not an integer.

## `XPRate() -> TFAPIXPRate?, TFAPIReason?`

The player's XP per hour over the last 15 minutes as a fresh `{perHour, toLevel}`, the same figures the experience
bar's tooltip shows. `toLevel` is the seconds to the next level at that pace, and it is missing while the rate is
zero.

It returns `nil, "loading"` before login and in the first five minutes of a session, and `nil, "disabled"` while XP
per hour on the experience bar is off: XP is only counted while that feature runs.

## `LastRare() -> TFAPIRare?, TFAPIReason?`

The most recent rare alert as a fresh `{name, map, x, y}`: the creature's name, and its map marker's current position
as a UiMapID and 0 to 1 coordinates while the marker is still up, else where it last was.

It returns `nil, "none"` when no rare has alerted since login, `nil, "disabled"` while Rare alerts is off, and
`nil, "loading"` before login.

## `Unexplored(map) -> TFAPIUnexploredArea[]?, TFAPIReason?`

A zone map's unexplored areas as fresh `{left, top, right, bottom}` rectangles in the same 0 to 1 coordinates as a
map position, for an addon that draws its own reveal. They come from the same decoded overlay data the dim tint draws,
with the client's explored textures removed. `map` is a UiMapID, or `nil` for the zone the player is in. It answers
whether or not Reveal unexplored areas is on.

It returns `nil, "none"` for a map that is not a zone or whose art has no overlay data, and `nil, "invalid"` for a
map ID that is not an integer. A zone whose every area is explored answers `{}`.
