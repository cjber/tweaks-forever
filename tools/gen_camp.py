#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Generate the camp benefit texts for the pinned Forever client (stdlib only)."""

import argparse
import csv
import io
import re
import urllib.request
from pathlib import Path

BUILD = "1.60.1.69977"
ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".cache"
OUTPUT = ROOT / "Data" / "CampBenefits.lua"
CAMP_BENEFITS = 1229741  # its aura description lists every feature aura, one $?a branch each
TENT_AURA, TENT = 1229451, 1229487  # the rest lockout the tent grants, and the tent's own explanation
# SpellEffect columns that make a value depend on level, stats or group size; all must be zero to ship a number.
SCALING = (
    "Coefficient",
    "ScalingClass",
    "EffectRealPointsPerLevel",
    "EffectBonusCoefficient",
    "BonusCoefficientFromAP",
    "Variance",
    "ResourceCoefficient",
)


def db2(name, key, refresh=False, offline=False):
    path = CACHE / f"{name}-{BUILD}.csv"
    if path.exists() and not refresh:
        data = path.read_bytes()
    else:
        if offline:
            raise ValueError(f"Missing cached source: {path}")
        url = f"https://wago.tools/db2/{name}/csv?build={BUILD}"
        request = urllib.request.Request(url, headers={"User-Agent": "TweaksForever/1.0"})
        with urllib.request.urlopen(request, timeout=600) as response:
            data = response.read()
    reader = csv.DictReader(io.StringIO(data.decode("utf-8-sig")), strict=True)
    if key not in (reader.fieldnames or []):
        raise ValueError(f"{name}: no {key} column (or an HTML response)")
    rows = {}
    for row in reader:
        rows.setdefault(int(row[key]), []).append(row)
    if not rows:
        raise ValueError(f"{name}: empty DB2 export")
    CACHE.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return rows


class Spells:
    def __init__(self, refresh, offline):
        load = lambda name, key: db2(name, key, refresh, offline)  # noqa: E731
        self.spell = load("Spell", "ID")
        self.effect = load("SpellEffect", "SpellID")
        self.misc = load("SpellMisc", "SpellID")
        self.duration = load("SpellDuration", "ID")

    def description(self, spell):
        return self.spell[spell][0]["AuraDescription_lang"]

    def effect_row(self, spell, index):
        rows = [r for r in self.effect.get(spell, []) if int(r["EffectIndex"]) == index and r["DifficultyID"] == "0"]
        if len(rows) != 1:
            raise ValueError(f"spell {spell}: no single effect {index}")
        row = rows[0]
        scaled = [c for c in SCALING if float(row[c]) != 0]
        if scaled:
            raise ValueError(f"spell {spell} effect {index} scales ({', '.join(scaled)}); resolve it at runtime")
        return row

    def seconds(self, spell):
        (misc,) = self.misc[spell]
        if misc["ContentTuningID"] != "0":
            raise ValueError(f"spell {spell} is content tuned; its values may scale")
        return int(self.duration[int(misc["DurationIndex"])][0]["Duration"]) // 1000


def number(value):
    value = float(value)
    return str(int(value)) if value.is_integer() else f"{value:g}"


def duration_text(seconds):
    # The client's own wording for $d in a description.
    if seconds < 60:
        return f"{seconds} sec"
    if seconds < 3600:
        return f"{seconds // 60} min"
    hours = seconds // 3600
    return f"{hours} hour" if hours == 1 else f"{hours} hours"


def resolve(spells, text, own):
    """Substitute $[spell]w<n>, $[spell]t<n> and $[spell]d; anything else left is a failure. Also returns the
    base value put in for each $w<n>, in effect order: the aura's live values replace them in game."""
    bases = {}

    def value(match):
        spell, kind, index = int(match[1] or own), match[2], int(match[3] or 1) - 1
        if kind == "d":
            return duration_text(spells.seconds(spell))
        row = spells.effect_row(spell, index)
        if kind == "t":
            return number(int(row["EffectAuraPeriod"]) / 1000)
        bases[index] = number(row["EffectBasePointsF"])
        return bases[index]

    resolved = re.sub(r"\$(\d+)?([wtd])(\d)?", value, text)
    if "$" in resolved:
        raise ValueError(f"unresolved token in {resolved!r}")
    if sorted(bases) != list(range(len(bases))):
        raise ValueError(f"{resolved!r} skips an effect; its live values would not line up")
    return resolved, [bases[i] for i in range(len(bases))]


def benefits(spells):
    template = spells.description(CAMP_BENEFITS)
    branches = re.findall(r"\$\?a(\d+)\[(.*?)\]\[\]", template, re.S)
    if len(branches) < 10:
        raise ValueError(f"Camp Benefits lists {len(branches)} features; the template changed")
    out = []
    for aura, body in branches:
        aura = int(aura)
        feature, effect = body.strip().split(": ", 1)
        if aura == TENT_AURA:
            # The benefit's own line only says rest was received; the tent says how to get it.
            out.append((aura, feature, resolve(spells, spells.description(TENT), TENT)[0], None, []))
        else:
            text, bases = resolve(spells, effect, aura)
            out.append((aura, feature, text.rstrip("."), spells.seconds(aura), bases))
    return out


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def wrap(text, indent):
    """A Lua string expression that fits the 120-column limit, split at spaces with `..` as stylua lays it out."""
    width = 120 - 4 * indent - 4  # tabs count 4; room for the quotes, a comma and a leading `.. `
    chunks, line = [], ""
    for word in re.findall(r"\S+\s*", text):
        if line and len(line) + len(word) > width:
            chunks.append(line)
            line = ""
        line += word
    chunks.append(line)
    return ("\n" + "\t" * (indent + 1) + ".. ").join(lua_string(chunk) for chunk in chunks)


def entry(fields):
    line = "\t{ " + ", ".join(fields) + " },"
    if len(line.expandtabs(4)) <= 120:
        return line
    return "\t{\n" + "".join(f"\t\t{field},\n" for field in fields) + "\t},"


def render(rows):
    lines = [
        "-- Generated by tools/gen_camp.py — do not edit.",
        f"-- Source: https://wago.tools/db2/Spell/csv?build={BUILD} (the Camp Benefits and Camp Tent",
        "-- auras' descriptions), with SpellEffect, SpellMisc and SpellDuration of the same build for the numbers.",
        "-- { aura, feature, effect, seconds it lasts (none for the tent's rest lockout), the effect's numbers in",
        "-- effect order }. The numbers are the spells' base values; the aura you get can carry others.",
        "local _, ns = ...",
        "ns.CampBenefits = {",
    ]
    for aura, feature, effect, seconds, bases in rows:
        fields = [str(aura), lua_string(feature), lua_string(effect)] + ([str(seconds)] if seconds else [])
        if bases:
            fields.append("{ " + ", ".join(bases) + " }")
        if len(fields[2]) > 120 - 12:
            fields[2] = wrap(effect, 2)
        lines.append(entry(fields))
    return "\n".join(lines + ["}", ""])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--refresh", action="store_true", help="download the exports again")
    parser.add_argument("--offline", action="store_true", help="require the cached exports")
    args = parser.parse_args()
    OUTPUT.write_text(render(benefits(Spells(args.refresh, args.offline))), encoding="utf-8")
    print(f"wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
