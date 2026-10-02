#!/usr/bin/env python3
"""Generate what each class trainer teaches, for the pinned Forever client (stdlib only).

Forever's spellbook lists only the spells you know, and its client holds no trainer lists: those live on the
server. CMaNGOS classic-db, pinned below, has the original game's class trainers (creature_template
TrainerType 0 with a TrainerClass) and what each teaches (npc_trainer, plus npc_trainer_template through
TrainerTemplateId), with the level and fee. A row there names the trainer's teaching spell, which the Classic
Era client resolves to the spell you learn (SpellEffect LEARN_SPELL); Forever's client drops most teaching
spells, so its own SpellEffect only fills in the rest. Forever's SkillLineAbility then puts each learned spell
on its class skill line (the spellbook tab), kept by SkillLine ID as the tab's name is in the client's locale,
and names the races it is for. Where the rank before a spell (by its "Rank N" subtext) is one no trainer
teaches, such as a talent, a quest reward or a starting spell, the row names it: that rank has to be known first.

A learned spell Forever's client doesn't know, or that sits on no class skill line, is left out and counted;
so are rows gated on a skill rank (rogue poisons). A trainer visit in game records the server's own list,
which wins over this one.
"""

import argparse
import csv
import gzip
import io
import re
import sys
import urllib.error
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

BUILD = "1.60.1.70170"
# Forever's client leaves out the trainers' teaching spells; Classic Era keeps them, with the same IDs.
TEACH_BUILD = "1.15.9.69722"
CLASSICDB_COMMIT = "22b51464f1625f6ef6275771de1f5466c6f5d19e"
CLASSICDB_URL = (
    f"https://raw.githubusercontent.com/cmangos/classic-db/{CLASSICDB_COMMIT}/Full_DB/ClassicDB_1_12_1_z2815.sql.gz"
)
ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".cache"
CLASSICDB_CACHE = CACHE / f"classicdb-{CLASSICDB_COMMIT[:7]}.sql.gz"
OUTPUT = ROOT / "Data" / "ClassSpells.lua"
# ChrClasses ID -> the class token UnitClass returns.
CLASSES = {
    1: "WARRIOR",
    2: "PALADIN",
    3: "HUNTER",
    4: "ROGUE",
    5: "PRIEST",
    7: "SHAMAN",
    8: "MAGE",
    9: "WARLOCK",
    11: "DRUID",
}
LEARN_SPELL = 36
RANK = re.compile(r"Rank (\d+)")
CLASS_CATEGORY = 7  # SkillLine.CategoryID of class skill lines (spellbook tabs), pet families included
ZONE = 3  # Enum.UIMapType zone, the maps a trainer's point projects onto
# creature_template, creature, npc_trainer and npc_trainer_template columns read, by position.
ENTRY, NAME, TRAINER_TYPE, TRAINER_CLASS, TRAINER_TEMPLATE = 0, 1, 71, 73, 75
SPELL, COST, REQ_SKILL, LEVEL = 1, 2, 3, 5
# creature: guid, then the template entry a spawn places, its map and point.
SPAWN_ENTRY, SPAWN_MAP, SPAWN_X, SPAWN_Y = 1, 2, 4, 5
CREATURE_COLUMNS = 87
TRAINER_UNUSED = re.compile(r"\[UNUSED\]|\*Temp\*|^World .* Trainer$")


def db2(name, build, refresh=False, offline=False):
    path = CACHE / f"{name}-{build}.csv"
    if path.exists() and not refresh:
        data = path.read_bytes()
    else:
        if offline:
            raise ValueError(f"Missing cached source: {path}")
        url = f"https://wago.tools/db2/{name}/csv?build={build}"
        request = urllib.request.Request(url, headers={"User-Agent": "TweaksForever/1.0"})
        with urllib.request.urlopen(request, timeout=600) as response:
            data = response.read()
    rows = list(csv.DictReader(io.StringIO(data.decode("utf-8-sig")), strict=True))
    if not rows or "ID" not in rows[0]:
        raise ValueError(f"{name} {build}: empty export (or an HTML response)")
    CACHE.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return rows


