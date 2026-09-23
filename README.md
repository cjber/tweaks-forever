<p align="center"><img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/media/icon-400.png" width="96" alt=""></p>

<h1 align="center">Tweaks Forever</h1>

<p align="center">
Small quality-of-life automations for WoW: Forever that feel like part of the default UI.<br>
<a href="https://github.com/cjber/tweaks-forever/actions/workflows/ci.yml"><img src="https://github.com/cjber/tweaks-forever/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<a href="https://github.com/cjber/tweaks-forever/releases/latest"><img src="https://img.shields.io/github/v/release/cjber/tweaks-forever" alt="Latest release"></a>
</p>

Tweaks Forever replaces a handful of single-purpose addons with checkboxes in the game's own settings: quest and gossip automation, repairs, junk selling, gear groups, a revealed world map, movable windows and fishing. Nothing opens a window of its own. Settings live under **Options → AddOns → Tweaks Forever** (or `/tweaks`, or the addon compartment on the minimap), with a page for each section.

When another addon already does one of these jobs, that feature is greyed out and its tooltip names the addon, so the two never fight. This is checked again each time the settings open.

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/gear.png" width="374" alt="A backpack with gear groups marked by coloured strips along the bottom of each slot, and a ring's tooltip ending Gear: DPS, Levelling in the groups' colours">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/menu.png" width="248" alt="The Ctrl+Right-click menu on a ring: group checkboxes, New group, Equip DPS, Equip Levelling and Colour">
</p>

## Features

**Automation.** All off until you turn them on, except faster auto loot.
- Accept and turn in quests. Hold Shift to talk normally. A quest with a choice of rewards is left to you.
- Skip gossip when an NPC offers only one thing (vendor, trainer, flight map). Hold Shift to see it.
- Accept summons, but not in combat.
- Accept resurrections from your group, but not from someone in combat, so a battle resurrection is still yours to time.
- Release your spirit in battlegrounds unless you can resurrect yourself.
- Decline duels.
- Faster auto loot: everything at once instead of waiting for the loot window.

**Vendors**
- Repair automatically at any merchant who repairs, from guild funds when the guild allows it. The cost is shown in chat.
- Sell junk automatically, up to 12 stacks per visit, so everything sold is still in the buyback tab.
- Mark any bag item as junk with **Alt+Right-click** (off by default). Marked items get the game's junk coin and a tooltip line, and they are sold with your greys, by the merchant's Sell All Junk button too. Marks are account-wide.

**Gear**
- **Ctrl+Right-click** a bag item to put it in a named group, such as Healing, DPS or Levelling, or to start a new one. The same menu equips a whole group, or an Equipment Manager set the item is in, in one click.
- Each group has its own colour, which you can change from the same menu. Grouped items get a strip in that colour along the bottom of their bag slot, split when an item is in several groups, and their tooltip names the groups in colour. A glowing coloured border in place of the quality border, coloured dots or no mark are options. Groups are kept per character.
- With **Combine Bags** on, grouped gear sits together at the top of the bag, under a heading for each group in its colour. Separate bags keep items where they are.
- Equipping a fishing pole remembers the weapons it replaced as a **Before fishing** group, so they stand out in your bags. Ctrl+Right-click one to put them back on.
- No modifier keys needed: pick **Mark junk** or **Group gear** from a bag's portrait menu and the cursor changes, like the merchant's repair mode. Click bag items to mark them or open their gear menu; right-click, close your bags or enter combat to stop.

**Maps**
- Reveal unexplored areas on zone maps, tinted blue so explored ground still stands out (off by default).

**Interface**
- Move and scale Blizzard windows in **Edit Mode**. The Edit Mode panel gets a **Windows** tab next to **HUD**. Tick a window there to preview it where the game opens it, then drag, snap and scale it like the rest of the UI. Covers the character sheet, spellbook, map, quest windows, merchant, bank, mailbox, trainer, auction house, professions and more. Each Edit Mode layout keeps its own arrangement, and Reset puts a window back where Blizzard had it.
- Quiet the errors a spammed macro repeats: no red text or spoken "not ready yet", out of range, not enough mana, rage or energy, no target or wrong facing. Full bags and other errors still show.
- `/rl` reloads the interface.
- Explain campsites. Hovering a camp feature (a Camp Tent, Mana Well, Anvil and the rest) shows what sitting nearby gives you and whether you have it now, with the time left. Hovering a campfire shows how long your camp benefits last.

**Fishing**
- Double right-click the world with a fishing pole equipped to cast Fishing. Not in combat or while mounted.
- If the pole has no lure, that double-click puts on the best lure in your bags that your fishing skill allows. Double right-click again to cast.
- A warning when you log in, equip a pole or cast without a lure.
- Louder splashes (off by default): full sound effects, no music or ambience while a pole is equipped. Your volumes come back when you unequip it or log out.

## Works alongside

A feature steps aside while one of these is loaded. For Leatrix Plus, Questie and Legacy Here, it steps aside only while that addon's matching option is on.

| Feature | Addons |
|---|---|
| Quests | Leatrix Plus, Questie, AutoTurnIn |
| Other automations, repairs, quiet errors | Leatrix Plus |
| `/rl` | Leatrix Plus, which always adds its own `/rl` |
| Faster auto loot | Leatrix Plus, SpeedyAutoLoot, AutoLootPlus |
| Junk marks and selling | Peddler, Scrap, Dejunk, Vendor |
| Unexplored areas | Legacy Here, Leatrix Maps, Mapster |
| Move windows | BlizzMove, MoveAnything |
| Fishing | FishingBuddy, FishingAce |

## Install

Download the zip from [Releases](https://github.com/cjber/tweaks-forever/releases) and extract it into `_classic_beta_/Interface/AddOns/`, so you end up with `AddOns/TweaksForever/TweaksForever.toc`.

## Development

```sh
# link the checkout into the game
ln -s "$PWD" ".../World of Warcraft/_classic_beta_/Interface/AddOns/TweaksForever"

luacheck .                                      # lint
stylua --check .                                # format
for spec in tests/*_spec.lua; do luajit "$spec"; done
python3 tools/gen_overlays.py                   # regenerate Data/Overlays.lua from wago.tools
python3 tools/screenshots.py                    # regenerate docs/screenshots from the game's own art
```

CI runs these checks on every push, plus ruff and ty on `tools/`, workflow linting and a secret scan. A daily workflow opens a PR with regenerated map data when wago.tools lists a newer Forever build. [tools/README.md](tools/README.md) covers the generators.

**Releasing:** move the `[Unreleased]` notes in `CHANGELOG.md` under `## [X.Y.Z] - YYYY-MM-DD`, then `git tag -s vX.Y.Z && git push --tags`. The [BigWigs packager](https://github.com/BigWigsMods/packager) builds the zip and attaches it to a GitHub release, with that version's entry (`tools/changelog.py`) as the release notes.

## Licence

GPL-3.0-or-later. Map overlay data comes from the game's own files via [wago.tools](https://wago.tools).

Made by Cillian Berragan · [cillian.dev](https://cillian.dev) · [GitHub](https://github.com/cjber) · [Twitter](https://twitter.com/cjberragan)
