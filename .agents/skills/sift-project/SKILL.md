---
name: sift-project
description: "Project profile for sift in Tweaks Forever: the exact quality-gate and evidence commands, live roots that must never be deleted as dead code, exclusions, conventions and risk order. Load before running sift or any code-quality, cleanup or dead-code work in this repository."
---

# sift project profile — Tweaks Forever

A World of Warcraft addon for the WoW: Forever client (`## Interface: 16001`; the client's own UI code is
called "Camelot" in comments). Lua 5.1 run by the game, loaded in `.toc` order, no `require`. Packaged by
the BigWigs packager on a `v*` tag; players install the zip. Two stdlib-only Python scripts under `tools/`
support it. Headless specs run under LuaJIT with stubbed WoW globals; they cannot exercise the real client.

## Gate

Run in order from the repository root. All must pass before and after any audit slice.

| Step | Command | Pass means |
|---|---|---|
| Format (Lua) | `stylua --check .` (StyLua 2.5.2) | exit 0 |
| Lint (Lua) | `luacheck .` | `0 warnings / 0 errors` |
| Tests (Lua) | specs loop (below) | each prints `…: ok`, exit 0 |
| Lint + format (Python) | `ruff check tools && ruff format --check tools` (ruff 0.16.8, `ruff.toml`) | exit 0 |
| Types (Python) | `uvx ty@0.0.83 check tools` | `All checks passed!` |
| Workflows | `uvx --from actionlint-py==1.7.12.25 actionlint && uvx zizmor@1.30.1 --offline .github` | no output / `No findings` |
| Secrets | `gitleaks git --redact --no-banner .` | `no leaks found` |

```sh
for spec in tests/*_spec.lua; do luajit "$spec" || exit 1; done
```

CI (`.github/workflows/ci.yml`) runs all of these. Run specs from the root: they `loadfile` by relative path.

## Evidence

On-demand tools for audits. Output is candidates, never verdicts.

| Concern | Command | Known false positives |
|---|---|---|
| Types (Lua) | once: `git clone -q --depth 1 --branch 0.22.3 https://github.com/Ketho/vscode-wow-api .luals/wow-api`; then `lua-language-server --check=. --checklevel=Warning --check_format=json --check_out_path=.sift/runs/luals/check.json` | The annotations model the retail client. Known: `SelectActiveQuest`/`SelectAvailableQuest` take an index here (Automation.lua); a submenu `root:CreateButton("Colour")` needs no callback (Gear.lua); `SecureActionButtonTemplate` passed to binding APIs (Fishing.lua); the `ShouldDisplayMessageType` stub in `tests/errors_spec.lua`. Undefined globals are disabled in `.luarc.json`: luacheck owns them. Exit 1 whenever anything is reported; read the JSON. |
| Dead code (Lua) | `luacheck .` (unused locals/args are in the gate) plus the live-roots search below | Model functions used only by specs are live: specs are the reason they are exported. |
| Dead code (Python) | `uvx vulture tools --min-confidence 60` | none seen |
| Duplication | `npx --yes jscpd@4 --silent --reporters json --output .sift/runs/jscpd --ignore "**/.sift/**,**/.luals/**,**/Data/Overlays.lua" .` | the spec files share a 10-line `ns` stub preamble on purpose (each spec is standalone) |

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
- `ns.Junk`, `ns.Gear`, `ns.Fishing`, `ns.Frames`, `ns.Exploration` — pure `Model` tables exported for the
  specs; `ns.Fishing.IsPole` is also used by `Gear.lua`.
- Conflict entries name other addons' folders and read their saved variables (`LeaPlusDB.X == "On"`,
  `LegacyHereDB`, `LeaMapsDB`, Questie, Mapster via LibStub) — external contracts.
- `tools/changelog.py` is run by `release.yml`; `tools/gen_overlays.py` is documented in the README.
- `.pkgmeta` `ignore:` — every non-dot file not listed ships in the addon zip. New tool configs at the root
  (like `ruff.toml`) must be added there; dot-files are skipped by the packager.

## Zones

Unlisted paths are `production`.

| Path | Zone | Reason |
|---|---|---|
| `Data/Overlays.lua` | generated | written by `tools/gen_overlays.py`; never edit or review |
| `tests/` | test | headless LuaJIT specs with stubbed globals |
| `tools/` | script | release notes and data generation |
| `.github/`, `.pkgmeta`, `.luacheckrc`, `.luarc.json`, `stylua.toml`, `ruff.toml` | config | |
| `README.md`, `CHANGELOG.md` | docs | CHANGELOG entries are release notes; history by design |
| `media/` | asset | not reviewed |

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
4. `Automation.lua`, `Exploration.lua`, `Fishing.lua` — event handlers, one secure button.
5. `Junk.lua`, `Gear.lua` — bag hooks, selling items and equipping gear.
6. `Frames.lua` — hooks Edit Mode and panel positioning; taint-sensitive.

## Project rules and lenses

- Rules: none yet.
- Lenses: none yet.
