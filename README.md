<p align="center"><img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/media/icon-400.png" width="96" alt=""></p>

<h1 align="center">Tweaks Forever</h1>

<p align="center">
Small quality-of-life tweaks for WoW: Forever that look like they came with the game.<br>
<a href="https://github.com/cjber/tweaks-forever/actions/workflows/ci.yml"><img src="https://github.com/cjber/tweaks-forever/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<a href="https://github.com/cjber/tweaks-forever/releases/latest"><img src="https://img.shields.io/github/v/release/cjber/tweaks-forever" alt="Latest release"></a>
</p>

I wanted the handful of little addons I always install in one place, looking like they came with the game. Tweaks Forever is quest and gossip automation, repairs, junk selling, gear groups, map extras, movable windows, nameplates and fishing, as checkboxes in the game's own settings. Moving windows is a tab in Edit Mode, and the map uses retail's own dungeon icons. Nothing opens a window of its own.

When another addon already does one of these jobs, that feature is greyed out and its tooltip names the addon, so the two never fight.

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/dungeons.png" width="768" alt="The Eastern Kingdoms map with an icon at every dungeon entrance and Blackrock Mountain's tooltip">
</p>

<p align="center">Every dungeon and raid entrance, with retail's icons. Blackrock Mountain lists all four.</p>

## Features

Every feature has its own checkbox; [docs/features.md](docs/features.md) has the detail.

