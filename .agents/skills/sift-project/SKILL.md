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
| Duplication, small | same command with `--min-lines 3 --min-tokens 30` and `**/tests/**` added to `--ignore` | the defaults missed the 6–11 line bag-hook clones between Bags/Junk.lua and Bags/Gear.lua; this run found them. Repeated checkout/setup-uv steps in ci.yml are expected. |
| Writable globals never written | for each `globals` entry, `rg -n 'NAME\s*=' -g '*.lua' -g '!types/**' .` | luacheck accepts a writable global that is only read; move it to `read_globals` (the nameplate APIs sat there from #38 to this audit) |
| Dead annotation fields | for each `---@field NAME` in `types/`, `rg -w NAME -g '*.lua' -g '!types/**' .` | fields of Blizzard objects the addon only reads through a hook still need one production reader |
| Standards (`wow-forever-addon`) | `SIFT_STANDARDS_PATH=/home/cjber/skills python3 ~/.agents/skills/sift/scripts/agents.py standards` | without the variable the pack reports as not installed; findings use `rule_id` `standards` with `what` starting `WFA-n:` |
| Unused allowed globals | for each name in `.luacheckrc`, `rg -wl NAME -g '*.lua' -g '*.xml' -g '!tests/**' -g '!types/**' -g '!Data/**' .` | luacheck never reports an unused `read_globals` entry, so these pile up when a feature drops an API; check open branches before removing one |

String-named entrypoints (always pass a path: `rg` with no path reads stdin when it is not a terminal):

```sh
rg -n 'RegisterEvent|SetScript|hooksecurefunc|OnSettingChanged|SLASH_|SlashCmdList|_G\[' -g '*.lua' .
```

## Live roots

- `TweaksForever.toc` — the file list and load order. `Core/Core.lua` defines `ns.Feature`/`ns.On`/`ns.Init`
  before any feature file runs; declaration order sets the settings subpage order and the order `ns.Init`
  callbacks run at login. Never reorder.
- SavedVariables `TweaksForeverDB` (feature keys, `junk`, `windowLayouts`, `savedSounds`, `lastVersion`) and
  `TweaksForeverCharDB` (`groups`, `colours`, `beforeFishing`) — persisted formats; keys are data.
- Feature `key`s are persisted and also form the setting variable `"TweaksForever_" .. key`, built only by
  Core's `ns.SettingVariable`; feature files take setting changes through `ns.OnSettingChanged(key, fn)`.
- `ns.On("<EVENT>")`, `hooksecurefunc("<Function>")` and `HookScript("<Script>")` name Blizzard events, functions
  and scripts as strings.
- `UI/Errors.lua` builds `_G["LE_GAME_ERR_" .. name]`; `UI/Frames.lua` resolves `_G[record.name]` and loads the
  listed load-on-demand addons.
- Slash commands: `SLASH_TWEAKSFOREVER1`, `SLASH_TWEAKSFOREVER_RELOAD1` with `SlashCmdList` entries.
- Global frame `TweaksForeverFishingButton` — the binding clicks it by name.
- `TweaksForever.API` (Core/API.lua, typed in `types/API.lua`) — the public addon-to-addon interface other addons
  (Adventure Guide Forever) call; every field is public surface. `TweaksForever_OnAddonCompartmentClick` is named
  by the TOC's `AddonCompartmentFunc`.
- `ShortestPathForever.API` (Integrations/Navigate.lua) and QuestieDB (`ns.QuestieDB`, QuestGivers/QuestProgress) — other addons'
  APIs read at runtime, the TOC's `OptionalDeps`.
- `ns.HookBagButtons` and `ns.IsBagActionClick` (Core/Core.lua) — the one home for bag-slot button hooks and
  the remappable-click guard, used by Bags/Junk.lua and Bags/Gear.lua. The specs never run `ns.Init`, so a change here
  needs a stubbed load of Core + the feature file (hook-registration trace) to show behaviour is unchanged.
- `ns.Junk`, `ns.Gear`, `ns.Fishing`, `ns.Frames`, `ns.Exploration`, `ns.Sections`, `ns.Reagents`, `ns.Camp`,
  `ns.ZoneLevels`, `ns.Entrances`, `ns.FutureSpells` — pure `Model` tables exported for the specs, each named
  once in production. Some are also cross-file APIs: `ns.Fishing.IsPole` (Gear), `ns.Gear.MarksOf`/`ColourOf`/
  `OnRefresh`/`Settling` (Sections), `ns.Sections` constants, `lift` and `Relayout` (Reagents).
- `ns.ClickMode` (Core/Modes.lua), `ns.ForEachBagButton`, `ns.ConflictOf`, `ns.Print` (Core/Core.lua), `ns.Suggestion`
  (Integrations/Companions.lua), `ns.Navigate`/`ns.NavigateHint` (Integrations/Navigate.lua), and Spellbook's `ns.KnownSpell`, `ns.TrainerSpells`,
  `ns.LineName`, `ns.GeneralName` (also read by Core/API.lua) — shared helpers.
- `ns.QuestDistance`, `ns.QuestGivers`, `ns.QuestProgress`, `ns.WhatsNew` — more `Model` tables exported for the specs.
- `ns.CampBenefits`, `ns.ZoneRanges`, `ns.DungeonEntrances`, `ns.InstanceEntrances`, `ns.RaidInstances`,
  `ns.Overlays`, `ns.ClassSpells` — generated `Data/` tables.
- `ns.L` (`Locales/enUS.lua`) and each translation's `Locales/<locale>.lua`, which only sets `ns.L` entries;
  `Locales/phrases.txt` is `tools/phrases.py`'s template for translators.
- `TweaksForeverDungeonEntrancePinMixin` — global named by `Map/DungeonEntrances.xml`'s pin template.
- `TweaksForeverCharDB.trainer` (Spellbook) — persisted trainer scan.
- Conflict entries name other addons' folders and read their saved variables (`LeaPlusDB.X == "On"`,
  `LegacyForeverDB`, `LeaMapsDB`, Questie, Mapster via LibStub) — external contracts.
