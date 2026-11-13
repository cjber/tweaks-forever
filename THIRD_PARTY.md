# Third-party inputs

Everything Tweaks Forever is built from that it did not write itself: where each comes from, where its pin lives, its
licence, and whether any of it reaches the zip players install. A pin is named by the constant that holds it, so a data
refresh that moves the pin never leaves this file behind. The addon itself is GPL-3.0-or-later ([LICENSE](LICENSE)).

## Ships in the zip

| Input | Used for | Pin | Licence |
|---|---|---|---|
| WoW: Forever client tables, via [wago.tools](https://wago.tools) | Camp benefits, dungeon entrances, Forever's new quests, map overlays, zone levels and class spell ranks in `Data/*.lua` | `BUILD` in each `tools/gen_*.py` | Blizzard Entertainment's game data |
| Classic Era client tables, via wago.tools | Which quests Forever added (`Data/ForeverQuests.lua`), and which spell each trainer's teaching spell gives (`Data/ClassSpells.lua`) | `ERA_BUILD` in `tools/gen_foreverquests.py`; `TEACH_BUILD` in `tools/gen_classspells.py` | Blizzard Entertainment's game data |
| [CMaNGOS classic-db](https://github.com/cmangos/classic-db) | Class trainer lists in `Data/ClassSpells.lua` | `CLASSICDB_COMMIT` in `tools/gen_classspells.py` | GPL-3.0 |
| [Warcraft Wiki: Zones by level (original)](https://warcraft.wiki.gg/wiki/Zones_by_level_(original)) | The original zones' level ranges in `Data/ZoneLevels.lua`, typed into `PUBLISHED` | `SOURCE` and `PUBLISHED` in `tools/gen_zonelevels.py`; the table is the pin | Facts cited from the wiki; no text copied |

`media/` is this addon's own: the icon is drawn in `media/icon.svg`, and `TooltipBorder*.tga` by `tools/tooltip_border.py`.

## Read in game, never bundled

| Input | Used for | Licence |
|---|---|---|
| Questie and QuestieDB, if installed | Quest givers, objectives and quest progress | QuestieDB carries no licence; nothing is copied |
| Shortest Path Forever, if installed | Travel to a clicked map point or dungeon entrance, through its public API | GPL-3.0-or-later |
| [Polestar](https://github.com/fitzforge/polestar), [OpenMap](https://github.com/jiforever/wowforever-openmap), Leatrix Plus, Leatrix Maps, Mapster and the other addons named in `docs/features.md#works-alongside`, if installed | Whether one of them already does a feature's job, read from its loaded state or settings (`Polestar.Get`, OpenMap's and Leatrix's saved options), so the feature steps aside | Their own (Polestar GPL-3.0, OpenMap MIT); nothing is copied |

## Build and test only

| Input | Used for | Pin | Licence |
|---|---|---|---|
| [Ketho's WoW API annotations](https://github.com/Ketho/vscode-wow-api) | lua-language-server types in `tools/typecheck.sh` | `revision` in `tools/typecheck.sh` | MIT |
| [FrameXML annotations](https://github.com/NumyAddon/FramexmlAnnotations) | FrameXML types, the Ketho checkout's `Annotations/FrameXML` submodule | The gitlink in that Ketho revision | MIT |
| [forever_tools](https://github.com/cjber/forever-core/tree/main/.agents/skills/wow-forever-addon/tooling/forever_tools) | Shared lints, release checks and the generated-data gate, vendored in `tools/forever_tools/` | `revision` in `tools/forever_tools/MANIFEST.json` | MIT |
| [forever-core/tools/wowmock](https://github.com/cjber/forever-core/tree/main/tools/wowmock) and the client art it fetches | `tools/screenshots.py` | `FOREVER_CORE` (a local forever-core checkout); the art at wowmock's own default build | MIT; the art is Blizzard Entertainment's, fetched at build time and committed only as it appears in `docs/screenshots/` |
| Ko-fi's Support me on Ko-fi button | The support button in the README (`ko-fi.com/img/githubbutton_sm.svg`) and its PNG render, `docs/kofi-button.png`, in the store description | None: the README links Ko-fi's live file; the PNG is rendered from it | Ko-fi's brand asset, used as Ko-fi provides it for linking to a Ko-fi page |
| `docs/github-sponsors-button.png` | The GitHub Sponsors button in the README and store description; drawn here to match the Ko-fi button, with the heart from GitHub's [Octicons](https://github.com/primer/octicons) and the Adwaita Sans font | None | Octicons: MIT; Adwaita Sans: SIL OFL 1.1 |
| `docs/discord-button.png` | The Discord button on the store page; drawn in forever-core with Discord's logo from [Simple Icons](https://simpleicons.org) and the Adwaita Sans font | None | Simple Icons: CC0; Adwaita Sans: SIL OFL 1.1; the logo is Discord's, used to link to a Discord server |

CI tools (StyLua, ruff, ty, luacheck, lua-language-server, actionlint, zizmor, gitleaks, the BigWigs packager) are pinned in `.github/workflows/` and `tools/typecheck.sh`, except luajit and luacheck, which come from the runner's apt; they build and check the addon and are never part of it.

## Players

Credit for the reports and requests behind the addon.

| Who | What | Notes |
|---|---|---|
| SirGooie | Fixed the gamepad crash leaving the addon settings | CurseForge; #168 |
| Sojiro84 | Tooltips anchored to the cursor | GitHub; #108 |
| Sojiro84 | Abandon Quests button hides with quest details | GitHub; #109 |
| [Mouchoir](https://github.com/Mouchoir) | Fixed the login Lua error (code) | GitHub; #202 |
| [Mouchoir](https://github.com/Mouchoir) | Questie icon sizes follow its sliders (code) | GitHub; #217, PR #216 |
| [Mouchoir](https://github.com/Mouchoir) | Fixed the chat options' login errors (code) | GitHub; #551, PR #552 |

## Inspired by

Credit for the addons and projects an idea came from.

| Who | What | Notes |
|---|---|---|
| [Polestar](https://github.com/fitzforge/polestar) by Fitz | Ideas for many features | Quest automation, repairs, social invites, guards, reward marking, tooltips, bindable buttons, coordinates, fast loot, zone maps, rare alerts, XP per hour, and the shared report window and tooling. GPL-3.0. Inspired only; no code was copied. Fitz is welcome to use our code. |
| [Forever Loot Sparkles](https://github.com/svengabr/ForeverLootSparkles) by Ashtar Senior (svengabr) | Quest item sparkles set the same five graphics settings | GPL-3.0. The settings are the client's; no code was copied |
| [Omen](https://www.curseforge.com/wow/addons/omen-threat-meter) and [Threat Plates](https://www.curseforge.com/wow/addons/tidy-plates-threat-plates) | The pull warning before your threat takes a mob off the tank | Inspired only; no code was copied. |
| [RareScanner](https://www.curseforge.com/wow/addons/rarescanner) | A waypoint to a rare after its alert | Inspired only; no code was copied. |

Thanks also to everyone else who reported a bug, here or on CurseForge.