- **Quest and gossip automation.** Accepts and turns in quests, skips one-option gossip, opens the flight map at a flight master, accepts summons and group resurrections, releases in battlegrounds and declines duels. Hold Shift to talk normally. Off until you turn it on.
- **Faster auto loot.** Takes everything at once instead of waiting for the loot window.
- **Repairs and junk.** Repairs at any merchant, from guild funds when allowed, and sells greys in batches that stay in the buyback tab. **Alt+Right-click** marks any item as junk, with the game's junk coin.
- **Gear groups.** **Ctrl+Right-click** a bag item to put it in a named, coloured group, then equip the whole group in one click. With Combine Bags on, grouped gear sits together at the top.
- **Map extras.** Reveal unexplored areas in a blue tint, see each zone's level range coloured like quest levels, and find every dungeon and raid entrance marked with retail's icons.
- **Movable windows.** A **Windows** tab in Edit Mode moves and scales 21 Blizzard windows, per layout, with Reset to put them back.
- **Nameplates.** A taller bar in retail's own frame, with name and level above, your target outlined and cast bars with the spell's icon.
- **Modern tooltips.** A thin rounded border over charcoal, class-coloured names, and a health bar inside the tooltip.
- **Nearest quests first.** The quest tracker sorts by distance as you move and shows how far each quest is.
- **Quests on minimap givers.** Pointing at a quest giver on the minimap lists their quests for you. Needs [QuestieDB](https://github.com/Questie/QuestieDB).
- **Quest progress.** A creature you still need for a quest shows your progress in its tooltip and a quest icon beside its nameplate. Needs [QuestieDB](https://github.com/Questie/QuestieDB).
- **Camp benefits.** Camp tooltips say what sitting nearby gives you and for how long, and each benefit you gain is named on screen.
- **Future spells.** Each spellbook tab ends with the spells you have not learned yet, and what your trainer can teach you now.
- **Quiet errors.** Hides the red text a spammed macro repeats; full bags and other errors still show.
- **Hide macro names.** Macros on your action bars show just their icon. Off until you turn it on.
- **Fishing.** Double right-click to cast, apply the best lure you have, and optionally hear splashes over everything else.

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/nameplates.png" width="644" alt="Three enemy nameplates, the target outlined in white with a quest icon and a Fireball cast">
</p>

<p align="center">Nameplates in retail's own frame, with your target outlined, casts in a slim bar and a quest icon on what you still need.</p>

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/editmode.png" width="100%" alt="Edit Mode's Windows tab and the Character window's Scale slider">
</p>

<p align="center">Move and scale Blizzard windows from a tab in Edit Mode.</p>

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/junk.png" width="452" alt="A backpack with the game's gold junk coin on a ring and on stacks of cloth, meat and fins">
</p>

<p align="center">The game's junk coin on greys and on anything you mark yourself.</p>

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/campsite.png" width="321" alt="A Mana Well tooltip saying what sitting nearby restores">
</p>

<p align="center">Camp tooltips say what sitting nearby gives you.</p>

## Install

Download the zip from [Releases](https://github.com/cjber/tweaks-forever/releases) and extract it into `_classic_beta_/Interface/AddOns/`, so you end up with `AddOns/TweaksForever/TweaksForever.toc`.

The quest features (quests on minimap givers, quest progress on tooltips and nameplates) read [QuestieDB](https://github.com/Questie/QuestieDB)'s quest data and are greyed out without it. The QuestieDB addon on its own is enough; you don't need Questie itself.

## Usage

- `/tweaks` or `/tweaksforever` opens the settings, also under **Options → AddOns → Tweaks Forever** or from the addon compartment on the minimap.
- `/rl` reloads the interface.

Nothing to set up. A few features that act for you are off until you tick them.

## For addon authors

`TweaksForever.API` (`version = 1`) gives the class trainer spells you can learn and each dungeon's own entrance. [docs/features.md](docs/features.md#for-addon-authors) has the details.

## Works alongside

A feature steps aside while one of these is loaded. For Leatrix Plus, Leatrix Maps, Mapster, Questie and Legacy Forever, it steps aside only while that addon's matching option is on.

| Feature | Addons |
|---|---|
| Quests | Leatrix Plus, Questie, AutoTurnIn |
| Nearest quests first | Questie, while its tracker is on |
| Quest progress on tooltips | Questie, while its tooltips are on |
| Quest icons on nameplates | Questie, while its nameplate icons are on |
| Other automations, repairs, quiet errors | Leatrix Plus |
| `/rl` | Leatrix Plus, which always adds its own `/rl` |
| Faster auto loot | Leatrix Plus, SpeedyAutoLoot, AutoLootPlus |
| Junk marks and selling | Peddler, Scrap, Dejunk, Vendor |
| Unexplored areas | Legacy Forever, Leatrix Maps, Mapster |
| Zone level ranges | Leatrix Maps |
| Dungeon entrances | Leatrix Maps, while its points of interest are on |
| Move windows | BlizzMove, MoveAnything |
| Hide macro names | Dominos, Bartender4, ElvUI |
| Reagent bag in the combined bag | AdiBags, ArkInventory, Baganator, Bagnon, BetterBags |
| Modern tooltips | Aurora, ElvUI, TinyTooltip, TipTac |
| Nameplates | Plater, Kui Nameplates, Threat Plates, Platynator, ElvUI |
| Fishing | FishingBuddy, FishingAce |

## Development

```sh
# link the checkout into the game
ln -s "$PWD" ".../World of Warcraft/_classic_beta_/Interface/AddOns/TweaksForever"

tools/typecheck.sh                              # LuaLS 3.19.1 + multi-value lint
luacheck .                                      # lint
stylua --check .                                # format
for spec in tests/*_spec.lua; do luajit "$spec" || exit 1; done
python3 tools/screenshots.py                    # regenerate docs/screenshots from the game's own art
```

`tools/typecheck.sh` needs LuaLS **3.19.1**, Git and Python 3.11+. [tools/README.md](tools/README.md) covers the multi-value rule and the `Data/` generators. CI also runs ruff and ty on `tools/`, workflow linting and a secret scan, and a daily workflow opens a PR with regenerated data for each new Forever build.

**Releasing:** move the `[Unreleased]` notes in `CHANGELOG.md` under `## [X.Y.Z] - YYYY-MM-DD`, then `git tag -s vX.Y.Z && git push --tags`. The [BigWigs packager](https://github.com/BigWigsMods/packager) builds the release with that entry as its notes.

**Contributing:** see [CONTRIBUTING.md](https://github.com/cjber/.github/blob/main/CONTRIBUTING.md) and this repository's [AGENTS.md](AGENTS.md); report security problems privately as [SECURITY.md](https://github.com/cjber/.github/blob/main/SECURITY.md) describes.

## Licence

GPL-3.0-or-later. Map overlay, camp benefit, dungeon entrance and new zone level data come from the game's own files via [wago.tools](https://wago.tools); the original zones' level ranges are the original game's, as listed on [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/Zones_by_level_(original)). Class trainer lists come from [CMaNGOS classic-db](https://github.com/cmangos/classic-db) (GPL-3.0).

Made by Cillian Berragan · [cillian.dev](https://cillian.dev) · [GitHub](https://github.com/cjber) · [Twitter](https://twitter.com/cjberragan)
