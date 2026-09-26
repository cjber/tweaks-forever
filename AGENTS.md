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
python3 tools/changelog.py --check
python3 .sift/gate.py --base origin/main && python3 .sift/agents.py check
```

The same gate CI runs, plus actionlint, zizmor and gitleaks on the workflows and history.
Every version needs a `CHANGELOG.md` entry (prose, bold-lead bullets) before its `v*` tag: the release
publishes that entry as its notes.

## Layout

- `Core.lua` — `ns.Feature`/`ns.On`/`ns.Init`; every feature file registers through it, and TOC
  order sets the settings subpage order.
- `Data/` — lookup tables; a generated one names the script that regenerates it in its header.
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
  alongside it. Automation that acts for the player is off by default.
- Never stretch art: an icon, atlas or texture is drawn at its native aspect (size it from
  `C_Texture.GetAtlasInfo`, fit inside the box); only nine-slice pieces, bars and fills stretch by design.
- Store copy, README and posts pitch the addon as looking like it came with the game, in cjber's
  own voice, never AI marketing: `wow-forever-addon` WFA-23/24, checked before every store paste.

## Standards

- `wow-forever-addon` — https://github.com/cjber/skills/tree/c587d4c74fcc27c97f73f2f7cb3d70cccebeb34e/wow-forever-addon (UI look,
  icon, README and store page, CI and release requirements shared by every WoW: Forever addon)
