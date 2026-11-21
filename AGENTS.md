# AGENTS.md

Tweaks Forever is a WoW: Forever addon (Interface 16001) that replaces single-purpose addons with options in the
game's own settings. It needs ForeverCore (declared in `## OptionalDeps` so it can load and explain a missing core; the
release pinned in `tools/forever-core.txt` ships in the zip). ForeverCore owns the shared tracker column, error journal,
report window and settings chrome. `Core/Require.lua` stops the addon with one on-screen line when the loaded core lacks
a member this addon calls (`APIKit.Hub`, `APIKit.NotReady`), never by version. Players install the zip the BigWigs
packager builds on a `v*` tag.

## Commands

```sh
python3 tools/doctor.py             # first on a new machine: every tool pin, with a fix for each problem
python3 tools/gate.py               # the fast local gate: format, lint, typecheck, specs, generated data, changelog, rules
python3 tools/gate.py --changed     # only the steps the diff against origin/main reaches
```

`gate.py` loads ForeverCore from `$FOREVER_CORE`, else `../forever-core`: set it in a worktree. CI runs the same checks
plus the simulator (`tools/forever_sim`), the package build, actionlint, zizmor and gitleaks. After a data change,
the matching `tools/gen_*.py` regenerates a `Data/*` file; after a text change, `python3 -m tools.phrases --write`.
A change's player-facing notes go in `changes/<issue>.md`; only the release commit edits `CHANGELOG.md`
(`python3 tools/changelog.py release X.Y.Z`). Release: `.agents/skills/release/SKILL.md`.

## Layout

- `Core/Core.lua` has `ns.Feature`/`ns.On`/`ns.Init`; every feature file registers through it, naming its settings
  page and heading (`UI/Settings.lua` lists them in order). A new file goes in `TweaksForever.toc` or never runs (Lua 5.1, no `require`).
- `Bags/`, `Quests/`, `Map/`, `Features/`, `Chat/`: feature modules by the part of the game they change. `UI/`:
  settings, tooltips, nameplates, `UI/Art.lua`. `Integrations/QuestieSource.lua` is the one place QuestieDB is opened.
- `Data/`: lookup tables for what neither QuestieDB nor AtlasLoot holds; a generated one names its generator and
  sources in its header. `Locales/enUS.lua` is keyed by the English text.
- Also ships `LibAHTab`. `tools/forever_tools/` and `tools/forever_sim/` are vendored: never edit them here.

## Rules

- On a map, draw only through `Map/MapDraw.lua`: frames of our own, made with no parent and then set on the canvas.
  Never `AddDataProvider`, `AcquirePin`, `AddOverlayFrame` or a `MapCanvasPinMixin`: the gamepad interface walks the
  map's providers from secure code (#168). `tests/map_canvas_spec.lua` enforces it.
- Register tracker sections after `PLAYER_ENTERING_WORLD` and `VARIABLES_LOADED`, deferred one frame, so Blizzard
  finishes its own initialization. This supersedes WFA-5's AddContainer hook guidance. Test event ordering and reuse.
- Player-visible text goes through `L["whole sentence"]`, or a Blizzard GlobalString that says exactly the same;
  `ns.Feature`/`ns.ClickMode` text stays plain English.
- A feature another loaded addon already provides is greyed out with that addon named, never run alongside it. Repairs,
  selling junk and faster auto loot start on; every other automation that acts for the player is off by default.
- Never touch Blizzard's Lua state (WFA-38): no `hooksecurefunc(object, ...)`, replaced method or field written on a
  Blizzard table; to restyle a Blizzard element, draw our own frame on top and set theirs to alpha 0.
- Never stretch art: draw icons and atlases at native aspect through `UI/Art.lua` (`Art.Fit`, `Art.Markup`);
  `tools/lint_art.py` refuses a raw `SetAtlas`/`SetTexture` elsewhere unless its line says `-- art-ok: reason`.
- New host globals go in `.luacheckrc`, with real types in `types/Forever.lua` where upstream lacks them. Never add a
  LuaLS globals allowlist.
- Specs are an offline harness with stubbed client APIs. Frames, menus, tooltips and the tracker are checked by hand in
  game; the PR lists what was checked.

## Waivers

Owner-approved exceptions to `wow-forever-addon`:

- WFA-2: Reveal unexplored areas and Hide macro names are off by default (spoiler; changes players' own bars).
- WFA-4: tooltips default to the charcoal Modern style, a headline feature pictured on the store page.
- WFA-13: `Quests/QuestDistance.lua`'s 1 s ticker stays: the only catch for Questie tracker toggles, which set no flag.
- WFA-28, data neither QuestieDB nor AtlasLoot holds, each sourced in its file: class trainer spells and trainer NPC
  ids (`Data/ClassSpells.lua`, CMaNGOS classic-db plus the client's DB2; a trainer visit's own list wins), pet family
  abilities, dungeon entrances, world map overlays, camp benefit texts and quests added in Forever (the client's
  tables on wago.tools), and zone level ranges (warcraft.wiki.gg for the original zones, the client's
  `AreaTable.ExplorationLevel` for new ones). `C_Map.GetMapLevels` and a live aura win over the bundled row.

- Before cleanup, dead-code or refactoring work, read the live roots and settled shapes in `.sloppatrol/instructions.md`.

## Standards

- `wow-forever-addon`: https://github.com/cjber/forever-core/tree/main/.agents/skills/wow-forever-addon (the WFA-*
  requirements every WoW: Forever addon meets: UI look, assets, README and store page, CI and releases)
- `wow-retail-ui-style`: https://github.com/cjber/forever-core/tree/main/.agents/skills/wow-retail-ui-style
- `repo-standards`: the RS-* requirements every cjber and agent-labs-dev repo meets; its `audit.py` checks this repo.
