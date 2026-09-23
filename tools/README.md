Run from the repository root with Python 3.

```sh
python3 tools/gen_overlays.py      # Data/Overlays.lua (stdlib only)
python3 tools/latest_build.py      # newest Forever build on wago.tools
python3 tools/changelog.py 0.1.0   # one version's CHANGELOG entry
python3 tools/screenshots.py       # docs/screenshots/*.png (Pillow)
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

The *Refresh map data* workflow runs `latest_build.py` daily, and when a newer
build is listed it bumps `BUILD`, regenerates, runs the checks and opens a PR.

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