- `tools/changelog.py` is run by `release.yml`; `refresh-data.yml` seds `BUILD` in and runs every
  `tools/gen_*.py`, so a new generator must be added there and in both READMEs.
- `.pkgmeta` `ignore:` — every non-dot file not listed ships in the addon zip. New tool configs at the root
  (like `ruff.toml`) must be added there. The pinned packager prunes every dot-path itself (release.sh:1828 at
  v2.6.1), so dot-files are never listed.

## Settled

Shapes that look like defects here but are not. Reviewers and verifiers read this before raising a
finding.

- stringly-typed on `UI/Frames.lua` `Model.LayoutKey`/`Model.Prune` (`"account"`, `"preset"`, character GUID):
  these strings are the persisted `windowLayouts` key format; changing them changes saved data.
- stringly-typed on the `gearMark` values (`Bags/Gear.lua`): the three-member set already fails loudly on an
  unknown value (`error("unknown gear mark …")`).
- Model fields named once in production (`ns.Junk`, `ns.Camp`, …) and `types/` classes referenced once
  (`NamePlateFrame`, `SpellBookFrameTemplate_PagedSpellsFrame`, `SpellBookSingleSkillLineCategoryMixin`,
  `TFEntrancePin`): spec exports and annotations of external or XML-made objects, not dead code.
- `Bags/Sections.lua` `Layout`/`Bags/Reagents.lua` `Reserve`: they share only the fits-at-`MIN_SCALE` check and two resize calls,
  and `MIN_SCALE` is already one constant; each owns its own state.
- `tools/screenshots.py` restates Lua layout constants on purpose: it draws without the game.
- `Bags/Sections.lua`/`Bags/Reagents.lua` `Relayout`: a three-line schedule idiom, not a shared implementation.
- Gear's colour kinds `"group"`/`"set"`/`"fishing"`: persisted keys in `TweaksForeverCharDB.colours`.
- Junk `Model.SaleValue`'s `not info` (an empty slot's info is nil; the spec calls the model directly) and
  Campsites' `if x and y and map` after `Here()` (which returns nothing where the position is secret).
- Gear's `Char()` short alias, Frames' repeated `if Active() then Schedule() end`, and Tooltips'
  single-caller `HealthBarStyle` (kept under the function-length limit).
- Small nil-safe reads of a saved variable or a Questie profile option (`Features/Automation.lua`, `Quests/QuestDistance.lua`):
  each site reads a different option for a different predicate, not one implementation.
