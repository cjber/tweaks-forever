<p align="center"><img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/media/icon-400.png" width="96" alt=""></p>

<h1 align="center">Tweaks Forever</h1>

<p align="center">
Small quality-of-life tweaks for WoW: Forever that look like they came with the game.<br>
<a href="https://github.com/cjber/tweaks-forever/actions/workflows/ci.yml"><img src="https://github.com/cjber/tweaks-forever/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<a href="https://github.com/cjber/tweaks-forever/releases/latest"><img src="https://img.shields.io/github/v/release/cjber/tweaks-forever" alt="Latest release"></a>
</p>

I wanted the handful of little addons I always install in one place, looking like they came with the game. Tweaks Forever is quest and gossip automation, repairs, junk selling, gear groups, map extras, movable windows, tooltips, nameplates and fishing, as checkboxes in the game's own settings. Moving windows is a tab in Edit Mode, and the map uses retail's own dungeon icons.

When another addon already does one of these jobs, that feature is greyed out and its tooltip names the addon, so the two never fight.

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/demo.gif" width="760" alt="Dungeon entrances, nameplates and a junk coin">
</p>

<p align="center">Dungeon entrances on the map, nameplates, and the junk coin in your bags.</p>

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/dungeonmap.png" width="768" alt="The world map inside Blackfathom Deeps, showing the dungeon's floor and legend">
</p>

<p align="center">Inside a dungeon the map opens on its own floor, with the legend beside it and a button for each floor.</p>

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/dungeons.png" width="768" alt="The Eastern Kingdoms with a dungeon icon at every entrance">
</p>

<p align="center">Every dungeon and raid entrance, with retail's icons. Blackrock Mountain lists all four.</p>

## Features

Every feature has its own setting; [docs/features.md](docs/features.md) has the detail.