def classicdb(refresh=False, offline=False):
    """The dump's INSERT lines for the trainer tables and creature spawns, by table."""
    if not CLASSICDB_CACHE.exists() or refresh:
        if offline:
            raise ValueError(f"Missing cached source: {CLASSICDB_CACHE}")
        request = urllib.request.Request(CLASSICDB_URL, headers={"User-Agent": "TweaksForever/1.0"})
        with urllib.request.urlopen(request, timeout=300) as response:
            data = response.read()
        CACHE.mkdir(parents=True, exist_ok=True)
        temporary = CLASSICDB_CACHE.with_suffix(".tmp")
        temporary.write_bytes(data)
        temporary.replace(CLASSICDB_CACHE)
    tables = {"creature_template": [], "creature": [], "npc_trainer": [], "npc_trainer_template": []}
    with gzip.open(CLASSICDB_CACHE, "rt", encoding="utf-8", errors="replace") as dump:
        for line in dump:
            for table, rows in tables.items():
                if line.startswith(f"INSERT INTO `{table}` VALUES "):
                    rows.extend(values(line))
    if not all(tables.values()):
        raise ValueError(f"{CLASSICDB_CACHE.name}: a trainer table is missing")
    return tables


def ui_maps(rows):
    """The version's map rectangles for projecting a world point onto a zone map: zone ID -> UiMapAssignment
    rows, matched by the world Map ID a spawn names, as gen_dungeons.py does."""
    zones = {int(r["ID"]) for r in rows["UiMap"] if int(r["Type"]) == ZONE}
    found: defaultdict[int, list[dict[str, str]]] = defaultdict(list)
    for row in rows["UiMapAssignment"]:
        if int(row["UiMapID"]) in zones:
            found[int(float(row["MapID"]))].append(row)
    return found


def project(assignment, x, y):
    """A world point as a zone map position, or None off the map. Rounded as gen_dungeons.py rounds its pins."""
    r0, r1, r3, r4 = (float(assignment[f"Region_{i}"]) for i in (0, 1, 3, 4))
    if not (r0 <= x <= r3 and r1 <= y <= r4):
        return None
    u0, u1, v0, v1 = (float(assignment[k]) for k in ("UiMin_0", "UiMax_0", "UiMin_1", "UiMax_1"))
    px = u0 + (r4 - y) / (r4 - r1) * (u1 - u0)
    py = v0 + (r3 - x) / (r3 - r0) * (v1 - v0)
    if not (0 <= px <= 1 and 0 <= py <= 1):
        return None
    return round(px, 3), round(py, 3)


def place(maps, map_id, x, y):
    """The smallest zone map a world point is on, as {map, x, y}, or None where none shows it."""
    found = []
    for assignment in maps.get(int(map_id), ()):
        at = project(assignment, x, y)
        if at is None:
            continue
        region = float(assignment["Region_3"]) - float(assignment["Region_0"])
        region *= float(assignment["Region_4"]) - float(assignment["Region_1"])
        found.append((region, int(assignment["UiMapID"]), at[0], at[1]))
    if not found:
        return None
    _, ui_map, px, py = min(found)
    return {"map": ui_map, "x": px, "y": py}


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def trainers(trainer_class, class_id, spawns, maps):
    """A class's trainer NPCs, by entry, each with one representative spawn where the dump has one; the unused
    templates are dropped, and counted."""
    found, unused = [], 0
    for entry, (klass, name) in sorted(trainer_class.items()):
        if klass != class_id:
            continue
        if name and TRAINER_UNUSED.search(name):
            unused += 1
            continue
        row = {"npc": entry, "name": name}
        for map_id, x, y in sorted(set(spawns.get(entry, ()))):
            spot = place(maps, map_id, x, y)
            if spot:
                row.update(spot)
                break
        found.append(row)
    return found, unused


