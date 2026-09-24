---
name: sift-project
description: "Project profile for sift in Tweaks Forever: the exact quality-gate and evidence commands, live roots that must never be deleted as dead code, exclusions, conventions and risk order. Load before running sift or any code-quality, cleanup or dead-code work in this repository."
---

# sift project profile — Tweaks Forever

A World of Warcraft addon for the WoW: Forever client (`## Interface: 16001`; the client's own UI code is
called "Camelot" in comments). Lua 5.1 run by the game, loaded in `.toc` order, no `require`. Packaged by
the BigWigs packager on a `v*` tag; players install the zip. Stdlib-only Python scripts under `tools/`
support it. Headless specs run under LuaJIT with stubbed WoW globals; they cannot exercise the real client.

## Gate

Run in order from the repository root. All must pass before and after any audit slice.

| Step | Command | Pass means |
|---|---|---|
| Format (Lua) | `stylua --check .` (StyLua 2.5.2) | exit 0 |
| Lint (Lua) | `luacheck .` | `0 warnings / 0 errors` |
| Types (Lua) | `tools/typecheck.sh` (LuaLS 3.19.1) | no diagnostics; multi-value lint and tooling tests pass |
| Tests (Lua) | specs loop (below) | each prints `…: ok`, exit 0 |
| Lint + format (Python) | `ruff check tools && ruff format --check tools` (ruff 0.16.8, `ruff.toml`) | exit 0 |
| Types (Python) | `uvx ty@0.0.83 check tools` | `All checks passed!` |
| Workflows | `uvx --from actionlint-py==1.7.12.25 actionlint && uvx zizmor@1.30.1 --offline .github` | no output / `No findings` |
| Secrets | `gitleaks git --redact --no-banner .` | `no leaks found` |
| Project rules | `python3 .sift/gate.py --base origin/main && python3 .sift/agents.py check` | exit 0 |

```sh
for spec in tests/*_spec.lua; do luajit "$spec" || exit 1; done
```

CI (`.github/workflows/ci.yml`) runs all of these. Run specs from the root: they `loadfile` by relative path.

## Evidence

On-demand tools for audits. Output is candidates, never verdicts.

| Concern | Command | Known false positives |
|---|---|---|
| Dead code (Lua) | `luacheck .` (unused locals/args are in the gate) plus the live-roots search below | Model functions used only by specs are live: specs are the reason they are exported. |
| Dead code (Python) | `uvx vulture tools --min-confidence 60` | none seen |
| Duplication | `npx --yes jscpd@4 --silent --reporters json --output .sift/runs/evidence/jscpd --ignore "**/.sift/**,**/Data/*.lua" .` | the spec files share a 10-line `ns` stub preamble on purpose (each spec is standalone) |
| Duplication, small | same command with `--min-lines 3 --min-tokens 30` and `**/tests/**` added to `--ignore` | the defaults missed the 6–11 line bag-hook clones between Junk.lua and Gear.lua; this run found them. Repeated checkout/setup-uv steps in ci.yml are expected. |
| Unused allowed globals | for each name in `.luacheckrc`, `rg -wl NAME -g '*.lua' -g '*.xml' -g '!tests/**' -g '!types/**' -g '!Data/**' .` | luacheck never reports an unused `read_globals` entry, so these pile up when a feature drops an API; check open branches before removing one |

String-named entrypoints (always pass a path: `rg` with no path reads stdin when it is not a terminal):

```sh
rg -n 'RegisterEvent|SetScript|hooksecurefunc|SetOnValueChangedCallback|SLASH_|SlashCmdList|_G\[' -g '*.lua' .
```

## Live roots

- `TweaksForever.toc` — the file list and load order. `Core.lua` defines `ns.Feature`/`ns.On`/`ns.Init`
  before any feature file runs; declaration order sets the settings subpage order and the order `ns.Init`
  callbacks run at login. Never reorder.
- SavedVariables `TweaksForeverDB` (feature keys, `junk`, `windowLayouts`, `savedSounds`) and
  `TweaksForeverCharDB` (`groups`, `colours`, `beforeFishing`) — persisted formats; keys are data.
- Feature `key`s are persisted and also form the setting variable `"TweaksForever_" .. key`, looked up by
  string in `Settings.SetOnValueChangedCallback` calls (Fishing, Gear, Frames).
- `ns.On("<EVENT>")` and `hooksecurefunc(obj, "<method>")` name Blizzard events and methods as strings.
- `Errors.lua` builds `_G["LE_GAME_ERR_" .. name]`; `Frames.lua` resolves `_G[record.name]` and loads the
  listed load-on-demand addons.
- Slash commands: `SLASH_TWEAKSFOREVER1`, `SLASH_TWEAKSFOREVER_RELOAD1` with `SlashCmdList` entries.
- Global frame `TweaksForeverFishingButton` — the binding clicks it by name.
- `ns.HookBagButtons` and `ns.IsBagActionClick` (Core.lua) — the one home for bag-slot button hooks and
  the remappable-click guard, used by Junk.lua and Gear.lua. The specs never run `ns.Init`, so a change here
  needs a stubbed load of Core + the feature file (hook-registration trace) to show behaviour is unchanged.
