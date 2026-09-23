#!/usr/bin/env python3
"""Generate what each class trainer teaches, for the pinned Forever client (stdlib only).

Forever's spellbook lists only the spells you know, and its client holds no trainer lists: those live on the
server. Wowhead's Forever database has them, as each class trainer's Teaches lists, with Forever's own spells,
levels and fees. The crawl starts from the original game's class trainers in CMaNGOS classic-db, pinned below
(creature_template TrainerType 0 with a TrainerClass), and adds every trainer Wowhead names as teaching a probe
spell: each class's most widely taught spells and every spell new to Forever, until no new trainer turns up. Each
class's lists are then merged, taking the most common (level, fee). A trainer's class is the one its own spells are
for. The crawl is saved to tools/wowhead_trainers.json, so a run reads it rather than Wowhead unless --crawl asks
for a new one.

Wowhead gives no trainer level for the rows it files under Teaches (other), such as Dual Wield: those take the
level of the CMaNGOS trainer row that teaches them (its teaching spell resolved to the spell you learn through the
Classic Era client's SpellEffect), and are left out without one. A fee Wowhead doesn't give is left out, never
guessed. Forever's SkillLineAbility then puts each spell on its class skill line (a spellbook tab), kept by
SkillLine ID as the tab's name is in the client's locale, or on the General tab when its line is another (Dual
Wield, Defense, armour, Lockpicking), and names the races it is for. Where the rank before a spell (by its "Rank
N" subtext) is one no trainer teaches, such as a talent, a quest reward or a starting spell, the row names it:
that rank has to be known first.

A learned spell Forever's client doesn't know, on no skill line of its class, or that is a tradeskill recipe
(rogue poisons, which open in their own window, not the spellbook) is left out and counted. A trainer visit in
game records the server's own list, which wins over this one.
"""

import argparse
import csv
import datetime
import gzip
import io
import json
import re
import sys
import time
import urllib.error
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

BUILD = "1.60.1.69977"
# Forever's client leaves out the trainers' teaching spells; Classic Era keeps them, with the same IDs.
TEACH_BUILD = "1.15.9.69722"
CLASSICDB_COMMIT = "22b51464f1625f6ef6275771de1f5466c6f5d19e"
CLASSICDB_URL = (
    f"https://raw.githubusercontent.com/cmangos/classic-db/{CLASSICDB_COMMIT}/Full_DB/ClassicDB_1_12_1_z2815.sql.gz"
)
WOWHEAD_URL = "https://www.wowhead.com/forever"
# Wowhead serves its pages to a browser; the crawl waits this long between requests, as it blocks a faster one.
WOWHEAD_AGENT = "Mozilla/5.0 (X11; Linux x86_64) TweaksForever/1.0"
WOWHEAD_DELAY = 3.0
PROBES = 3
WOWHEAD_TRIES = 4  # a server error is tried again, waiting twice as long each time
ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".cache"
CLASSICDB_CACHE = CACHE / f"classicdb-{CLASSICDB_COMMIT[:7]}.sql.gz"
PAGES = CACHE / "wowhead"
CRAWL = ROOT / "tools" / "wowhead_trainers.json"
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
PROFESSION_CATEGORY = 11  # SkillLine.CategoryID of the professions
# Wowhead's lists on a trainer's page; "other" rows carry the spell's own level, not the trainer's.
TEACHES = ("teaches-ability", "teaches-recipe", "teaches-other")
OTHER = "teaches-other"
# creature_template, npc_trainer and npc_trainer_template columns read, by position.
ENTRY, TRAINER_TYPE, TRAINER_CLASS, TRAINER_TEMPLATE = 0, 71, 73, 75
SPELL, COST, REQ_SKILL, LEVEL = 1, 2, 3, 5
CREATURE_COLUMNS = 87


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
    """The dump's INSERT lines for the three trainer tables, by table."""
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
    tables = {"creature_template": [], "npc_trainer": [], "npc_trainer_template": []}
    with gzip.open(CLASSICDB_CACHE, "rt", encoding="utf-8", errors="replace") as dump:
        for line in dump:
            for table, rows in tables.items():
                if line.startswith(f"INSERT INTO `{table}` VALUES "):
                    rows.extend(values(line))
    if not all(tables.values()):
        raise ValueError(f"{CLASSICDB_CACHE.name}: a trainer table is missing")
    return tables


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


