# Third-party inputs

Everything Tweaks Forever is built from that it did not write itself: where each comes from, where its pin lives, its
licence, and whether any of it reaches the zip players install. A pin is named by the constant that holds it, so a data
refresh that moves the pin never leaves this file behind. The addon itself is GPL-3.0-or-later ([LICENSE](LICENSE)).

## Ships in the zip

| Input | Used for | Pin | Licence |
|---|---|---|---|
| [LibAHTab](https://github.com/TheMouseNest/LibAHTab), adapted | The `LibAHTab` child addon that keeps Auctionator's tabs working on Forever's auction house (`LibAHTab/README.md` lists the changes) | Upstream commit and library revision 4, named in `LibAHTab/README.md` | MIT (`LibAHTab/LICENSE`, plusmouse) |
| [LibStub](https://www.wowace.com/projects/libstub) | Loads LibAHTab (`LibAHTab/LibStub/LibStub.lua`) | Its revision 103 header, minor version 2 | Public domain |
| WoW: Forever client tables, via [wago.tools](https://wago.tools) | Camp benefits, dungeon entrances, Forever's new quests, map overlays, zone levels and class spell ranks in `Data/*.lua` | `BUILD` in each `tools/gen_*.py` | Blizzard Entertainment's game data |
| Classic Era client tables, via wago.tools | Which quests Forever added (`Data/ForeverQuests.lua`), and which spell each trainer's teaching spell gives (`Data/ClassSpells.lua`) | `ERA_BUILD` in `tools/gen_foreverquests.py`; `TEACH_BUILD` in `tools/gen_classspells.py` | Blizzard Entertainment's game data |
| [CMaNGOS classic-db](https://github.com/cmangos/classic-db) | Class trainer lists in `Data/ClassSpells.lua` | `CLASSICDB_COMMIT` in `tools/gen_classspells.py` | GPL-3.0 |
| [Warcraft Wiki: Zones by level (original)](https://warcraft.wiki.gg/wiki/Zones_by_level_(original)) | The original zones' level ranges in `Data/ZoneLevels.lua`, typed into `PUBLISHED` | `SOURCE` and `PUBLISHED` in `tools/gen_zonelevels.py`; the table is the pin | Facts cited from the wiki; no text copied |

`media/` is this addon's own: the icon is drawn in `media/icon.svg`, and `TooltipBorder*.tga` by `tools/tooltip_border.py`.

## Read in game, never bundled

| Input | Used for | Licence |
|---|---|---|
| Questie and QuestieDB, if installed | Quest givers, objectives and quest progress | QuestieDB carries no licence; nothing is copied |
| Atlas and Atlas_ClassicWoW, if installed | Dungeon map images, drawn from their own folder | Their own; nothing is copied |
| Auctionator, if installed | The auction house tabs LibAHTab keeps working | Its own; nothing is copied |
| Shortest Path Forever, if installed | Travel to a clicked map point or dungeon entrance, through its public API | GPL-3.0-or-later |
| [Polestar](https://github.com/fitzforge/polestar), [OpenMap](https://github.com/jiforever/wowforever-openmap), Leatrix Plus, Leatrix Maps, Mapster and the other addons named in `docs/features.md#works-alongside`, if installed | Whether one of them already does a feature's job, read from its loaded state or settings (`Polestar.Get`, OpenMap's and Leatrix's saved options), so the feature steps aside | Their own (Polestar GPL-3.0, OpenMap MIT); nothing is copied |

## Build and test only

| Input | Used for | Pin | Licence |
|---|---|---|---|
| [Ketho's WoW API annotations](https://github.com/Ketho/vscode-wow-api) | lua-language-server types in `tools/typecheck.sh` | `revision` in `tools/typecheck.sh` | MIT |
| [FrameXML annotations](https://github.com/NumyAddon/FramexmlAnnotations) | FrameXML types, the Ketho checkout's `Annotations/FrameXML` submodule | The gitlink in that Ketho revision | MIT |
| [forever_tools](https://github.com/cjber/skills/tree/main/wow-forever-addon/tooling/forever_tools) | Shared lints, release checks and the generated-data gate, vendored in `tools/forever_tools/` | `revision` in `tools/forever_tools/MANIFEST.json` | MIT |
| [wow-mock-screenshots](https://github.com/cjber/skills/tree/main/wow-mock-screenshots) and the client art it fetches | `tools/screenshots.py` | `WOWMOCK` (a local checkout); the art at wowmock's own default build | MIT; the art is Blizzard Entertainment's, fetched at build time and committed only as it appears in `docs/screenshots/` |
| [Atlas](https://www.wowinterface.com/downloads/info3896) and [Atlas_ClassicWoW](https://www.wowinterface.com/downloads/info20513) | The dungeon map screenshot, `docs/screenshots/dungeonmap.png`, which shows its map image and legend | `ATLAS_VERSION` and each zip's sha256 in `ATLAS_ZIPS`, `tools/screenshots.py`; fetched into `~/.cache/wowmock/atlas/`, outside the repository | GPL-2.0; only that screenshot is committed |
| sift gate | `.sift/gate.py` and `.sift/agents.py` in CI | Vendored by `sift setup` | MIT (`.sift/LICENSE`) |

CI tools (StyLua, ruff, ty, luacheck, lua-language-server, actionlint, zizmor, gitleaks, the BigWigs packager) are pinned in `.github/workflows/` and `tools/typecheck.sh`, except luajit and luacheck, which come from the runner's apt; they build and check the addon and are never part of it.

## Ideas and contributors

Credit for the ideas and reports behind the addon.

| Who | What | Notes |
|---|---|---|
| [Polestar](https://github.com/fitzforge/polestar) by Fitz | The ideas for not paying quest gold or taking PvP quests unasked (#153), retrying a repair after junk sales (#154), friend and guild exceptions and party invites (#155), stronger summon, resurrection and release guards (#156), marking the best reward (#157), quest progress on item and object tooltips (#158), bindable quest buttons (#159), world map coordinates (#160), a calmer fast loot (#161), unexplored areas on the zone map (#162), Shift to skip the merchant (#163), rare alerts (#165), quest levels in greetings (#166), XP per hour (#167) and drawing the maps on frames of its own, which the maps never touch (#168). From cjber/adventure-guide-forever's issues: `/tweaks report` with its copy box and caught errors (#156), the issue forms (#157), the zip check (#158), `tools/doctor.py` (#160), the stale-screenshot check (#161), this file (#162), the "For addon authors" changelog subsection (#163) and `.editorconfig` (#165). | GPL-3.0. Inspired only; no code was copied. Fitz is welcome to use our code. |
| [Forever Loot Sparkles](https://github.com/svengabr/ForeverLootSparkles) by Ashtar Senior (svengabr) | Quest item sparkles set the same five graphics settings it sets | GPL-3.0. The settings are the client's; no code was copied |
| A CurseForge player | Reported the game crashing when backing out of the addon settings with a gamepad (#168) | |
| Sojiro84 | Asked for tooltips anchored to the cursor (#108) and found the Abandon quests button showing inside a quest (#109) | |
| [Mouchoir](https://github.com/Mouchoir) | Found the login error from Rare alerts reading the settings before they load, with the event order, a spec and the fix (#202) | |

Thanks also to everyone else who reported a bug, here or on CurseForge.