def values(line):
    """The rows of one extended INSERT, as lists of strings (quoted strings unescaped, NULL kept as text)."""
    rows, row, field, i = [], [], [], line.index(" VALUES ") + len(" VALUES ")
    quoted = depth = 0
    while i < len(line):
        char = line[i]
        if quoted:
            if char == "\\":
                field.append(line[i + 1])
                i += 1
            elif char == "'" and line[i + 1 : i + 2] == "'":
                field.append("'")
                i += 1
            elif char == "'":
                quoted = 0
            else:
                field.append(char)
        elif char == "'":
            quoted = 1
        elif char == "(" and not depth:
            depth, row, field = 1, [], []
        elif char in ",)" and depth:
            row.append("".join(field))
            field = []
            if char == ")":
                rows.append(row)
                depth = 0
        elif depth:
            field.append(char)
        i += 1
    return rows


def teachings(*effect_tables):
    """Teaching spell -> the spells it teaches, from the first table that has an entry for it."""
    taught = {}
    for rows in effect_tables:
        found = defaultdict(set)
        for row in rows:
            if int(row["Effect"]) == LEARN_SPELL and int(row["DifficultyID"]) == 0:
                found[int(row["SpellID"])].add(int(row["EffectTriggerSpell"]))
        for spell, learned in found.items():
            taught.setdefault(spell, learned)
    return taught


def race_ids(masks, races):
    """The playable races a SkillLineAbility row allows, or None for all of them. The mask is 64 bits over
    ChrRaces.PlayableRaceBit, exported as two signed halves."""
    bits = {int(r["ID"]): int(r["PlayableRaceBit"]) for r in races if int(r["PlayableRaceBit"]) >= 0}
    allowed = set()
    for low, high in masks:
        mask = (low & 0xFFFFFFFF) | ((high & 0xFFFFFFFF) << 32)
        if mask in (0, 0xFFFFFFFFFFFFFFFF):
            return None
        allowed |= {race for race, bit in bits.items() if mask >> bit & 1}
    return None if allowed >= set(bits) else sorted(allowed)


def offers(tables):
    """(class, trainer spell) -> Counter of (level, fee) over every class trainer teaching it, plus the class
    trainers themselves by entry."""
    trainer_rows = {}
    for row in tables["creature_template"]:
        if len(row) != CREATURE_COLUMNS:
            raise ValueError(f"creature_template: {len(row)} columns, expected {CREATURE_COLUMNS}")
        if row[TRAINER_TYPE] == "0" and int(row[TRAINER_CLASS]) in CLASSES:
            trainer_rows[int(row[ENTRY])] = (int(row[TRAINER_CLASS]), int(row[TRAINER_TEMPLATE]), row[NAME])
    lists = defaultdict(list)
    for row in tables["npc_trainer"]:
        lists[("npc", int(row[0]))].append(row)
    for row in tables["npc_trainer_template"]:
        lists[("template", int(row[0]))].append(row)
    seen: defaultdict[tuple[int, int], Counter[tuple[int, int]]] = defaultdict(Counter)
    skill_gated = set()
    for entry, (klass, template, _name) in trainer_rows.items():
        for row in lists[("npc", entry)] + lists[("template", template)]:
            if row[REQ_SKILL] != "0":
                skill_gated.add((klass, int(row[SPELL])))
            elif int(row[LEVEL]) > 0:
                seen[(klass, int(row[SPELL]))][(int(row[LEVEL]), int(row[COST]))] += 1
    trainer_class = {entry: (klass, name) for entry, (klass, _template, name) in trainer_rows.items()}
    return seen, trainer_class, len(skill_gated)


