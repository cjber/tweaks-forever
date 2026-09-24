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
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/dungeons.png" width="768" alt="The Eastern Kingdoms with a dungeon or raid icon at every entrance, and Blackrock Mountain\'s tooltip listing its four instances">
</p>

<p align="center">Every dungeon and raid entrance, with retail's icons. Blackrock Mountain lists all four.</p>

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/nameplates.png" width="644" alt="Three enemy nameplates in retail\'s bronze-rimmed bar, the targeted Defias Pillager outlined in white, with debuffs above and a Fireball cast below">
</p>

<p align="center">Nameplates in retail's own frame, with your target outlined and casts in a slim bar.</p>

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/editmode.png" width="100%" alt="Edit Mode's Windows tab: a checkbox for each of 21 Blizzard windows, the Character window's outline selected on the left, and a Character dialog with a Scale slider at 100% and Reset To Default Position">
</p>

<p align="center">Move and scale Blizzard windows from a tab in Edit Mode.</p>

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/junk.png" width="452" alt="A backpack with the game's gold junk coin on a ring and on stacks of cloth, meat and fins, and the ring's tooltip ending Marked as junk – Alt+Right-click to unmark">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/campsite.png" width="321" alt="A Mana Well tooltip in green: Sitting nearby: Restores 29 Mana every 5 seconds for 1 Hr, and Active: 48 Min">
</p>

<p align="center">The game's junk coin on anything you mark, and camp tooltips that say what sitting nearby gives you.</p>

## Features

Every feature has its own checkbox. The full detail is in [docs/features.md](docs/features.md).

- **Quest and gossip automation.** Accepts and turns in quests, skips one-option gossip, accepts summons and group resurrections, releases in battlegrounds and declines duels. Hold Shift to talk normally. Off until you turn it on.
- **Faster auto loot.** Takes everything at once instead of waiting for the loot window.
- **Repairs and junk.** Repairs at any merchant, from guild funds when allowed, and sells greys in batches that stay in the buyback tab. **Alt+Right-click** marks any item as junk, with the game's junk coin.
- **Gear groups.** **Ctrl+Right-click** a bag item to put it in a named, coloured group, then equip the whole group in one click. With Combine Bags on, grouped gear sits together at the top.
- **Map extras.** Reveal unexplored areas in a blue tint, see each zone's level range coloured like quest levels, and find every dungeon and raid entrance marked with retail's icons.
- **Movable windows.** A **Windows** tab in Edit Mode moves and scales 21 Blizzard windows, per layout, with Reset to put them back.
- **Nameplates.** A taller bar in retail's own frame, with name and level above, your target outlined and cast bars with the spell's icon.
- **Modern tooltips.** A thin rounded border over charcoal, class-coloured names, and a health bar inside the tooltip.
- **Nearest quests first.** The quest tracker sorts by distance as you move and shows how far each quest is.
- **Camp benefits.** Camp tooltips say what sitting nearby gives you and how long you have left on it.
- **Future spells.** Each spellbook tab ends with the spells you have not learned yet, and what your trainer can teach you now.
- **Quiet errors.** Hides the red text a spammed macro repeats; full bags and other errors still show.
- **Fishing.** Double right-click to cast, apply the best lure you have, and optionally hear splashes over everything else.

## Usage

- `/tweaks` opens the settings, also under **Options → AddOns → Tweaks Forever** or from the addon compartment on the minimap.
- `/rl` reloads the interface.

Nothing to set up. A few features that act for you are off until you tick them.

## Works alongside

A feature steps aside while one of these is loaded. For Leatrix Plus, Leatrix Maps, Questie and Legacy Forever, it steps aside only while that addon's matching option is on.

| Feature | Addons |
|---|---|
| Quests | Leatrix Plus, Questie, AutoTurnIn |
| Nearest quests first | Questie, while its tracker is on |
| Other automations, repairs, quiet errors | Leatrix Plus |
| `/rl` | Leatrix Plus, which always adds its own `/rl` |
| Faster auto loot | Leatrix Plus, SpeedyAutoLoot, AutoLootPlus |
| Junk marks and selling | Peddler, Scrap, Dejunk, Vendor |
| Unexplored areas | Legacy Forever, Leatrix Maps, Mapster |
| Zone level ranges | Leatrix Maps |
| Dungeon entrances | Leatrix Maps, while its points of interest are on |
| Move windows | BlizzMove, MoveAnything |
| Reagent bag in the combined bag | AdiBags, ArkInventory, Baganator, Bagnon, BetterBags |
| Modern tooltips | Aurora, ElvUI, TinyTooltip, TipTac |
| Nameplates | Plater, Kui Nameplates, Threat Plates, Platynator, ElvUI |
| Fishing | FishingBuddy, FishingAce |

## Install

Download the zip from [Releases](https://github.com/cjber/tweaks-forever/releases) and extract it into `_classic_beta_/Interface/AddOns/`, so you end up with `AddOns/TweaksForever/TweaksForever.toc`.

## Development

```sh
# link the checkout into the game
ln -s "$PWD" ".../World of Warcraft/_classic_beta_/Interface/AddOns/TweaksForever"

tools/typecheck.sh                              # LuaLS 3.19.1 + multi-value lint
luacheck .                                      # lint
stylua --check .                                # format
for spec in tests/*_spec.lua; do luajit "$spec" || exit 1; done
python3 tools/gen_overlays.py                   # regenerate Data/Overlays.lua from wago.tools
python3 tools/gen_camp.py                       # regenerate Data/CampBenefits.lua from wago.tools
python3 tools/gen_dungeons.py                   # regenerate Data/DungeonEntrances.lua from wago.tools
python3 tools/gen_zonelevels.py                 # regenerate Data/ZoneLevels.lua from wago.tools
python3 tools/screenshots.py                    # regenerate docs/screenshots from the game's own art
```

Install LuaLS **3.19.1**, Git and Python 3.11+ before running `tools/typecheck.sh`. It fetches the pinned
Ketho WoW API annotations (including pinned FrameXML) into ignored `.types/`, checks all runtime Lua
(including generated data), and rejects every diagnostic. Local contracts in `types/` are editor-only
and excluded from the release. See [tools/README.md](tools/README.md) for the multi-value rule.

CI runs these checks on every push, plus ruff and ty on `tools/`, workflow linting and a secret scan. A daily workflow opens a PR with regenerated map, camp, zone level and dungeon entrance data when wago.tools lists a newer Forever build. [tools/README.md](tools/README.md) covers the generators.

**Releasing:** move the `[Unreleased]` notes in `CHANGELOG.md` under `## [X.Y.Z] - YYYY-MM-DD`, then `git tag -s vX.Y.Z && git push --tags`. The [BigWigs packager](https://github.com/BigWigsMods/packager) builds the zip and attaches it to a GitHub release, with that version's entry (`tools/changelog.py`) as the release notes.

**Contributing:** see [CONTRIBUTING.md](https://github.com/cjber/.github/blob/main/CONTRIBUTING.md) and this repository's [AGENTS.md](AGENTS.md); report security problems privately as [SECURITY.md](https://github.com/cjber/.github/blob/main/SECURITY.md) describes.

## Licence

GPL-3.0-or-later. Map overlay, camp benefit, dungeon entrance and new zone level data come from the game's own files via [wago.tools](https://wago.tools); the original zones' level ranges are the original game's, as listed on [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/Zones_by_level_(original)).

Made by Cillian Berragan · [cillian.dev](https://cillian.dev) · [GitHub](https://github.com/cjber) · [Twitter](https://twitter.com/cjberragan)
