#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Generate dungeon and raid entrances for the pinned Forever client (stdlib only).

The world map already carries Blizzard's entrance provider, but it asks C_EncounterJournal, and Forever's
client ships no Journal* tables, so it has nothing to draw. The entrance itself is in Map: Corpse_0/1 on
CorpseMapID is where a ghost is sent to walk back in, which is the door. UiMapAssignment projects that point
onto a map, the same way Legacy Forever places its instance pins, so a pin lands where Legacy's does.

Which zone map owns an entrance is curated (ZONES): zone rectangles overlap, and a point inside several would
otherwise give Uldaman to Loch Modan. Continent maps take every entrance that projects onto them.

Entrances whose icons would overlap on the smallest world map merge into one pin at their centre, named by
the area in COMPLEXES where one is curated (Blackrock Mountain, the Gates of Ahn'Qiraj). A complex always
shows as one pin, even where its doors sit apart. Instances with no entrance in the client are listed.
"""

import argparse
import csv
import io
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path

BUILD = "1.60.1.69977"
ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".cache"
OUTPUT = ROOT / "Data" / "DungeonEntrances.lua"
AZEROTH = 947
CONTINENT = 2  # Enum.UIMapType
DUNGEON, RAID = "1", "2"  # Map.InstanceType
# The world map's canvas when minimized, in UI units, and the solid part of a 32-unit Dungeon or Raid icon.
MINIMIZED = (697, 465)
ICON = 20
# The zone maps that show each instance's entrance, by instance (Map) ID.
ZONES = {
    33: [1421],  # Shadowfang Keep: Silverpine Forest
    34: [1453],  # Stormwind Stockade: Stormwind City
    36: [1436],  # Deadmines: Westfall
    43: [1413],  # Wailing Caverns: The Barrens
    47: [1413],  # Razorfen Kraul: The Barrens
    48: [1440],  # Blackfathom Deeps: Ashenvale
    70: [1418],  # Uldaman: Badlands
    90: [1426],  # Gnomeregan: Dun Morogh
    109: [1435],  # Sunken Temple: Swamp of Sorrows
    129: [1413],  # Razorfen Downs: The Barrens
    189: [1420],  # Scarlet Monastery: Tirisfal Glades
    209: [1446],  # Zul'Farrak: Tanaris
    229: [1427, 1428],  # Blackrock Spire: Searing Gorge, Burning Steppes
    230: [1427, 1428],  # Blackrock Depths
    249: [1445],  # Onyxia's Lair: Dustwallow Marsh
    289: [1422],  # Scholomance: Western Plaguelands
    309: [1434],  # Zul'Gurub: Stranglethorn Vale
    329: [1423],  # Stratholme: Eastern Plaguelands
    349: [1443],  # Maraudon: Desolace
    389: [1454],  # Ragefire Chasm: Orgrimmar
    409: [1427, 1428],  # Molten Core
    429: [1444],  # Dire Maul: Feralas
    469: [1428],  # Blackwing Lair: Burning Steppes
    509: [1451],  # Ruins of Ahn'Qiraj: Silithus
    531: [1451],  # Ahn'Qiraj Temple: Silithus
}
# Instances sharing one way in, and the AreaTable ID that names it.
COMPLEXES = {
    frozenset({229, 230, 409, 469}): 25,  # Blackrock Mountain
    frozenset({509, 531}): 3478,  # Gates of Ahn'Qiraj
}
# Instances with a corpse point that is not an entrance.
SKIP = {44}  # <unused> Monastery, a copy of Scarlet Monastery's


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


def project(assignment, x, y):
    """A world point as a map position, or None off the map. Rounded as Legacy Forever rounds its pins."""
    r0, r1, r3, r4 = (float(assignment[f"Region_{i}"]) for i in (0, 1, 3, 4))
    if not (r0 <= x <= r3 and r1 <= y <= r4):
        return None
    u0, u1, v0, v1 = (float(assignment[k]) for k in ("UiMin_0", "UiMax_0", "UiMin_1", "UiMax_1"))
    px = u0 + (r4 - y) / (r4 - r1) * (u1 - u0)
    py = v0 + (r3 - x) / (r3 - r0) * (v1 - v0)
    if not (0 <= px <= 1 and 0 <= py <= 1):
        return None
    return round(px, 3), round(py, 3)


def footprints(tables):
    """Per map, the icon's size as a fraction of the map, at the minimized map's smallest zoom."""
    art = {int(r["UiMapID"]): int(r["UiMapArtID"]) for r in tables["UiMapXMapArt"] if r["PhaseID"] == "0"}
    style = {int(r["ID"]): int(r["UiMapArtStyleID"]) for r in tables["UiMapArt"]}
    layers = {int(r["UiMapArtStyleID"]): r for r in tables["UiMapArtStyleLayer"] if r["LayerIndex"] == "0"}
    sizes = {}
    for ui_map, art_id in art.items():
        layer = layers[style[art_id]]
        width, height = int(layer["LayerWidth"]), int(layer["LayerHeight"])
        scale = min(MINIMIZED[0] / width, MINIMIZED[1] / height)
        sizes[ui_map] = (ICON / (width * scale), ICON / (height * scale))
    return sizes


@dataclass
class Pin:
    members: list[tuple[int, float, float]]  # (instance, x, y)
    area: int | None = None
    x: float = field(init=False)
    y: float = field(init=False)

    def __post_init__(self):
        self.centre()

    def centre(self):
        self.x = round(sum(m[1] for m in self.members) / len(self.members), 3)
        self.y = round(sum(m[2] for m in self.members) / len(self.members), 3)

    def overlaps(self, other, footprint):
        return abs(self.x - other.x) < footprint[0] and abs(self.y - other.y) < footprint[1]


def cluster(points, footprint):
    """Merge a map's entrances into pins: every complex into one, then any whose icons overlap."""
    pins = []
    for members, area in COMPLEXES.items():
        inside = [p for p in points if p[0] in members]
        if len(inside) > 1:
            pins.append(Pin(inside, area))
            points = [p for p in points if p[0] not in members]
    pins += [Pin([p]) for p in points]
    while pair := next(((a, b) for i, a in enumerate(pins) for b in pins[i + 1 :] if a.overlaps(b, footprint)), None):
        a, b = pair
        a.members += b.members
        a.area = a.area or b.area
        a.centre()
        pins.remove(b)
    return sorted(pins, key=lambda pin: (pin.y, pin.x))


def generate(tables):
    ui_maps = {int(r["ID"]): r for r in tables["UiMap"]}
    continents = {i for i, r in ui_maps.items() if int(r["ParentUiMapID"]) == AZEROTH and int(r["Type"]) == CONTINENT}
    assignments = {}
    for row in tables["UiMapAssignment"]:
        assignments.setdefault((int(row["UiMapID"]), int(row["MapID"])), []).append(row)
    instances = {int(r["ID"]): r for r in tables["Map"] if r["InstanceType"] in (DUNGEON, RAID)}
    placed, unplaced = {}, []
    for instance, row in sorted(instances.items()):
        corpse_map, x, y = int(row["CorpseMapID"]), float(row["Corpse_0"]), float(row["Corpse_1"])
        name = row["MapName_lang"]
        if instance in SKIP:
            continue
        if corpse_map < 0 or (x, y) == (0, 0):
            unplaced.append(name)
            continue
        if instance not in ZONES:
            raise ValueError(f"{name} ({instance}) has an entrance but no curated zone map")
        for ui_map in (*ZONES[instance], *sorted(continents)):
            at = next(
                (p for a in assignments.get((ui_map, corpse_map), ()) if (p := project(a, x, y))),
                None,
            )
            if at:
                placed.setdefault(ui_map, []).append((instance, *at))
            elif ui_map not in continents:
                raise ValueError(f"{name} ({instance}): entrance is off {ui_map}")
    sizes = footprints(tables)
    pins = {ui_map: cluster(points, sizes[ui_map]) for ui_map, points in sorted(placed.items())}
    raids = sorted(i for i in ZONES if instances[i]["InstanceType"] == RAID)
    return pins, raids, {i: r["MapName_lang"] for i, r in instances.items()}, ui_maps, unplaced


def render(pins, raids, names, ui_maps, areas):
    lines = [
        "-- Generated by tools/gen_dungeons.py — do not edit.",
        f"-- Dungeon and raid entrances by UiMap ID, from Map.Corpse (build {BUILD}). A pin lists its instances",
        "-- (Map IDs); one with an area is a complex of several, named by that AreaTable ID.",
        "local _, ns = ...",
        "ns.DungeonEntrances = {",
    ]
    for ui_map, map_pins in pins.items():
        lines.append(f"\t[{ui_map}] = {{ -- {ui_maps[ui_map]['Name_lang']}")
        for pin in map_pins:
            ids = [m[0] for m in pin.members]
            area = f", area = {pin.area}" if pin.area else ""
            label = areas[pin.area] if pin.area else ", ".join(names[i] for i in ids)
            members = ", ".join(map(str, ids))
            lines.append(f"\t\t{{ x = {pin.x}, y = {pin.y}, instances = {{ {members} }}{area} }}, -- {label}")
        lines.append("\t},")
    lines += ["}", "ns.RaidInstances = {"]
    lines += [f"\t[{i}] = true, -- {names[i]}" for i in raids]
    return "\n".join(lines + ["}", ""])


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--refresh", action="store_true", help="Download the pinned CSVs again")
    group.add_argument("--offline", action="store_true", help="Require cached CSVs")
    args = parser.parse_args()
    names = ("Map", "AreaTable", "UiMap", "UiMapAssignment", "UiMapXMapArt", "UiMapArt", "UiMapArtStyleLayer")
    tables = {name: db2(name, **vars(args)) for name in names}
    pins, raids, instance_names, ui_maps, unplaced = generate(tables)
    areas = {int(r["ID"]): r["AreaName_lang"] for r in tables["AreaTable"]}
    OUTPUT.write_text(render(pins, raids, instance_names, ui_maps, areas), encoding="utf-8")
    count = sum(len(map_pins) for map_pins in pins.values())
    print(f"wrote {OUTPUT.relative_to(ROOT)}: {len(ZONES)} instances, {count} pins on {len(pins)} maps")
    for name in unplaced:
        print(f"no entrance for {name}: the client has no corpse point for it")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, csv.Error, urllib.error.URLError) as error:
        sys.exit(f"gen_dungeons: {error}")