- `ns.Junk`, `ns.Gear`, `ns.Fishing`, `ns.Frames`, `ns.Exploration`, `ns.Sections`, `ns.Reagents`, `ns.Camp`,
  `ns.ZoneLevels`, `ns.Entrances`, `ns.FutureSpells` — pure `Model` tables exported for the specs, each named
  once in production. Some are also cross-file APIs: `ns.Fishing.IsPole` (Gear), `ns.Gear.MarksOf`/`ColourOf`/
  `OnRefresh`/`Settling` (Sections), `ns.Sections` constants and `lift`/`Sectioned` (Reagents).
- `ns.ClickMode` (Modes.lua), `ns.ForEachBagButton`, `ns.ConflictOf`, `ns.Print` (Core.lua) — shared helpers.
- `ns.CampBenefits`, `ns.ZoneRanges`, `ns.DungeonEntrances`, `ns.Overlays` — generated `Data/` tables.
- `TweaksForeverDungeonEntrancePinMixin` — global named by `DungeonEntrances.xml`'s pin template.
- `TweaksForeverCharDB.trainer` (Spellbook) — persisted trainer scan.
- Conflict entries name other addons' folders and read their saved variables (`LeaPlusDB.X == "On"`,
  `LegacyForeverDB`, `LeaMapsDB`, Questie, Mapster via LibStub) — external contracts.
- `tools/changelog.py` is run by `release.yml`; `refresh-data.yml` seds `BUILD` in and runs every
  `tools/gen_*.py`, so a new generator must be added there and in both READMEs.
- `.pkgmeta` `ignore:` — every non-dot file not listed ships in the addon zip. New tool configs at the root
  (like `ruff.toml`) must be added there; dot-files are skipped by the packager.

## Dismissed candidates

- stringly-typed on `Frames.lua` `Model.LayoutKey`/`Model.Prune` (`"account"`, `"preset"`, character GUID):
  these strings are the persisted `windowLayouts` key format; changing them changes saved data.
- stringly-typed on the `gearMark` values (`Gear.lua`): the three-member set already fails loudly on an
  unknown value (`error("unknown gear mark …")`).
- Model fields named once in production (`ns.Junk`, `ns.Camp`, …) and `types/` classes referenced once
  (`NamePlateFrame`, `SpellBookFrameTemplate_PagedSpellsFrame`, `SpellBookSingleSkillLineCategoryMixin`,
  `TFEntrancePin`): spec exports and annotations of external or XML-made objects, not dead code.
- `Sections.lua`/`Reagents.lua` `Grow`: they share only the fits-at-`MIN_SCALE` check and two resize calls,
  and `MIN_SCALE` is already one constant; each owns its own state.
- `tools/screenshots.py` restates Lua layout constants on purpose: it draws without the game.
- Gear's `Char()` short alias, Frames' repeated `if Active() then Schedule() end`, and Tooltips'
  single-caller `HealthBarStyle` (kept under the function-length limit).

## Zones

Unlisted paths are `production`.

| Path | Zone | Reason |
|---|---|---|
| `Data/*.lua` | generated | written by the `tools/gen_*.py` script its header names; never edit or review |
| `tests/` | test | headless LuaJIT specs with stubbed globals |
| `tools/` | script | release notes, data generation, lint and type-check helpers |
| `types/` | config | LuaLS annotations only; never loaded in game |
| `.github/`, `.gitattributes`, `.pkgmeta`, `.luacheckrc`, `.luarc.json`, `stylua.toml`, `ruff.toml` | config | |
| `README.md`, `CHANGELOG.md`, `AGENTS.md`, `tools/README.md` | docs | CHANGELOG entries are release notes; history by design |
| `docs/curseforge.md` | docs | the store page, pasted by hand; its facts must match the README |
| `media/`, `docs/screenshots/` | asset | not reviewed |
| `.agents/`, `.sift/` | docs | this profile and audit reports |

## Conventions

- Each file starts `local _, ns = ...`, declares its features with `ns.Feature{…}` at the top, then acts only
  inside `ns.Init` / `ns.On` handlers and checks `ns.Active(key)` at the moment it acts.
- Pure logic goes in a local `Model` table exported on `ns` so specs can load the file headlessly.
- PascalCase local functions, UPPER_CASE constants, tabs, 120 columns. British spelling in UI text.
- Comments are short and state why: client quirks ("Camelot", "Forever"), taint and combat restrictions.
- No error handling beyond `xpcall` in Core's dispatcher; host-API guards (`X and X()`) cover functions
  absent on this client.

## Risk order

Audit slices from lowest to highest risk:

1. `tools/`, `README.md`, `.github/` — no player-facing effect.
2. `tests/` — specs only.
3. `Reload.lua`, `Errors.lua`, `Vendor.lua`, `Settings.lua`, `Core.lua` — small; Core is shared by all.
4. `Automation.lua`, `Exploration.lua`, `Fishing.lua`, `Modes.lua`, `Campsites.lua`, `QuestDistance.lua`,
   `ZoneLevels.lua`, `DungeonEntrances.lua`/`.xml`, `Spellbook.lua` — event handlers, map pins, one secure button.
5. `Tooltips.lua`, `Nameplates.lua`, `Sections.lua`, `Reagents.lua` — restyle Blizzard frames; in-game only.
6. `Junk.lua`, `Gear.lua` — bag hooks, selling items and equipping gear.
7. `Frames.lua` — hooks Edit Mode and panel positioning; taint-sensitive.

## Project rules and lenses

- Rules: none yet.
- Lenses: none yet.