class Wowhead:
    """Wowhead Forever pages, cached raw in tools/.cache/wowhead and fetched at most once a WOWHEAD_DELAY."""

    def __init__(self, refresh=False, offline=False):
        self.refresh, self.offline, self.last = refresh, offline, 0.0

    def page(self, kind, entry):
        path = PAGES / f"{kind}-{entry}.html"
        if path.exists() and not self.refresh:
            return path.read_text(encoding="utf-8")
        if self.offline:
            raise ValueError(f"Missing cached source: {path}")
        request = urllib.request.Request(f"{WOWHEAD_URL}/{kind}={entry}", headers={"User-Agent": WOWHEAD_AGENT})
        text = ""
        for attempt in range(WOWHEAD_TRIES):
            time.sleep(max(0.0, self.last + WOWHEAD_DELAY * 2**attempt - time.monotonic()))
            try:
                with urllib.request.urlopen(request, timeout=60) as response:
                    text = response.read().decode("utf-8")
                break
            except urllib.error.HTTPError as error:
                if error.code == 404:
                    break  # not in Forever: remembered as an empty page
                if error.code < 500 or attempt == WOWHEAD_TRIES - 1:
                    raise
            finally:
                self.last = time.monotonic()
        PAGES.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return text


def listview(html, name):
    """The data rows of one of a Wowhead page's Listviews, or none."""
    start = html.find(f"id: '{name}'")
    if start < 0:
        return []
    data = html.index("data: ", start) + len("data: ")
    rows = json.JSONDecoder().raw_decode(html, data)[0]
    if not isinstance(rows, list):
        raise ValueError(f"Wowhead listview {name}: not a list")
    return rows


def trainer_class(rows):
    """The class a trainer teaches: the one most of its spells are for, when it is a clear majority."""
    bits = {1 << (klass - 1): klass for klass in CLASSES}
    counts = Counter(bits[row["reqclass"]] for row in rows if row.get("reqclass") in bits)
    if not counts:
        return None
    klass, count = counts.most_common(1)[0]
    return klass if count * 2 > len(rows) else None


def probes(trainers):
    """The spells whose trainers are worth asking for: each class's PROBES most widely taught ones, which any trainer
    of that class's levels teaches too, and every spell new to Forever, which a trainer new to Forever may be alone
    in teaching. Asking for every spell would take thousands of pages, more than Wowhead serves one visitor."""
    taught: defaultdict[int, Counter[tuple[int, int]]] = defaultdict(Counter)
    for klass, rows in trainers.values():
        for row in rows["teaches-ability"]:
            taught[klass][(row.get("level") or 0, row["id"])] += 1
    found = set()
    for counts in taught.values():
        found |= {spell for (_, spell), _ in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))[:PROBES]}
    for _, lists in trainers.values():
        found |= {
            row["id"] for rows in lists.values() for row in rows if row.get("envChange", {}).get("status") == "new"
        }
    return found


def offer_order(item):
    """Offers by level, then fee (an unknown one first), then list: None and a fee don't compare."""
    (level, fee, listed), _ = item
    return level, fee is not None, fee or 0, listed


def professions(forever):
    """The spells on a profession's skill line (Tailoring, Blacksmithing): a trainer teaching one teaches that
    profession, whatever class spells Wowhead also files under it."""
    lines = {int(r["ID"]) for r in forever["SkillLine"] if int(r["CategoryID"]) == PROFESSION_CATEGORY}
    return {int(r["Spell"]) for r in forever["SkillLineAbility"] if int(r["SkillLine"]) in lines}


