# AGENTS.md

Tweaks Forever is a WoW: Forever addon (Interface 16001) that replaces single-purpose addons with
options in the game's own settings. Players install the zip the BigWigs packager builds on a `v*` tag.

## Commands

```sh
stylua --check .
luacheck .
tools/typecheck.sh
for spec in tests/*_spec.lua; do luajit "$spec" || exit 1; done
ruff check tools && ruff format --check tools
uvx ty@0.0.83 check tools
python3 tools/check_generated.py --offline # omit --offline to fetch missing pinned inputs
python3 tools/changelog.py --check
python3 .sift/gate.py --base origin/main && python3 .sift/agents.py check
```

The same gate CI runs, plus actionlint, zizmor and gitleaks on the workflows and history.
Every version needs a `CHANGELOG.md` entry (prose, bold-lead bullets) before its `v*` tag: the release
publishes that entry as its notes.

## Layout

- `Core/Core.lua` — `ns.Feature`/`ns.On`/`ns.Init`; every feature file registers through it, and TOC
  order sets the settings subpage order.
- `Bags/`, `Quests/`, `Map/`, `Features/` — feature modules grouped by the part of the game they change.
- `UI/` — settings, tooltips, nameplates and window helpers; `Integrations/` — companion navigation, and
  `Integrations/QuestieSource.lua`, the one place QuestieDB is opened: quests, NPC names and spawns are read from the installed
  addon in game, a little each frame, and never copied here.
- `Data/` — lookup tables for what neither QuestieDB nor AtlasLoot holds (the WFA-28 waivers below); a generated one
  names the script that regenerates it and its sources in its header.
- `docs/curseforge.md` — the store description, pasted into CurseForge and Wago by hand.
- `Locales/` — `ns.L` (enUS.lua), keyed by the English text, and one `<locale>.lua` per translation, each in the
  TOC. After changing player-visible text, run `python3 -m tools.phrases --write` (translators copy `Locales/phrases.txt`).
  CurseForge's localization is gone and its packager keyword fails the release, so none may appear in the tree.

## Rules

- Lua 5.1 in the game's sandbox: no `require`. The client loads the files `TweaksForever.toc` lists, in
  that order, each receiving `local addonName, ns = ...`; a new file goes in the TOC or never runs.
- The specs are a headless harness with stubbed client APIs. Anything they cannot reach (frames,
  menus, tooltips, the tracker) is checked in game: list those checks in the PR as `/reload` tests
  for the user. Never drive the game client.
- LuaLS 3.19.1 checks every TOC-loaded file against pinned Ketho API/FrameXML annotations.
  `tools/typecheck.sh` fetches them into an ignored types cache and also checks accidental `select()` expansion.
- New host globals go in `.luacheckrc`; if upstream lacks their types, declare real types in
  `types/Forever.lua`. Addon contracts live in `types/`. Never add a LuaLS globals allowlist.
- A final `select(...)` or multi-return call (`GetDrawLayer`, `GetPoint`, `GetRGB`, … in
  `tools/lint_multivalue.py`) as an argument, table element or return must be parenthesised, or carry a
  trailing `-- multi-value: reason` when expansion is intentional.
- Never touch Blizzard's Lua state. Forever runs its UI through secure delegates, so an addon hook, write or
  first call there makes Blizzard's own code fail or be blocked, blamed on this addon. React through
  `HookScript`, events, `EventRegistry` or an object's own `RegisterCallback`, `TooltipDataProcessor`
  (`ns.OnTooltip`), a map data provider of our own, or `hooksecurefunc("GlobalFunction", …)`; draw on our own
  textures and frames; lay Blizzard frames out with engine calls (points, sizes, alpha) after Blizzard has.
  Never `hooksecurefunc(object, …)`, a replaced method, a field written on a Blizzard table, or a call into
  Blizzard's layout or lazy caches. `python3 -m tools.lint_taint` (in `tools/typecheck.sh`) enforces this; a
  deliberate exception carries a trailing `-- taint-ok: reason`.
- Player-visible text goes through `L["whole sentence"]` (a whole format string, never joined fragments), or a
  Blizzard GlobalString that says exactly the same; `ns.Feature`/`ns.ClickMode` text stays plain English.
