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
| Classic Era client tables, via wago.tools | Which quests Forever added (`Data/ForeverQuests.lua`) and which spells a trainer teaches (`Data/ClassSpells.lua`) | `ERA_BUILD` in `tools/gen_foreverquests.py`; `TEACH_BUILD` in `tools/gen_classspells.py` | Blizzard Entertainment's game data |
| [CMaNGOS classic-db](https://github.com/cmangos/classic-db) | Class trainer lists in `Data/ClassSpells.lua` | `CLASSICDB_COMMIT` in `tools/gen_classspells.py` | GPL-3.0 |
| [Warcraft Wiki: Zones by level (original)](https://warcraft.wiki.gg/wiki/Zones_by_level_(original)) | The original zones' level ranges in `Data/ZoneLevels.lua`, typed into `PUBLISHED` | `SOURCE` and `PUBLISHED` in `tools/gen_zonelevels.py`; the table is the pin | Facts cited from the wiki; no text copied |

`media/TooltipBorder*.tga` are drawn by `tools/tooltip_border.py` and are this addon's own.

## Read in game, never bundled

| Input | Used for | Licence |
|---|---|---|
| Questie and QuestieDB, if installed | Quest givers, objectives and quest progress | No licence; nothing is copied |
| Atlas and Atlas_ClassicWoW, if installed | Dungeon map images, drawn from their own folder | Their own; nothing is copied |
| Auctionator, if installed | The auction house tabs LibAHTab keeps working | Its own; nothing is copied |
| Shortest Path Forever, if installed | Travel to a clicked map point or dungeon entrance, through its public API | GPL-3.0-or-later |

## Build and test only

| Input | Used for | Pin | Licence |
|---|---|---|---|
| [Ketho's WoW API annotations](https://github.com/Ketho/vscode-wow-api) | lua-language-server types in `tools/typecheck.sh` | `revision` in `tools/typecheck.sh` | MIT |
| [forever_tools](https://github.com/cjber/skills/tree/main/wow-forever-addon/tooling) | Shared lints, release checks and the generated-data gate, vendored in `tools/forever_tools/` | `revision` in `tools/forever_tools/MANIFEST.json` | MIT |
| [wow-mock-screenshots](https://github.com/cjber/skills/tree/main/wow-mock-screenshots) and the client art it fetches | `tools/screenshots.py` | `WOWMOCK`; art at `BUILD` | MIT; the art is Blizzard Entertainment's |
| Atlas data | The dungeon map screenshot (`ATLAS` in `tools/screenshots.py`) | A local install | Its own; read locally, never committed |
| sift gate | `.sift/gate.py` and `.sift/agents.py` in CI | Vendored by `sift setup` | MIT (`.sift/LICENSE`) |

CI tools (StyLua, ruff, luacheck, lua-language-server, actionlint, zizmor, gitleaks, the BigWigs packager) are pinned in
`.github/workflows/` and `tools/typecheck.sh`; they build and check the addon and are never part of it.