def crawl(seeds, wowhead, profession_spells):
    """Every class trainer reachable from the seed NPCs, by the trainers Wowhead lists for the probe spells they
    teach, until no new one turns up; a profession trainer is none:
    {"trainers": {class: [npc]}, "spells": {class: {spell: [[level, fee or None, list], trainer count]...}}}."""
    trainers, seen, asked = {}, set(seeds), set()
    queue = sorted(seeds)
    while queue:
        for npc in queue:
            html = wowhead.page("npc", npc)
            rows = {name: listview(html, name) for name in TEACHES}
            klass = trainer_class(rows["teaches-ability"])
            if klass and not any(row["id"] in profession_spells for rows in rows.values() for row in rows):
                trainers[npc] = (klass, rows)
        queue = []
        for spell in sorted(probes(trainers) - asked):
            asked.add(spell)
            for npc in listview(wowhead.page("spell", spell), "taught-by-npc"):
                if npc["id"] not in seen:
                    seen.add(npc["id"])
                    queue.append(npc["id"])
    by_class: defaultdict[str, list[int]] = defaultdict(list)
    offered: defaultdict[str, defaultdict[int, Counter[tuple[int, int | None, str]]]] = defaultdict(
        lambda: defaultdict(Counter)
    )
    for npc, (klass, lists) in sorted(trainers.items()):
        token, bit = CLASSES[klass], 1 << (klass - 1)
        by_class[token].append(npc)
        for name, rows in lists.items():
            for row in rows:
                if not row.get("reqclass") or row["reqclass"] & bit:
                    offer = (row.get("level") or 0, row.get("trainingcost"), name)
                    offered[token][row["id"]][offer] += 1
    return {
        "trainers": {token: npcs for token, npcs in sorted(by_class.items())},
        "spells": {
            token: {
                str(spell): [[*offer, n] for offer, n in sorted(offers.items(), key=offer_order)]
                for spell, offers in spells.items()
            }
            for token, spells in sorted(offered.items())
        },
    }


def fetched():
    """The UTC date span of the cached Wowhead pages."""
    dates = sorted(
        datetime.datetime.fromtimestamp(path.stat().st_mtime, datetime.UTC).date().isoformat()
        for path in PAGES.glob("*.html")
    )
    if not dates:
        raise ValueError(f"No Wowhead pages in {PAGES}")
    return dates[0] if dates[0] == dates[-1] else f"{dates[0]} to {dates[-1]}"


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


def class_trainers(tables):
    """CMaNGOS's class trainers: NPC entry -> (class, trainer template)."""
    trainers = {}
    for row in tables["creature_template"]:
        if len(row) != CREATURE_COLUMNS:
            raise ValueError(f"creature_template: {len(row)} columns, expected {CREATURE_COLUMNS}")
        if row[TRAINER_TYPE] == "0" and int(row[TRAINER_CLASS]) in CLASSES:
            trainers[int(row[ENTRY])] = (int(row[TRAINER_CLASS]), int(row[TRAINER_TEMPLATE]))
    return trainers


def trainer_levels(tables, taught):
    """(class token, learned spell) -> Counter of the levels CMaNGOS's class trainers teach it at."""
    lists = defaultdict(list)
    for row in tables["npc_trainer"]:
        lists[("npc", int(row[0]))].append(row)
    for row in tables["npc_trainer_template"]:
        lists[("template", int(row[0]))].append(row)
    levels: defaultdict[tuple[str, int], Counter[int]] = defaultdict(Counter)
    for entry, (klass, template) in class_trainers(tables).items():
        for row in lists[("npc", entry)] + lists[("template", template)]:
            if row[REQ_SKILL] == "0" and int(row[LEVEL]) > 0:
                for spell in taught.get(int(row[SPELL]), {int(row[SPELL])}):
                    levels[(CLASSES[klass], spell)][int(row[LEVEL])] += 1
    return levels


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