def ranks(abilities, names, subtexts, bit):
    """(skill line, name, rank) -> this class's spells of that rank, from the client's "Rank N" subtext."""
    found = defaultdict(set)
    for spell, rows in abilities.items():
        rank = RANK.fullmatch(subtexts.get(spell, ""))
        for row in rows:
            if rank and spell in names and for_class(row, bit):
                found[(int(row["SkillLine"]), names[spell], int(rank[1]))].add(spell)
    return found


def for_class(row, bit):
    return int(row["ClassMask"]) in (0, -1) or int(row["ClassMask"]) & bit


def generate(tables, taught, forever, maps):
    """Per class token: its skill line IDs and rows of (spell, level, fee, skill line ID, needs, races), plus its
    trainer NPCs by entry."""
    names = {int(r["ID"]): r["Name_lang"] for r in forever["SpellName"]}
    subtexts = {int(r["ID"]): r["NameSubtext_lang"] for r in forever["Spell"]}
    # Lines are baked by ID: their names are the client's locale, so an English name matches no other client's tab.
    lines = {
        int(r["ID"])
        for r in forever["SkillLine"]
        if int(r["CategoryID"]) == CLASS_CATEGORY and not r["DisplayName_lang"].startswith("Pet - ")
    }
    abilities = defaultdict(list)
    for row in forever["SkillLineAbility"]:
        if int(row["SkillLine"]) in lines:
            abilities[int(row["Spell"])].append(row)
    seen, trainer_class, skill_gated = offers(tables)
    spawns: defaultdict[int, list[tuple[int, float, float]]] = defaultdict(list)
    for row in tables["creature"]:
        spawns[int(row[SPAWN_ENTRY])].append((int(row[SPAWN_MAP]), float(row[SPAWN_X]), float(row[SPAWN_Y])))
    learned = defaultdict(Counter)
    for (klass, spell), counts in seen.items():
        for spell_id in taught.get(spell, {spell}):
            learned[(klass, spell_id)].update(counts)
    stats = Counter(trainers=len(trainer_class), skill_gated=skill_gated)
    result = {}
    for klass, token in CLASSES.items():
        bit = 1 << (klass - 1)
        by_rank = ranks(abilities, names, subtexts, bit)
        trained = {spell for k, spell in learned if k == klass}
        rows = []
        for spell in sorted(trained):
            if spell not in names:
                stats["not_in_client"] += 1
                continue
            own = [r for r in abilities[spell] if for_class(r, bit)]
            if not own:
                stats["no_class_line"] += 1
                continue
            line_ids = sorted({int(r["SkillLine"]) for r in own})
            if len(line_ids) > 1:
                raise ValueError(f"{token} {spell}: on several class lines {line_ids}")
            # Duplicate trainers almost always agree; take the most common (level, fee), cheaper on a tie.
            level, cost = min(learned[(klass, spell)].items(), key=lambda kv: (-kv[1], kv[0]))[0]
            # The rank before one no trainer teaches (a talent, a quest reward, a starting spell) has to be known
            # first: any of them, as a few names carry a second, rune-given rank of the same number.
            rank = RANK.fullmatch(subtexts.get(spell, ""))
            before = by_rank[(line_ids[0], names[spell], int(rank[1]) - 1)] if rank else set()
            needs = None if before & trained else sorted(before) or None
            races = race_ids([(int(r["RaceMasks_0"]), int(r["RaceMasks_1"])) for r in own], forever["ChrRaces"])
            rows.append((spell, level, cost, line_ids[0], needs, races))
        used = sorted({line for _, _, _, line, _, _ in rows})
        class_trainers, unused = trainers(trainer_class, klass, spawns, maps)
        stats["unused"] += unused
        stats["placed"] += sum(1 for row in class_trainers if "map" in row)
        stats["unplaced"] += sum(1 for row in class_trainers if "map" not in row)
        result[token] = (used, sorted(rows, key=lambda row: row[:2]), class_trainers)
        stats[token] = len(rows)
    return result, stats


