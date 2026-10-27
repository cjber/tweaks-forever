#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Generate the camp benefit texts for the pinned Forever client (stdlib only)."""

import argparse
import re
import sys
import urllib.error
from pathlib import Path

try:
    from tools.forever_tools import wago
    from tools.forever_tools.csvtable import parse_csv
except ModuleNotFoundError:
    from forever_tools import wago
    from forever_tools.csvtable import parse_csv

BUILD = "1.60.1.70630"
USER_AGENT = "TweaksForever/1.0"
ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".cache"
OUTPUT = ROOT / "Data" / "CampBenefits.lua"
CAMP_BENEFITS = 1229741  # its aura description lists every feature aura, one $?a branch each
TENT_AURA, TENT = 1229451, 1229487  # the rest lockout the tent grants, and the tent's own explanation
FEATURES = 9  # the summary's $?a branches: every camp feature but the tent
# The languages the Forever client ships besides English, in Locales/. itIT is absent because the client has none.
LOCALES = ("deDE", "esES", "esMX", "frFR", "koKR", "ptBR", "ruRU", "zhCN", "zhTW")
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
    rows = {}
    for row in wago.db2_rows(
        name, BUILD, CACHE, user_agent=USER_AGENT, refresh=refresh, offline=offline, timeout=600, ints=[key]
    ):
        rows.setdefault(row[key], []).append(row)
    return rows


def locale_db2(name, key, locale, refresh=False, offline=False):
    path = CACHE / f"{name}-{locale}-{BUILD}.csv"
    url = f"{wago.DB2_URL.format(name=name, build=BUILD)}&locale={locale}"
    data = wago.fetch(url, path, user_agent=USER_AGENT, refresh=refresh, offline=offline, timeout=600)
    return parse_csv(data.decode("utf-8-sig"), name, ints=[key])


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


class LocaleSpells:
    def __init__(self, locale, refresh, offline):
        self.spell = {row["ID"]: row for row in locale_db2("Spell", "ID", locale, refresh, offline)}
        self.strings = {
            row["BaseTag"]: row["TagText_lang"] for row in locale_db2("GlobalStrings", "ID", locale, refresh, offline)
        }

    def description(self, spell):
        return self.spell[spell]["AuraDescription_lang"]


def duration_text(seconds):
    # The client's own wording for $d in a description.
    if seconds < 60:
        return f"{seconds} sec"
    if seconds < 3600:
        return f"{seconds // 60} min"
    hours = seconds // 3600
    return f"{hours} hour" if hours == 1 else f"{hours} hours"