def recipe(row):
    """A tradeskill recipe (rogue poisons): learned into its own window, never the spellbook."""
    return int(row["TradeSkillCategoryID"]) != 0 or int(row["TrivialSkillLineRankHigh"]) != 0


def offer(offers, token, spell, levels):
    """The most common (level, fee) over a class's trainers, cheaper on a tie. A row Wowhead files under Teaches
    (other) has no trainer level, so it takes CMaNGOS's; None when neither has one."""
    counts = Counter()
    for level, fee, listed, n in offers:
        if listed == OTHER:
            known = levels.get((token, spell))
            level = known.most_common(1)[0][0] if known else 0
        if level > 0:
            counts[(level, fee)] += n
    if not counts:
        return None
    return min(counts.items(), key=lambda kv: (-kv[1], kv[0][0], kv[0][1] is None, kv[0][1] or 0))[0]


def generate(found, levels, forever):
    """Per class token: its class skill line IDs and rows of (spell, level, fee or None, skill line ID, needs,
    races); a row on another line than the class's goes on the General tab."""
    names = {int(r["ID"]): r["Name_lang"] for r in forever["SpellName"]}
    subtexts = {int(r["ID"]): r["NameSubtext_lang"] for r in forever["Spell"]}
    # Lines are baked by ID: their names are the client's locale, so an English name matches no other client's tab.
    class_lines, pet_lines = set(), set()
    for r in forever["SkillLine"]:
        if int(r["CategoryID"]) == CLASS_CATEGORY:
            (pet_lines if r["DisplayName_lang"].startswith("Pet - ") else class_lines).add(int(r["ID"]))
    abilities = defaultdict(list)
    for row in forever["SkillLineAbility"]:
        abilities[int(row["Spell"])].append(row)
    stats = Counter(trainers=sum(map(len, found["trainers"].values())))
    result = {}
    for klass, token in CLASSES.items():
        bit = 1 << (klass - 1)
        stats[f"{token}_trainers"] = len(found["trainers"].get(token, []))
        by_rank = ranks(abilities, names, subtexts, bit)
        offered = {int(spell): offers for spell, offers in found["spells"].get(token, {}).items()}
        trained = set(offered)
        rows = []
        for spell in sorted(offered):
            if spell not in names:
                stats["not_in_client"] += 1
                continue
            own = [r for r in abilities[spell] if for_class(r, bit)]
            if any(recipe(r) for r in own):
                stats["recipe"] += 1
                continue
            # A spell on a class line goes on that tab; one on another line (Dual Wield, Defense) on General.
            on_class = [r for r in own if int(r["SkillLine"]) in class_lines]
            own = on_class or [r for r in own if int(r["SkillLine"]) not in pet_lines]
            if not own and any(int(r["SkillLine"]) in pet_lines for r in abilities[spell]):
                stats["pet"] += 1  # the pet's own spell (Growl), which the pet's tab lists
                continue
            if not own:
                stats["no_skill_line"] += 1
                continue
            line_ids = sorted({int(r["SkillLine"]) for r in own})
            if len(line_ids) > 1:
                raise ValueError(f"{token} {spell}: on several skill lines {line_ids}")
            chosen = offer(offered[spell], token, spell, levels)
            if not chosen:
                stats["no_level"] += 1
                continue
            level, cost = chosen
            # The rank before one no trainer teaches (a talent, a quest reward, a starting spell) has to be known
            # first: any of them, as a few names carry a second, rune-given rank of the same number.
            rank = RANK.fullmatch(subtexts.get(spell, ""))
            before = by_rank[(line_ids[0], names[spell], int(rank[1]) - 1)] if rank else set()
            needs = None if before & trained else sorted(before) or None
            races = race_ids([(int(r["RaceMasks_0"]), int(r["RaceMasks_1"])) for r in own], forever["ChrRaces"])
            rows.append((spell, level, cost, line_ids[0], needs, races))
        used = sorted({line for _, _, _, line, _, _ in rows if line in class_lines})
        result[token] = (used, sorted(rows, key=lambda row: row[:2]))
        stats[token] = len(rows)
        stats[f"{token}_general"] = sum(line not in class_lines for _, _, _, line, _, _ in rows)
    return result, stats


