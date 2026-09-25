#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Generate zone level ranges for the pinned Forever client (stdlib only).

Forever's client links no zone to a level range (UiMap and AreaTable ContentTuningID are 0), so
C_Map.GetMapLevels returns nothing. Two sources fill the gap:

- Zones of the original game take its published range (PUBLISHED below).
- Every other zone the world or a continent map names on hover is one of Forever's own, and takes the lowest
  and highest AreaTable.ExplorationLevel among its subzones: the level the client gives for exploring each
  one. Checked against the original zones it lands close to their published ranges (Darkshore 11-19 against
  10-20, Desolace 30-39 against 30-40), though a stray subzone can stretch one (Dun Morogh 4-56), so the
  published range wins wherever there is one. Quest and creature levels are server-side and not in the DB2s.

Cities and battlegrounds have no range and are left out, and so is a new zone none of whose subzones carries
an exploration level; the script lists those so a newer build that adds one is noticed.
"""

import argparse
import csv
import io
import sys
import urllib.error
import urllib.request
from pathlib import Path

BUILD = "1.60.1.70009"
ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".cache"
OUTPUT = ROOT / "Data" / "ZoneLevels.lua"
AZEROTH = 947
ZONE, CONTINENT = 3, 2  # Enum.UIMapType
SOURCE = "https://warcraft.wiki.gg/wiki/Zones_by_level_(original)"
# The original game's published ranges, by UiMap ID.
PUBLISHED = {
    # Eastern Kingdoms
    1416: (30, 40),  # Alterac Mountains
    1417: (30, 40),  # Arathi Highlands
    1418: (35, 45),  # Badlands
    1419: (45, 55),  # Blasted Lands
    1420: (1, 10),  # Tirisfal Glades
    1421: (10, 20),  # Silverpine Forest
    1422: (51, 58),  # Western Plaguelands
    1423: (53, 60),  # Eastern Plaguelands
    1424: (20, 30),  # Hillsbrad Foothills
    1425: (40, 50),  # The Hinterlands
    1426: (1, 10),  # Dun Morogh
    1427: (45, 50),  # Searing Gorge
    1428: (50, 58),  # Burning Steppes
    1429: (1, 10),  # Elwynn Forest
    1430: (55, 60),  # Deadwind Pass
    1431: (18, 30),  # Duskwood
    1432: (10, 20),  # Loch Modan
    1433: (15, 25),  # Redridge Mountains
    1434: (30, 45),  # Stranglethorn Vale
    1435: (35, 45),  # Swamp of Sorrows
    1436: (10, 20),  # Westfall
    1437: (20, 30),  # Wetlands
    # Kalimdor
    1411: (1, 10),  # Durotar
    1412: (1, 10),  # Mulgore
    1413: (10, 25),  # The Barrens
    1438: (1, 10),  # Teldrassil
    1439: (10, 20),  # Darkshore
    1440: (18, 30),  # Ashenvale
    1441: (25, 35),  # Thousand Needles
    1442: (15, 27),  # Stonetalon Mountains
    1443: (30, 40),  # Desolace
    1444: (40, 50),  # Feralas
    1445: (35, 45),  # Dustwallow Marsh
    1446: (40, 50),  # Tanaris
    1447: (45, 55),  # Azshara
    1448: (48, 55),  # Felwood
    1449: (48, 55),  # Un'Goro Crater
    1450: (55, 60),  # Moonglade
    1451: (55, 60),  # Silithus
    1452: (53, 60),  # Winterspring
}
# The original game's cities and battlegrounds, which have no range.
UNRANGED = {
    1453,  # Stormwind City
    1454,  # Orgrimmar
    1455,  # Ironforge
    1456,  # Thunder Bluff
    1457,  # Darnassus
    1458,  # Undercity
    1459,  # Alterac Valley
    1460,  # Warsong Gulch
    1461,  # Arathi Basin
}


def db2(name, refresh=False, offline=False):
    path = CACHE / f"{name}-{BUILD}.csv"
    if path.exists() and not refresh:
        data = path.read_bytes()
    else:
        if offline:
            raise ValueError(f"Missing cached source: {path}")
        url = f"https://wago.tools/db2/{name}/csv?build={BUILD}"
        request = urllib.request.Request(url, headers={"User-Agent": "TweaksForever/1.0"})
        with urllib.request.urlopen(request, timeout=300) as response:
            data = response.read()
    rows = list(csv.DictReader(io.StringIO(data.decode("utf-8-sig")), strict=True))
    if not rows or "ID" not in rows[0]:
        raise ValueError(f"{name}: empty export (or an HTML response)")
    CACHE.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return rows


def hover_zones(ui_maps):
    """The zones Blizzard's hover label names: zone children of the world map and of each continent on it."""
    parents = {AZEROTH} | {
        int(r["ID"]) for r in ui_maps if int(r["ParentUiMapID"]) == AZEROTH and int(r["Type"]) == CONTINENT
    }
    return sorted(
        (int(r["ID"]), r["Name_lang"]) for r in ui_maps if int(r["ParentUiMapID"]) in parents and int(r["Type"]) == ZONE
    )