def render(result, stats):
    lines = [
        "-- Generated by tools/gen_classspells.py — do not edit.",
        f"-- Source: CMaNGOS classic-db {CLASSICDB_COMMIT} class trainers (GPL-3.0); teaching spells",
        f"-- resolved through wago.tools SpellEffect {TEACH_BUILD}; skill lines, ranks and races from Forever {BUILD}.",
        f"-- Left out: {stats['not_in_client']} spells Forever's client lacks, {stats['no_class_line']} on no class"
        f" skill line, {stats['skill_gated']} gated on a skill rank.",
        f"-- {stats['unused']} unused trainer templates are left out; of {stats['placed'] + stats['unplaced']}"
        f" trainers, {stats['placed']} have a spawn on a zone map and {stats['unplaced']} none.",
        "-- A trainer visit in game records the server's own list, which wins over this one.",
        "---@type string, TFNamespace",
        "local _, ns = ...",
        "-- [class] = { lines = SkillLine IDs, spells = { { spell, level, fee in copper, SkillLine ID, needs =",
        "-- earlier rank no trainer teaches, races = the ChrRaces IDs it is for } },",
        "-- trainers = { { npc, name, map, x, y } }; a trainer without a spawn on a zone map keeps its NPC id and",
        "-- name and no place.",
        "-- stylua: ignore",
        "ns.ClassSpells = {",
    ]
    for token, (line_ids, rows, class_trainers) in sorted(result.items()):
        lines += [
            f"\t{token} = {{",
            f"\t\tlines = {{ {', '.join(map(str, line_ids))} }},",
            "\t\tspells = {",
        ]
        for spell, level, cost, line, needs, races in rows:
            extra = (f", needs = {{ {', '.join(map(str, needs))} }}" if needs else "") + (
                f", races = {{ {', '.join(map(str, races))} }}" if races else ""
            )
            lines.append(f"\t\t\t{{ {spell}, {level}, {cost}, {line}{extra} }},")
        lines += ["\t\t},", "\t\ttrainers = {"]
        for row in class_trainers:
            spot = f", {row['map']}, {row['x']}, {row['y']}" if "map" in row else ""
            lines.append(f"\t\t\t{{ {row['npc']}, {lua_string(row['name'])}{spot} }},")
        lines += ["\t\t},", "\t},"]
    return "\n".join(lines + ["}", ""])


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--refresh", action="store_true", help="download the pinned sources again")
    mode.add_argument("--offline", action="store_true", help="require the cached sources")
    mode.add_argument("--check", action="store_true", help="fail if the generated file is out of date")
    args = parser.parse_args()
    options = {"refresh": args.refresh, "offline": args.offline}
    forever = {
        name: db2(name, BUILD, **options)
        for name in ("Spell", "SpellName", "SkillLine", "SkillLineAbility", "ChrRaces")
    }
    taught = teachings(db2("SpellEffect", TEACH_BUILD, **options), db2("SpellEffect", BUILD, **options))
    maps = ui_maps({name: db2(name, BUILD, **options) for name in ("UiMap", "UiMapAssignment")})
    result, stats = generate(classicdb(**options), taught, forever, maps)
    text = render(result, stats)
    if args.check:
        if OUTPUT.read_text(encoding="utf-8") != text:
            sys.exit(f"gen_classspells: {OUTPUT.relative_to(ROOT)} is out of date")
        print(f"{OUTPUT.relative_to(ROOT)} is up to date")
        return
    OUTPUT.write_text(text, encoding="utf-8")
    counts = ", ".join(f"{token} {stats[token]}" for token in sorted(CLASSES.values()))
    print(f"wrote {OUTPUT.relative_to(ROOT)} from {stats['trainers']} trainers: {counts}")
    print(f"left out {stats['not_in_client']} not in the client, {stats['no_class_line']} on no class line")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, csv.Error, urllib.error.URLError) as error:
        sys.exit(f"gen_classspells: {error}")