- Commits are signed (`git commit -S`) with the personal email.
- Quality: load `.agents/skills/sift-project/SKILL.md` before cleanup, dead-code or refactoring
  work.
- A feature another loaded addon already provides is greyed out with that addon named, never run
  alongside it. Repairs, selling junk and faster auto loot start on;
  every other automation that acts for the player is off by default.
- Never stretch art: an icon, atlas or texture is drawn at its native aspect (size it from
  `C_Texture.GetAtlasInfo`, fit inside the box); only nine-slice pieces, bars and fills stretch by design.
- Store copy, README and posts pitch the addon as looking like it came with the game, in cjber's
  own voice, never AI marketing: `wow-forever-addon` WFA-23/24, checked before every store paste.

## Waivers

Owner-approved exceptions to `wow-forever-addon`:

- WFA-2: Reveal unexplored areas is off by default: unexplored areas are a spoiler for players who like to explore.
- WFA-2: Hide macro names is off by default: it changes action bars players set up themselves.
- WFA-4: tooltips default to the charcoal Modern style, a headline feature pictured on the store page.
- WFA-13: `Quests/QuestDistance.lua`'s 1 s ticker keeps running: it is the only catch for Questie tracker toggles and
  tracker collapses, which set no dirty flag, and it is cheap.
- WFA-28: class trainer spells with their level and fee (`Data/ClassSpells.lua` `spells`): CMaNGOS classic-db trainer
  tables, with skill lines, ranks and races from the Forever client's DB2 on wago.tools. QuestieDB's NPC rows carry no
  trainer offers and AtlasLoot lists profession recipes only. A trainer visit records the game's own list, level and
  fee, which win over the bundled row.
- WFA-28: which NPCs train each class (`Data/ClassSpells.lua` `trainers`, NPC IDs only): CMaNGOS classic-db
  `creature_template.TrainerClass`. QuestieDB marks a trainer with a general flag and a translated subtitle, never
  its class, and AtlasLoot has no trainers. Their names and places are read from QuestieDB.
- WFA-28: dungeon and raid entrances (`Data/DungeonEntrances.lua`): the Forever client's `Map` corpse points on
  wago.tools. QuestieDB keeps one zone point per dungeon, shared by every instance of a complex such as Blackrock
  Mountain, not each instance's own door, and AtlasLoot has no map points.
- WFA-28: world map overlays (`Data/Overlays.lua`): the Forever client's `WorldMapOverlay` art tables on wago.tools.
  Neither database holds map art.
- WFA-28: camp benefit texts (`Data/CampBenefits.lua`): the Forever client's `Spell` tables on wago.tools. Neither
  database holds spell descriptions. The aura you have supplies its own values, which win.
- WFA-28: zone level ranges (`Data/ZoneLevels.lua`): the published ranges on warcraft.wiki.gg for the original zones
  and the Forever client's `AreaTable.ExplorationLevel` for new ones. QuestieDB has no zone ranges and AtlasLoot has
  them for dungeons only. `C_Map.GetMapLevels` wins wherever the client fills it in.
- WFA-28: quests added in Forever (`Data/ForeverQuests.lua`): the Forever client's `QuestV2` IDs less Classic Era's,
  both on wago.tools. QuestieDB's quest rows have no field for the version a quest arrived in.

## Standards

- `wow-forever-addon` — https://github.com/cjber/skills/tree/19082fc10bf90cbb466b8129bddc4a7f32334756/wow-forever-addon (UI look,
  icon, README and store page, CI and release requirements shared by every WoW: Forever addon)


## Secure UI regression checks

`tools/typecheck.sh` checks the TOC/XML load graph, LuaLS coverage and `tools/lint_taint.py`.
`tools/forever_tools/` is the shared tooling (cjber/skills, `wow-forever-addon/tooling`), vendored byte for byte: never edit it here.
`python3 tools/forever_tools/sync.py check` verifies it offline; `sync.py update --source <checkout>` is the only way to refresh it.
Register tracker sections after `PLAYER_ENTERING_WORLD` and `VARIABLES_LOADED`, deferred one frame
so Blizzard finishes its own initialization. This supersedes WFA-5's AddContainer hook guidance.
A `taint-ok` exception must identify an addon-owned object or a verified safe contract; it cannot
excuse hooking a native frame. Test event ordering and reuse, not just method existence.