def render(result, stats, date):
    lines = [
        "-- Generated by tools/gen_classspells.py — do not edit.",
        f"-- Source: Wowhead Forever's class trainer lists ({stats['trainers']} trainers, fetched {date}); levels"
        " of Teaches (other) rows",
        f"-- from CMaNGOS classic-db {CLASSICDB_COMMIT} (GPL-3.0)",
        f"-- through wago.tools SpellEffect {TEACH_BUILD};",
        f"-- skill lines, ranks and races from Forever {BUILD}.",
        f"-- Left out: {stats['not_in_client']} spells Forever's client lacks, {stats['no_skill_line']} on no skill"
        f" line of the class, {stats['pet']} pet spells, {stats['recipe']} tradeskill recipes,",
        f"-- {stats['no_level']} with no trainer level.",
        "-- A trainer visit in game records the server's own list, which wins over this one.",
        "---@type string, TFNamespace",
        "local _, ns = ...",
        "-- [class] = { lines = class SkillLine IDs (spellbook tabs), spells = { { spell, level, fee in copper or nil",
        "-- when unknown, SkillLine ID (not a class line: the General tab), needs = earlier rank no trainer teaches,",
        "-- races = the ChrRaces IDs it is for } } }",
        "-- stylua: ignore",
        "ns.ClassSpells = {",
    ]
    for token, (line_ids, rows) in sorted(result.items()):
        lines += [f"\t{token} = {{", f"\t\tlines = {{ {', '.join(map(str, line_ids))} }},", "\t\tspells = {"]
        for spell, level, cost, line, needs, races in rows:
            extra = (f", needs = {{ {', '.join(map(str, needs))} }}" if needs else "") + (
                f", races = {{ {', '.join(map(str, races))} }}" if races else ""
            )
            fee = "nil" if cost is None else cost
            lines.append(f"\t\t\t{{ {spell}, {level}, {fee}, {line}{extra} }},")
        lines += ["\t\t},", "\t},"]
    return "\n".join(lines + ["}", ""])


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--crawl", action="store_true", help=f"crawl Wowhead again into {CRAWL.name}")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--refresh", action="store_true", help="download the pinned sources (and pages) again")
    mode.add_argument("--offline", action="store_true", help="require the cached sources (and pages)")
    args = parser.parse_args()
    options = {"refresh": args.refresh, "offline": args.offline}
    tables = classicdb(**options)
    forever = {
        name: db2(name, BUILD, **options)
        for name in ("Spell", "SpellName", "SkillLine", "SkillLineAbility", "ChrRaces")
    }
    if args.crawl:
        found = crawl(set(class_trainers(tables)), Wowhead(**options), professions(forever))
        found = {"fetched": fetched(), **found}
        CRAWL.write_text(json.dumps(found, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    found = json.loads(CRAWL.read_text(encoding="utf-8"))
    taught = teachings(db2("SpellEffect", TEACH_BUILD, **options), db2("SpellEffect", BUILD, **options))
    result, stats = generate(found, trainer_levels(tables, taught), forever)
    OUTPUT.write_text(render(result, stats, found["fetched"]), encoding="utf-8")
    counts = ", ".join(f"{token} {stats[token]} ({stats[f'{token}_general']} General)" for token in CLASSES.values())
    print(f"wrote {OUTPUT.relative_to(ROOT)} from {stats['trainers']} trainers: {counts}")
    print(
        f"left out {stats['not_in_client']} not in the client, {stats['no_skill_line']} on no skill line,"
        f" {stats['pet']} pet spells, {stats['recipe']} recipes, {stats['no_level']} with no level"
    )


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, csv.Error, urllib.error.URLError, json.JSONDecodeError) as error:
        sys.exit(f"gen_classspells: {error}")
