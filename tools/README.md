Run from the repository root with Python 3.

```sh
python3 tools/gen_overlays.py      # Data/Overlays.lua (stdlib only)
python3 tools/gen_camp.py          # Data/CampBenefits.lua (stdlib only)
python3 tools/latest_build.py      # newest Forever build on wago.tools
python3 tools/changelog.py 0.1.0   # one version's CHANGELOG entry
python3 tools/screenshots.py       # docs/screenshots/*.png (Pillow)
python3 tools/tooltip_border.py    # media/TooltipBorder.tga (stdlib only)
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
description instead. It refuses to write a number that depends on level, stats or
content tuning, and fails on any token it can't resolve. Same cache and flags as
`gen_overlays.py`.

The *Refresh game data* workflow runs `latest_build.py` daily, and when a newer
build is listed it bumps `BUILD` in both generators, regenerates, runs the checks and
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

`tooltip_border.py` draws `media/TooltipBorder.tga`, the rounded one-unit border
*Retail-style tooltips* puts on a tooltip in place of Forever's beige one, at two
texels per unit: 7-unit corners and a 2-unit middle that `Tooltips.lua` stretches
along each edge, lit brighter along the top and tinted grey in game. The file holds
only the line, with no shadow beside it, because tooltips draw without pixel snapping
and a dark texel next to the line shows as a black strip. Two runs give
byte-identical files.

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
Use `f((select(2, UnitClass(unit))))` or a local for a single value. Intentional expansion requires
a trailing `-- multi-value: reason` on the closing call/table/return line. A keyed table field,
assignment, operator or non-final argument already consumes one value.

The gate runs the Python regression tests first; run them separately with
`python3 -m unittest discover -s tools -p '*_test.py'`. Reports use `file:line: code: message`,
and missing/malformed reports and checker crashes fail closed.
