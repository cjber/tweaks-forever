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
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/exploration.png" width="768" alt="The Redridge Mountains map with its unexplored east revealed in a cool blue tint, beside the explored areas in full colour">
</p>

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/zonelevels.png" width="768" alt="Kalimdor on the world map with the cursor on Ashenvale: the label at the top reads Ashenvale (18-30), the range in yellow for a level 22 character">
</p>

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/dungeons.png" width="768" alt="The Eastern Kingdoms on the world map with a dungeon or raid icon at every entrance, and the cursor on Blackrock Mountain: its tooltip lists Blackrock Spire, Blackrock Depths, Molten Core and Blackwing Lair">
</p>

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/editmode.png" width="100%" alt="Edit Mode's Windows tab: a checkbox for each of 21 Blizzard windows, the Character window's outline selected on the left, and a Character dialog with a Scale slider at 100% and Reset To Default Position">
</p>

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/gear.png" width="374" alt="A backpack with gear groups marked by coloured strips along the bottom of each slot, and a ring's tooltip ending Gear: DPS, Levelling in the groups' colours">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/menu.png" width="248" alt="The Ctrl+Right-click menu on a ring: group checkboxes, New group, Equip DPS, Equip Levelling and Colour">
</p>

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/junk.png" width="452" alt="A backpack with the game's gold junk coin on a ring and on stacks of cloth, meat and fins, and the ring's tooltip ending Marked as junk – Alt+Right-click to unmark">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/campsite.png" width="321" alt="A Mana Well tooltip in green: Sitting nearby: Restores 29 Mana every 5 seconds for 1 Hr, and Active: 48 Min">
</p>

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/camp.png" width="327" alt="The Campfire Nearby buff tooltip: the game's description, then Campfire: about 35 yd ahead to your left, and the three benefits you have in green with their time left, such as First Aid Kit (52 Min): Stamina increased by 56">
</p>

<p align="center">
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/nameplates.png" width="644" alt="Three enemy nameplates: the targeted Defias Pillager outlined in white in retail's bronze-rimmed bar, its name centred above with level 15 in yellow after it and 62% inside the bar, two debuffs above and a Fireball cast in a slim bar below with the spell's icon inside; the other two faded back">
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
- Grey items show the game's junk coin in your bags all the time, not only at a merchant.
- Mark any bag item as junk with **Alt+Right-click** (off by default). Marked items get the game's junk coin and a tooltip line, and they are sold with your greys, by the merchant's Sell All Junk button too. Marks are account-wide.

**Gear**
- **Ctrl+Right-click** a bag item to put it in a named group, such as Healing, DPS or Levelling, or to start a new one. The same menu equips a whole group, or an Equipment Manager set the item is in, in one click.
- Each group has its own colour, which you can change from the same menu. Grouped items get a strip in that colour along the bottom of their bag slot, split when an item is in several groups, and their tooltip names the groups in colour. A glowing coloured border in place of the quality border, coloured dots or no mark are options. Groups are kept per character.
- With **Combine Bags** on, grouped gear sits together at the top of the bag, under a heading for each group in its colour. Separate bags keep items where they are.
- Equipping a fishing pole remembers the weapons it replaced as a **Before fishing** group, so they stand out in your bags. Ctrl+Right-click one to put them back on.
- No modifier keys needed: pick **Mark junk** or **Group gear** from a bag's portrait menu and the cursor changes, like the merchant's repair mode. Click bag items to mark them or open their gear menu; right-click, close your bags or enter combat to stop.

**Maps**
- Reveal unexplored areas on zone maps, tinted blue so explored ground still stands out (off by default).
- Point at a zone on the world map to see its level range after the name, coloured like quest levels: grey and green below you, yellow at your level, orange and red above. Forever's map data has no ranges of its own, so the original zones show the original game's, and Zephras Isle and Riverglades show the span of their subzones' exploration levels. Cities, battlegrounds, and Forever zones whose subzones carry no level show none.
- Mark every dungeon and raid entrance on zone and continent maps with retail's icons; point at one for its name, and left-click it to travel there: Shortest Path Forever plans the journey when it is installed, and otherwise the map's own waypoint marks the entrance. Instances sharing a way in, such as Blackrock Mountain, share one pin that lists them. The map's own **Show instance entrances** filter turns them off, and an entrance steps aside where a flight master or Shortest Path Forever portal or dock already marks the spot; Legacy Forever draws the same portal with its shield on the corner where a Legacy step is left there. Forever's new instances (Dalaran, the Ruins of Lordaeron, the Hall of Thanes and the Wetlands excavation) have no entrance in the game's data yet, so they have no pin.

