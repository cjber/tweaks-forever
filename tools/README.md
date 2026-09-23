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

`tooltip_border.py` draws `media/TooltipBorder.tga`, the whole tooltip *Retail-style
tooltips* draws in place of Forever's beige one: a rounded one-unit grey line lit
brighter along the top, with the tooltip's background baked in everywhere inside it,
at two texels per unit. `Tooltips.lua` cuts all nine NineSlice pieces from this one
file, the Center included: the 7-unit corners, and a 2-unit middle it stretches along
each edge and across the middle. Tooltips draw without pixel snapping, so the line and
the background have to be one image; as two textures meeting edge to edge, a sub-pixel
gap opens between them on one side or the other. The colours are final, drawn
untinted. Two runs give byte-identical files.
