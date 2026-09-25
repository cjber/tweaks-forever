Run from the repository root with Python 3.

```sh
python3 tools/gen_overlays.py      # Data/Overlays.lua (stdlib only)
python3 tools/gen_camp.py          # Data/CampBenefits.lua (stdlib only)
python3 tools/gen_zonelevels.py    # Data/ZoneLevels.lua (stdlib only)
python3 tools/gen_dungeons.py      # Data/DungeonEntrances.lua (stdlib only)
python3 tools/gen_classspells.py   # Data/ClassSpells.lua (stdlib only)
python3 tools/latest_build.py      # newest Forever build on wago.tools
python3 tools/changelog.py 0.1.0   # one version's CHANGELOG entry
python3 tools/screenshots.py       # docs/screenshots/*.png (Pillow)
python3 tools/tooltip_border.py    # media/TooltipBorder{Modern,Retail}.tga (stdlib only)
python3 -m tools.phrases --write     # Locales/phrases.txt, the template translators copy (stdlib only)
```

`gen_overlays.py` pins a Forever build and writes `Data/Overlays.lua`: the map art
the game draws over explored parts of each zone, which *Reveal unexplored areas*
shows for the parts you haven't explored. It joins four same-build DB2 exports from
wago.tools: `WorldMapOverlay` (each area's rectangle on its map art),
`WorldMapOverlayTile` (the texture file for each tile), `UiMapArt` and
`UiMapArtStyleLayer` (tile size per layer). Each overlay becomes one record per
layer of rectangle and row-major file IDs, decoded only when that map is viewed.
Downloads are cached in `tools/.cache/`; `--refresh` downloads again and
`--offline` requires the cache. Malformed exports, orphan or missing tiles and
overlays gated by a player condition fail before the output is replaced. Overlays
with no tiles are counted and skipped.

`gen_camp.py` writes `Data/CampBenefits.lua`: what each camp feature gives, in the
game's own words and numbers. The Camp Benefits aura's description (`Spell`) is a
template with one `$?a<aura>[Feature: effect][]` branch per feature aura; the
script takes each branch and fills in `$w` (effect base points, `SpellEffect`), `$t`
(effect period) and `$d` (`SpellMisc` duration index into `SpellDuration`). The tent's
branch only says rest was received, so its entry uses the Camp Tent aura's own
description instead. Each entry also lists the base points it put in for `$w`, in effect
order, so the addon can put in the values the aura you get actually carries. It refuses to write a number that depends on level, stats or
content tuning, and fails on any token it can't resolve. Same cache and flags as
`gen_overlays.py`.

`gen_zonelevels.py` writes `Data/ZoneLevels.lua`: each zone's level range, which
Forever's client leaves empty (its `UiMap` and `AreaTable` carry no content tuning).
Zones of the original game take their published range, listed in the script. Forever's
own zones take the lowest and highest `AreaTable.ExplorationLevel` among their
subzones. Cities and battlegrounds are left out; so is a new zone with no exploration
level, which the run lists. A published zone missing from the maps fails the run.
Same cache and flags as `gen_overlays.py`.

`gen_dungeons.py` writes `Data/DungeonEntrances.lua`: where each dungeon and raid
entrance sits on the world map. Blizzard's map asks `C_EncounterJournal`, which is
empty without the journal's tables that Forever's client lacks. The entrance is
`Map.Corpse_0/1` on `CorpseMapID`, the point a ghost walks back in from, projected
through `UiMapAssignment` exactly as Legacy Forever places its instance pins. Which zone
map shows an entrance is curated in the script (zone rectangles overlap); continents
take every entrance on them. `ns.InstanceEntrances` preserves each instance's first
curated zone projection for the public API before clustering. Entrances whose icons
would overlap on the minimized map at its smallest zoom merge into one pin at their centre, and the curated
complexes (Blackrock Mountain, the Gates of Ahn'Qiraj) always do, named by their
area. An instance with an entrance but no curated zone fails the run; instances
with no entrance at all are listed. Same cache and flags as `gen_overlays.py`.

`gen_classspells.py` writes `Data/ClassSpells.lua`: what each class trainer teaches,
for *Show future spells in the spellbook* before you have visited one. Forever's client
has no trainer lists, so the rows come from the class trainers in CMaNGOS classic-db
(pinned by commit), each teaching spell resolved to the spell you learn through the
Classic Era client's `SpellEffect` (Forever's drops most teaching spells). Forever's
`SkillLineAbility` gives each spell's class skill line, kept by ID as a tab's name is in
the client's language, and its races; `Spell`'s rank subtext names the rank before one
no trainer teaches (a talent, quest or starting spell), which has to be known first.
Spells the client lacks or on no class skill line are counted and left out. Same cache
and flags as `gen_overlays.py`.

The *Refresh game data* workflow runs `latest_build.py` daily, and when a newer
build is listed it bumps `BUILD` in every generator, regenerates, runs the checks and
opens a PR.

`changelog.py` prints the section of `CHANGELOG.md` for one version; the release
workflow passes it to the packager as the release notes, and fails on a tag with
no entry.

`screenshots.py` renders `docs/screenshots/*.png` without the game: the client's
own UI art, fonts and item icons from wago.tools, laid out as Blizzard's UI code and
the addon's own modules draw them, using the `wowmock` library from the
[wow-mock-screenshots](https://github.com/cjber/skills/tree/main/wow-mock-screenshots)
skill. It looks for the library in `$WOWMOCK`, else
`~/.claude/skills/wow-mock-screenshots`, and needs Pillow. Two runs give
byte-identical images.

`tooltip_border.py` draws `media/TooltipBorderModern.tga` and
`media/TooltipBorderRetail.tga`, the whole tooltip *Modern tooltips* draws in place of
Forever's beige one, one file per Tooltip style: a rounded one-unit grey line lit
brighter along the top, with the tooltip's background baked in everywhere inside it,
at two texels per unit. `Tooltips.lua` cuts all nine NineSlice pieces from one such
file, the Center included: the 7-unit corners, and a 2-unit middle it stretches along
each edge and across the middle. Tooltips draw without pixel snapping, so the line and
the background have to be one image; as two textures meeting edge to edge, a sub-pixel
gap opens between them on one side or the other. The colours are final, drawn
untinted. Two runs give byte-identical files.

## Lua type checking

Run `tools/typecheck.sh` from any directory with LuaLS 3.19.1, Git and Python 3.11+ on PATH.
CI uses the same entrypoint and verifies the LuaLS release tarball's SHA-256. API annotations are
pinned to Ketho/vscode-wow-api `d0b5b51fac4c52c493371b9b18e66ce604ea4326`, including its FrameXML gitlink
`2ffc9177b0e55a8a3f51baf47c2cfb0f54f685ee`. Modified or differently pinned checkouts fail the gate.

LuaLS checks runtime Lua and `types/`, including TOC-loaded generated data; the headless stubs in
`tests/` and tooling/cache directories are excluded. Luacheck and specs still cover the harness.
`types/` declares the addon's contracts and missing Forever/other-addon APIs; it never loads in game.

`python3 tools/lint_multivalue.py` checks every TOC entry, or the file paths supplied as arguments.
Lua expands an unparenthesised final call in an argument list, array-style table field or return.
This covers `select()` and the client's multi-return calls listed in `MULTI_RETURN` (`GetDrawLayer`,
`GetPoint`, `GetRGB`, `UnitClass`, …), bare, namespaced or as methods: `CreateTexture(nil, icon:GetDrawLayer())`
passes the sublevel as the template name. Add a multi-return API there when the addon starts calling it.
`select()`'s own final argument expands by design. Use `f((select(2, UnitClass(unit))))` or a local for a
single value. Intentional expansion requires
a trailing `-- multi-value: reason` on the closing call/table/return line. A keyed table field,
assignment, operator or non-final argument already consumes one value.

`python3 -m tools.lint_taint` checks the same files for code that taints Blizzard's UI on Forever:
`hooksecurefunc` on an object rather than a function name or a table the file built itself, a field
written or method defined on a global the addon does not own, and calls to Blizzard's bag and panel
layout, its lazy bag caches, `SetParentInitializer` and `AddMaskableTexture`. AGENTS.md lists what to
use instead. A deliberate exception takes a trailing `-- taint-ok: reason` on the flagged line.

The gate runs the Python regression tests first; run them separately with
`python3 -m unittest discover -s tools -p '*_test.py'`. Reports use `file:line: code: message`,
and missing/malformed reports and checker crashes fail closed.

`phrases.py` lists every phrase the addon translates: each `L["..."]` in the shipped Lua, plus the category,
name, tooltip and option labels an `ns.Feature` declares and the label and tooltip of an `ns.ClickMode`, which
Settings.lua and Modes.lua translate where they show them. The English text is the key. With no argument it prints
a translation template, a `Locales/<locale>.lua` with an `L["x"] = "x"` line per phrase; `--write` saves that to
`Locales/phrases.txt` for translators to copy. `--check` (in `tools/typecheck.sh`) fails when that file is stale,
when a declaration's text is not plain English, when shipped code hands text with words in it straight to a UI call
(`SetText`, `AddLine`, `ns.Print`, a menu button and the like) instead of through `L[...]` or a Blizzard string,
when a `Locales/*.lua` translation is missing from the TOC, or when a tracked file carries the packager's
CurseForge localization keyword, which fails the release now that CurseForge's localization is gone.