- **Quests.** Quest levels on map tooltips and the tracker, a gold tint on quests added in Forever, **Abandon quests** with one confirmation, and the tracker sorted nearest first with distances.
- **Automation.** Accepts and turns in quests, skips one-option gossip, opens the flight map, accepts summons and group resurrections, releases in battlegrounds and declines duels. Hold Shift to talk normally. Off until you turn it on, as are invites from a whispered keyword and skipping loot confirmations.
- **Faster auto loot.** Takes everything at once instead of waiting for the loot window.
- **Repairs and junk.** Repairs at any merchant, from guild funds when allowed, and sells grey junk through the game's own Sell All Junk, plus up to 12 marked stacks per visit. Everything stays in buyback. **Alt+Right-click** marks an item with the game's junk coin when *Mark items as junk* is on.
- **Gear groups.** **Ctrl+Right-click** a bag item to put it in a named, coloured group, then equip the whole group in one click. Each item shows a coloured strip, border or dots. A fishing pole keeps the weapons it replaced as a **Before fishing** group.
- **Map extras.** Unexplored areas in a blue tint (off until you turn it on), each zone's level range coloured like quest levels, and every dungeon and raid entrance marked with retail's icons.
- **Dungeon maps.** Inside a dungeon, the world map opens on the dungeon's own floor map and legend, with a button for the floor and a Back to map button. Needs [Atlas](https://www.curseforge.com/wow/addons/atlas) and its Classic WoW maps, read from your install.
- **Movable windows.** A **Windows** tab in Edit Mode moves and scales 21 Blizzard windows, per layout.
- **Nameplates.** A taller bar in retail's own frame, name and level above, your target outlined, and cast bars with the spell's icon.
- **Spell reach.** A small icon for each attack you track on every enemy nameplate: full colour in reach, solid red out of it. Off until you turn it on.
- **Tooltips.** A thin rounded border over charcoal, class-coloured names and a health bar inside. The style is charcoal, retail's navy, or the game's own border.
- **Questie extras.** Needs [Questie](https://www.curseforge.com/wow/addons/questie) or its QuestieDB addon. Quests listed when you point at a minimap giver, your progress in a creature's tooltip with a quest icon by its nameplate, and Questie's markers in the game's own quest symbols.
- **Camps.** Camp tooltips say what sitting nearby gives you, and each benefit you gain is named on screen.
- **Spellbook and bags.** Each spellbook tab ends with the spells you have not learned yet. With Combine Bags on, the reagent bag joins the combined bag.
- **Train all.** A button beside the class trainer's Train button buys every spell you can afford. Off until you turn it on.
- **Auction house.** A sortable **iLvl** column for weapons and armour.
- **Fishing.** Double right-click to cast, apply the best lure you have, and a warning when you have none.
- **Small things.** Quiet repeated macro errors, companion hints in tooltips and one line in chat after an update are on. Hide macro names, maximum camera zoom and no screen glow are off until you turn them on.

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/nameplates.png" width="644" alt="Three enemy nameplates, the target outlined with a Fireball cast">
</p>

<p align="center">Nameplates in retail's own frame, with your target outlined and a quest icon on what you still need.</p>

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/tooltips.png" width="394" alt="An enemy's and a shaman's tooltip with health bars">
</p>

<p align="center">Unit tooltips with the health bar inside, in the retail game's own bar and frame.</p>

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/editmode.png" width="100%" alt="Edit Mode's Windows tab and the Character window's Scale slider">
</p>

<p align="center">Move and scale Blizzard windows from a tab in Edit Mode.</p>

## Install

Download the zip from [Releases](https://github.com/cjber/tweaks-forever/releases) and extract it into `_classic_beta_/Interface/AddOns/`, so you end up with `AddOns/TweaksForever/TweaksForever.toc`. Questie features and Dungeon maps are greyed out until Questie (or QuestieDB) and Atlas [Classic WoW] are installed.

## Usage

- `/tweaks` or `/tweaksforever` opens the settings, also under **Options → AddOns → Tweaks Forever** or from the addon compartment on the minimap.
- `/rl` reloads the interface.

Repairs, selling junk and faster auto loot start on; everything else that acts for you is off until you tick it. Translations are welcome as a pull request or an issue on [GitHub](https://github.com/cjber/tweaks-forever/tree/main/Locales); anything not translated shows in English.

## For addon authors

`TweaksForever.API` (`version = 3`) gives the class trainer spells you can learn, your class's trainers and where they stand, and each dungeon's own entrance. [docs/features.md](docs/features.md#for-addon-authors) has the details.

## Works alongside

A feature steps aside while Leatrix Plus, Leatrix Maps, Mapster, Questie, Legacy Forever, BlizzMove, Peddler, FishingBuddy, a nameplate or tooltip addon such as Plater or ElvUI, or a similar addon already does its job. [docs/features.md](docs/features.md#works-alongside) lists which addon covers which feature. It also works with [Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever): click a dungeon entrance on the map and it plans the way there.

## Development

Developed with AI assistance; changes are reviewed and checked with automated tests, linting and type checks.

```sh
tools/typecheck.sh                              # LuaLS 3.19.1 + multi-value lint
luacheck . && stylua --check .                  # lint and format
for spec in tests/*_spec.lua; do luajit "$spec" || exit 1; done
python3 tools/screenshots.py                    # regenerate docs/screenshots from the game's own art
```

[tools/README.md](tools/README.md) covers the `Data/` generators and [AGENTS.md](AGENTS.md) the rest, including releasing and contributing. Report security problems privately, as [SECURITY.md](https://github.com/cjber/.github/blob/main/SECURITY.md) describes.

## Licence

GPL-3.0-or-later. Map overlay, camp benefit, dungeon entrance and new zone level data come from the game's own files via [wago.tools](https://wago.tools); the original zones' level ranges are the original game's, as listed on [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/Zones_by_level_(original)). Class trainer lists come from [CMaNGOS classic-db](https://github.com/cmangos/classic-db) (GPL-3.0).

Made by Cillian Berragan · [cillian.dev](https://cillian.dev) · [GitHub](https://github.com/cjber) · [Twitter](https://twitter.com/cjberragan)