def exploration_range(ui_map, assignments, areas, children):
    """Lowest and highest ExplorationLevel among the map's areas and all their subzones, or None."""
    stack = [a for m, a in assignments if m == ui_map]
    levels = []
    while stack:
        area = stack.pop()
        level = int(areas[area]["ExplorationLevel"]) if area in areas else 0
        if level > 0:
            levels.append(level)
        stack.extend(children.get(area, ()))
    return (min(levels), max(levels)) if levels else None


def generate(tables):
    areas = {int(r["ID"]): r for r in tables["AreaTable"]}
    children = {}
    for area in areas.values():
        children.setdefault(int(area["ParentAreaID"]), []).append(int(area["ID"]))
    assignments = {(int(r["UiMapID"]), int(r["AreaID"])) for r in tables["UiMapAssignment"] if r["AreaID"] != "0"}
    ranges, missing = [], []
    for ui_map, name in hover_zones(tables["UiMap"]):
        if ui_map in PUBLISHED:
            ranges.append((ui_map, name, PUBLISHED[ui_map], False))
        elif ui_map in UNRANGED:
            continue
        elif derived := exploration_range(ui_map, assignments, areas, children):
            ranges.append((ui_map, name, derived, True))
        else:
            missing.append(name)
    absent = set(PUBLISHED) - {ui_map for ui_map, *_ in ranges}
    if absent:
        raise ValueError(f"published zones no longer on a hover map: {sorted(absent)}")
    return ranges, missing


def render(ranges):
    lines = [
        "-- Generated by tools/gen_zonelevels.py — do not edit.",
        "-- Level ranges by UiMap ID. The original game's zones take its published range:",
        f"-- {SOURCE}",
        "-- Forever's own zones take the lowest and highest exploration level of their subzones",
        f"-- (AreaTable.ExplorationLevel, build {BUILD}). C_Map.GetMapLevels wins wherever it returns a range.",
        "local _, ns = ...",
        "ns.ZoneRanges = {",
    ]
    for ui_map, name, (low, high), derived in ranges:
        note = " (exploration levels)" if derived else ""
        lines.append(f"\t[{ui_map}] = {{ {low}, {high} }}, -- {name}{note}")
    return "\n".join(lines + ["}", ""])


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--refresh", action="store_true", help="Download the pinned CSVs again")
    group.add_argument("--offline", action="store_true", help="Require cached CSVs")
    args = parser.parse_args()
    tables = {name: db2(name, **vars(args)) for name in ("UiMap", "UiMapAssignment", "AreaTable")}
    ranges, missing = generate(tables)
    OUTPUT.write_text(render(ranges), encoding="utf-8")
    print(f"wrote {OUTPUT.relative_to(ROOT)}: {len(ranges)} zones")
    for name in missing:
        print(f"no range for {name}: none of its subzones has an exploration level")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, csv.Error, urllib.error.URLError) as error:
        sys.exit(f"gen_zonelevels: {error}")