- Junk's and Gear's click and mark guards: Gear needs `gearGroups` and Ctrl, Junk `markJunk` and Alt; Junk's icons
  show saved marks while selling blocks unknown quality for Leatrix, as `junk_spec` asserts.
- `Core/API.lua`'s `TweaksForever = TweaksForever or {}`: the shared global is a trust boundary; attach, never replace.
- The Sections/Reagents quotient-and-remainder grid placement: a small idiom over different contracts.
- `UI/Spellbook.lua`'s size: one Future Spells feature whose scan, selection and drawing share ClassData and Tabs.
- The README middle-dot footer and the `Options → …` arrow paths: the owner's house style across the docs.

## Anti-patterns

Shapes this codebase has produced more than once and a reviewer confirmed. Check new code against them.


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
| `docs/features.md`, `Locales/README.md` | docs | |
| `Locales/phrases.txt` | generated | written by `python3 -m tools.phrases --write`; never edit or review |
| `.sift/gate.py`, `.sift/agents.py`, `.sift/LICENSE` | vendor | copied byte for byte from sift; changed only by `sift update` |
| `media/`, `docs/screenshots/` | asset | not reviewed |
| `.agents/`, `.sift/` | docs | this profile and audit reports |

## Conventions

- Each file starts `local _, ns = ...`, declares its features with `ns.Feature{…}` at the top, then acts only
  inside `ns.Init` / `ns.On` handlers and checks `ns.Active(key)` at the moment it acts.
- Pure logic goes in a local `Model` table exported on `ns` so specs can load the file headlessly.
- PascalCase local functions, UPPER_CASE constants, tabs, 120 columns. British spelling in UI text.
- Comments are short and state why: client quirks ("Camelot", "Forever"), taint and combat restrictions.
- No error handling beyond `xpcall` in Core's dispatcher and `pcall` around other addons' code (conflict and
  `needs` checks in `ns.RefreshConflicts`, QuestieDB in `ns.QuestieDB`); host-API guards (`X and X()`) cover functions
  absent on this client.

## Risk order

Audit slices from lowest to highest risk:

1. `tools/`, `README.md`, `.github/` — no player-facing effect.
2. `tests/` — specs only.
3. `UI/Reload.lua`, `UI/Errors.lua`, `Bags/Vendor.lua`, `UI/Settings.lua`, `UI/WhatsNew.lua`, `Integrations/Companions.lua`, `Integrations/Navigate.lua`,
   `UI/MacroNames.lua`, `Core/API.lua`, `Core/Core.lua` — small; Core is shared by all, API is public surface.
4. `Features/Automation.lua`, `Map/Exploration.lua`, `Features/Fishing.lua`, `Core/Modes.lua`, `Map/Campsites.lua`, `Quests/QuestDistance.lua`,
   `Quests/QuestGivers.lua`, `Quests/QuestProgress.lua`, `Map/ZoneLevels.lua`, `Map/DungeonEntrances.lua`/`.xml`, `UI/Spellbook.lua` — event
   handlers, map pins, the tracker, one secure button.
5. `UI/Tooltips.lua`, `UI/Nameplates.lua`, `Bags/Sections.lua`, `Bags/Reagents.lua` — restyle Blizzard frames; in-game only.
6. `Bags/Junk.lua`, `Bags/Gear.lua` — bag hooks, selling items and equipping gear.
7. `UI/Frames.lua` — hooks Edit Mode and panel positioning; taint-sensitive.

## Project rules and lenses

- Rules: `unused-luacheck-global` (`.sift/scripts/unused-luacheck-global.py`): a `.luacheckrc` global that no
  tracked Lua, XML or `Locales/phrases.txt` names.
- Rules: `setting-callback-outside-core` (`.sift/scripts/setting-callback-outside-core.py`): a
  `SetOnValueChangedCallback` call outside Core/Core.lua; use `ns.OnSettingChanged`.
- Lenses: none yet.

The type gate also runs `python3 -m tools.lint_taint` and `python3 tools/typecheck_coverage.py`: native-method hooks, shared UI-state writes and omitted runtime type coverage fail CI. Tracker initialization follows both native load events, deferred one frame; AddContainer hooks are retired.