**Interface**
- Move and scale Blizzard windows in **Edit Mode**. The Edit Mode panel gets a **Windows** tab next to **HUD**. Tick a window there to preview it where the game opens it, then drag, snap and scale it like the rest of the UI. Covers the character sheet, spellbook, map, quest windows, merchant, bank, mailbox, trainer, auction house, professions and more. Each Edit Mode layout keeps its own arrangement, and Reset puts a window back where Blizzard had it.
- Quiet the errors a spammed macro repeats: no red text or spoken "not ready yet", out of range, not enough mana, rage or energy, no target or wrong facing. Full bags and other errors still show.
- `/rl` reloads the interface.
- With **Combine Bags** on, the reagent bag's slots sit at the bottom of the combined bag, tinted green under a thin rule, instead of in a small window beside it, and the backpack key opens and closes both. Clicking the reagent bag on the bag bar still opens it in its own window.
- Nearest quests first. The quest tracker sorts itself by distance as you move and shows how far away each quest is; the one whose area you're standing in reads "here" with a soft gold highlight.
- Explain campsite benefits. Hovering a camp feature (a Camp Tent, Mana Well, Anvil and the rest) shows exactly what sitting nearby gives you, such as "Stamina increased by 56 for 1 Hr", and whether you have it now, with the time left. Hovering a campfire lists every benefit a camp can give: the ones you have in green with their time left, the rest in grey. Your Campfire Nearby buff adds the benefits you have and which way the campfire is, once you have lit it or sat by it; your Camp Benefits buff adds the ones you haven't gained yet.
- Show future spells in the spellbook. Each tab ends with the spells you haven't learned yet under a Future Spells heading, greyed out as the retail spellbook shows them: the ones your trainer can teach you now glow and say "See your trainer", the rest name their level, and the tooltip gives the cost. Only each spell's next rank shows. The server leaves unlearned spells out of the spellbook, so the list comes from your class trainer, remembered per character each time you visit.
- Modern tooltips: a thin grey border with rounded corners in place of the beige one, over a neutral charcoal that keeps the text crisp over any scenery. Tooltip style switches to the retail game's navy, or keeps the game's own border. A player's name is in their class colour, with the guild in brackets, race and class on one line and the faction in its colour. A unit's health bar sits inside its tooltip in class or reaction colour, with health as numbers for players and a percentage for others, and a comparison tooltip's Equipped label moves inside it in grey. On by default.
- Larger, clearer nameplates. A taller health bar in the retail game's own frame, with the full name centred above it and the level, coloured by difficulty, after the name. Your target is outlined in white and your focus in gold, and the other plates fade back while you have one. Casts show in a slim bar with the spell's icon and name inside, grey with a shield when they can't be interrupted. Health numbers inside the bar follow the game's own Nameplates options. Friendly plates in dungeons are the game's own and can't be restyled. On by default; turning it off takes effect after a reload.

**Fishing**
- Double right-click the world with a fishing pole equipped to cast Fishing. Not in combat or while mounted.
- If the pole has no lure, that double-click puts on the best lure in your bags that your fishing skill allows. Double right-click again to cast.
- A warning when you log in, equip a pole or cast without a lure.
- Louder splashes (off by default): full sound effects, no music or ambience while a pole is equipped. Your volumes come back when you unequip it or log out.

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
python3 tools/gen_zonelevels.py                 # regenerate Data/ZoneLevels.lua from wago.tools
python3 tools/screenshots.py                    # regenerate docs/screenshots from the game's own art
```

Install LuaLS **3.19.1**, Git and Python 3.11+ before running `tools/typecheck.sh`. It fetches the pinned
Ketho WoW API annotations (including pinned FrameXML) into ignored `.types/`, checks all runtime Lua
(including generated data), and rejects every diagnostic. Local contracts in `types/` are editor-only
and excluded from the release. See [tools/README.md](tools/README.md) for the multi-value rule.

CI runs these checks on every push, plus ruff and ty on `tools/`, workflow linting and a secret scan. A daily workflow opens a PR with regenerated map, camp, zone level and dungeon entrance data when wago.tools lists a newer Forever build. [tools/README.md](tools/README.md) covers the generators.

**Releasing:** move the `[Unreleased]` notes in `CHANGELOG.md` under `## [X.Y.Z] - YYYY-MM-DD`, then `git tag -s vX.Y.Z && git push --tags`. The [BigWigs packager](https://github.com/BigWigsMods/packager) builds the zip and attaches it to a GitHub release, with that version's entry (`tools/changelog.py`) as the release notes.

## Licence

GPL-3.0-or-later. Map overlay, camp benefit, dungeon entrance and new zone level data come from the game's own files via [wago.tools](https://wago.tools); the original zones' level ranges are the original game's, as listed on [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/Zones_by_level_(original)).

Made by Cillian Berragan · [cillian.dev](https://cillian.dev) · [GitHub](https://github.com/cjber) · [Twitter](https://twitter.com/cjberragan)