def localised_duration_text(seconds, strings):
    # The client language's own wording for $d, from its GlobalStrings at the same build.
    if seconds < 60:
        return strings["INT_SPELL_DURATION_SEC"] % seconds
    if seconds < 3600:
        return strings["INT_SPELL_DURATION_MIN"] % (seconds // 60)
    hours = seconds // 3600
    text = strings["INT_GENERAL_DURATION_HOURS"] % hours
    return re.sub(r"\|4([^:;]+):([^;]+);", lambda match: match[1] if hours == 1 else match[2], text)


def plural(text):
    # $l singular:plural; picks one form; camp values are above one, so the plural is right for them.
    return re.sub(r"\$l([^:;]+):([^;]+);", lambda match: match[2], text)


def resolve(spells, text, own, duration=duration_text):
    """Substitute $[spell]w<n>, $[spell]t<n> and $[spell]d; anything else left is a failure. Also returns the
    base value put in for each $w<n>, in effect order: the aura's live values replace them in game."""
    text = plural(text)
    bases = {}

    def value(match):
        spell, kind, index = int(match[1] or own), match[2], int(match[3] or 1) - 1
        if kind == "d":
            return duration(spells.seconds(spell))
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


def summary_branches(text):
    """The summary's $?a branches, tolerant of a missing opening bracket in one client language."""
    branches = []
    for match in re.finditer(r"\$\?a(\d+)", text):
        aura, start = int(match[1]), match.end()
        while start < len(text) and text[start] in "[]":
            start += 1
        end = text.find("][]", start)
        if end < 0:
            raise ValueError(f"spell {CAMP_BENEFITS}: branch {aura} has no end")
        branches.append((aura, text[start:end]))
    return branches


def split_feature(body):
    parts = re.split(r"[:：]", body.strip(), maxsplit=1)
    if len(parts) != 2:
        raise ValueError(f"spell {CAMP_BENEFITS}: no colon between a feature and its effect in {body!r}")
    return parts[0].strip(), parts[1].strip()


def benefits(spells):
    template = spells.description(CAMP_BENEFITS)
    branches = summary_branches(template)
    # Since 1.60.1.70425 the summary no longer has a Tent branch; the tent is still a camp feature, explained by
    # its own spell, and its rest lockout aura is unchanged. It comes first, where the summary used to list it.
    if any(int(aura) == TENT_AURA for aura, _ in branches):
        raise ValueError("Camp Benefits lists the tent again; take its row from the template")
    if len(branches) != FEATURES:
        raise ValueError(f"Camp Benefits lists {len(branches)} features, not {FEATURES}; the template changed")
    if "Camp Tent" not in spells.description(TENT_AURA):
        raise ValueError(f"spell {TENT_AURA} is no longer the Camp Tent's rest lockout")
    out = [(TENT_AURA, "Tent", resolve(spells, spells.description(TENT), TENT)[0], None, [])]
    for aura, body in branches:
        feature, effect = split_feature(body)
        text, bases = resolve(spells, effect, aura)
        out.append((aura, feature, text.rstrip("."), spells.seconds(aura), bases))
    return out


def localised_effects(spells, texts, auras):
    """Each feature's effect in one client language, from the same auras and numbers."""
    duration = lambda seconds: localised_duration_text(seconds, texts.strings)  # noqa: E731
    out = {TENT_AURA: one_line(resolve(spells, texts.description(TENT), TENT, duration)[0]).rstrip("。.")}
    branches = summary_branches(texts.description(CAMP_BENEFITS))
    if len(branches) != FEATURES:
        raise ValueError(f"Camp Benefits lists {len(branches)} features, not {FEATURES}; the template changed")
    for aura, body in branches:
        _, effect = split_feature(body)
        text, bases = resolve(spells, effect, aura, duration)
        if bases != next(row[4] for row in auras if row[0] == aura):
            raise ValueError(
                f"spell {aura}: its translated numbers are in another order; live values would not line up"
            )
        out[aura] = one_line(text).rstrip("。.")
    if set(out) != {row[0] for row in auras}:
        raise ValueError("Camp Benefits: its translated branches do not cover every aura")
    return out


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def one_line(text):
    # A tooltip line never spans rows, and Lua short strings cannot hold a raw newline.
    return re.sub(r"[ \t\r\n]+", " ", text).strip()


def wrap(text, indent, prefix=0):
    """A Lua string expression that fits the 120-column limit, split at spaces with `..` as stylua lays it out."""
    width = 120 - 4 * indent - 4 - prefix  # tabs count 4; room for the quotes, a comma and a leading `.. `
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


def render(rows, localised):
    lines = [
        "-- Generated by tools/gen_camp.py; do not edit.",
        f"-- Source: https://wago.tools/db2/Spell/csv?build={BUILD} (the Camp Benefits and Camp Tent",
        "-- auras' descriptions), with SpellEffect, SpellMisc and SpellDuration of the same build for the numbers,",
        "-- and GlobalStrings of the same build and locale for a translated duration's wording.",
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
    lines += [
        "}",
        "",
        "-- Each feature's effect in the client languages, keyed by locale and then aura. A missing locale or",
        "-- aura falls back to the English effect above.",
        "ns.CampBenefitEffects = {",
    ]
    for locale in LOCALES:
        lines.append(f"\t{locale} = {{")
        for row in rows:
            aura, effect = row[0], localised[locale][row[0]]
            prefix = f"\t\t[{aura}] = "
            lines.append(prefix + wrap(effect, 2, len(prefix.expandtabs(4))) + ",")
        lines.append("\t},")
    lines.append("}")
    return "\n".join(lines + [""])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--refresh", action="store_true", help="Download the pinned CSVs again")
    group.add_argument("--offline", action="store_true", help="Require cached CSVs")
    args = parser.parse_args()
    spells = Spells(args.refresh, args.offline)
    rows = benefits(spells)
    localised = {
        locale: localised_effects(spells, LocaleSpells(locale, args.refresh, args.offline), rows) for locale in LOCALES
    }
    OUTPUT.write_text(render(rows, localised), encoding="utf-8")
    print(f"wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, urllib.error.URLError) as error:
        sys.exit(f"gen_camp: {error}")
