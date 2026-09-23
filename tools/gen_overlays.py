#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Generate lazy map-art overlay data for the pinned Forever client (stdlib only)."""

import argparse
import csv
import io
import sys
import urllib.error
import urllib.request
from collections import defaultdict
from pathlib import Path

BUILD = "1.60.1.69977"
ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".cache"
OUTPUT = ROOT / "Data" / "Overlays.lua"
SCHEMAS = {
    "WorldMapOverlay": ("UiMapArtID", "OffsetX", "OffsetY", "TextureWidth", "TextureHeight", "PlayerConditionID"),
    "WorldMapOverlayTile": ("WorldMapOverlayID", "LayerIndex", "RowIndex", "ColIndex", "FileDataID"),
    "UiMapArt": ("UiMapArtStyleID",),
    "UiMapArtStyleLayer": ("UiMapArtStyleID", "LayerIndex", "TileWidth", "TileHeight"),
}


def write_atomic(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    try:
        temporary.write_bytes(data)
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def db2(name, refresh=False, offline=False):
    path = CACHE / f"{name}-{BUILD}.csv"
    if path.exists() and not refresh:
        data = path.read_bytes()
    else:
        if offline:
            raise ValueError(f"Missing cached source: {path}")
        url = f"https://wago.tools/db2/{name}/csv?build={BUILD}"
        request = urllib.request.Request(url, headers={"User-Agent": "TweaksForever/1.0"})
        with urllib.request.urlopen(request, timeout=60) as response:
            data = response.read()
    content = data.decode("utf-8-sig")
    reader = csv.DictReader(io.StringIO(content), strict=True)
    fields = reader.fieldnames or []
    columns = ("ID", *SCHEMAS[name])
    if not set(columns) <= set(fields) or len(fields) != len(set(fields)):
        raise ValueError(f"{name}: missing/duplicate CSV columns (or an HTML response)")
    rows = {}
    for line, row in enumerate(reader, 2):
        if None in row or None in row.values():
            raise ValueError(f"{name}:{line}: malformed CSV row")
        parsed = {key: int(row[key]) for key in columns}
        if parsed["ID"] <= 0 or parsed["ID"] in rows:
            raise ValueError(f"{name}:{line}: invalid/duplicate ID")
        rows[parsed["ID"]] = parsed
    if not rows:
        raise ValueError(f"{name}: empty DB2 export")
    write_atomic(path, data)
    return rows


def generate(tables):
    overlays, arts = tables["WorldMapOverlay"], tables["UiMapArt"]
    layers = {}
    for row in tables["UiMapArtStyleLayer"].values():
        key = row["UiMapArtStyleID"], row["LayerIndex"]
        if key in layers or min(row["TileWidth"], row["TileHeight"]) <= 0:
            raise ValueError(f"Invalid/duplicate art layer: {key}")
        layers[key] = row
    tiles = defaultdict(dict)
    for row in tables["WorldMapOverlayTile"].values():
        oid = row["WorldMapOverlayID"]
        if oid not in overlays:
            raise ValueError(f"Orphan tile: {row['ID']}")
        key = row["LayerIndex"], row["RowIndex"], row["ColIndex"]
        if key in tiles[oid] or min(key) < 0 or row["FileDataID"] <= 0:
            raise ValueError(f"Overlay {oid}: invalid/duplicate tile {key}")
        tiles[oid][key] = row["FileDataID"]

    packed, seen = defaultdict(list), set()
    missing, count = 0, 0
    for oid, row in sorted(overlays.items()):
        art = row["UiMapArtID"]
        if art not in arts:
            raise ValueError(f"Overlay {oid}: missing art {art}")
        if row["PlayerConditionID"]:
            raise ValueError(f"Overlay {oid}: player condition needs runtime support")
        source = tiles[oid]
        if not source:
            missing += 1
            continue
        rect = tuple(row[key] for key in ("OffsetX", "OffsetY", "TextureWidth", "TextureHeight"))
        x, y, width, height = rect
        if min(x, y) < 0 or min(width, height) <= 0:
            raise ValueError(f"Overlay {oid}: invalid rectangle")
        for index in sorted({key[0] for key in source}):
            layer = layers[arts[art]["UiMapArtStyleID"], index]
            wide = (width + layer["TileWidth"] - 1) // layer["TileWidth"]
            tall = (height + layer["TileHeight"] - 1) // layer["TileHeight"]
            expected = {(index, r, c) for r in range(tall) for c in range(wide)}
            actual = {key for key in source if key[0] == index}
            if expected != actual:
                raise ValueError(f"Overlay {oid}: incomplete/out-of-grid layer {index}")
            key = art, index, rect
            if key in seen:
                raise ValueError(f"Overlay {oid}: duplicate rectangle on art/layer {art}/{index}")
            seen.add(key)
            files = [source[index, r, c] for r in range(tall) for c in range(wide)]
            # One record per overlay/layer; indices match the canvas's one-based layers.
            packed[art].append(",".join(map(str, (index + 1, *rect, *files))) + ";")
            count += 1

    lines = [
        "-- Generated by tools/gen_overlays.py — do not edit.",
        f"-- Source: https://wago.tools/db2/WorldMapOverlay/csv?build={BUILD}",
        f"-- WorldMapOverlayTile, UiMapArt, UiMapArtStyleLayer: same source/build {BUILD}.",
        "-- Per art: layer,x,y,width,height,fileDataIDs (row-major); decoded only for the viewed map.",
        "local _, ns = ...",
        "ns.Overlays = {",
    ]
    for art, records in sorted(packed.items()):
        chunks, chunk = [], ""
        for record in records:
            for character in record:
                if len(chunk) == 100:
                    chunks.append(chunk)
                    chunk = ""
                chunk += character
        if chunk:
            chunks.append(chunk)
        lines.append(f"\t[{art}] = " + f'"{chunks[0]}"' + ("," if len(chunks) == 1 else ""))
        lines.extend(f'\t\t.. "{chunk}"' + ("," if i == len(chunks) - 1 else "") for i, chunk in enumerate(chunks[1:], 1))
    lines.extend(("}", ""))
    return "\n".join(lines).encode(), len(packed), count, missing


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--refresh", action="store_true", help="Download the pinned CSVs again")
    group.add_argument("--offline", action="store_true", help="Require cached CSVs")
    args = parser.parse_args()
    tables = {name: db2(name, **vars(args)) for name in SCHEMAS}
    data, arts, count, missing = generate(tables)
    write_atomic(OUTPUT, data)
    print(f"{OUTPUT}: {len(data):,} bytes, {arts} map arts, {count} overlays; {missing} tile-less rows omitted")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, csv.Error, urllib.error.URLError) as error:
        sys.exit(f"gen_overlays: {error}")
