"""The class trainer generator: dump parsing, Wowhead pages, the crawl, ranks, races and what it leaves out."""

import json
import unittest
import unittest.mock
from collections import Counter

from tools.gen_classspells import (
    CREATURE_COLUMNS,
    crawl,
    generate,
    listview,
    race_ids,
    teachings,
    trainer_class,
    trainer_levels,
    values,
)

SHAMAN, MAGE = 64, 128  # ChrClasses bits, as Wowhead's reqclass has them


def creature(entry, trainer_class, template=0, trainer_type=0):
    row = ["0"] * CREATURE_COLUMNS
    row[0], row[71], row[73], row[75] = str(entry), str(trainer_type), str(trainer_class), str(template)
    return row


def offer(entry, spell, cost, level, skill=0):
    return [str(entry), str(spell), str(cost), str(skill), "0", str(level), "NULL", "NULL", "NULL", "0"]


def ability(spell, line, class_mask=64, low=0, high=0, trivial=0):
    return {
        "Spell": str(spell),
        "SkillLine": str(line),
        "ClassMask": str(class_mask),
        "RaceMasks_0": str(low),
        "RaceMasks_1": str(high),
        "TradeSkillCategoryID": "0",
        "TrivialSkillLineRankHigh": str(trivial),
    }


def learn(teacher, taught):
    return {"SpellID": str(teacher), "Effect": "36", "DifficultyID": "0", "EffectTriggerSpell": str(taught)}


def page(**lists):
    """A Wowhead page with the given Listviews, written as Wowhead writes them."""
    views = [
        f"new Listview({{template: 'spell', id: '{name.replace('_', '-')}', data: {json.dumps(rows)}}});"
        for name, rows in lists.items()
    ]
    return "<script>" + "\n".join(views) + "</script>"


def row(spell, level, cost=None, reqclass=SHAMAN):
    found = {"id": spell, "level": level, "reqclass": reqclass}
    return found if cost is None else {**found, "trainingcost": cost}


RACES = [{"ID": str(race), "PlayableRaceBit": str(race - 1)} for race in range(1, 9)]


class ValuesTest(unittest.TestCase):
    def test_quotes_and_nulls(self):
        line = "INSERT INTO `t` VALUES (1,'O\\'Neil, (the) ''Elder''',NULL),(2,'',3);\n"
        self.assertEqual(values(line), [["1", "O'Neil, (the) 'Elder'", "NULL"], ["2", "", "3"]])


class RacesTest(unittest.TestCase):
    def test_masks(self):
        self.assertIsNone(race_ids([(0, 0)], RACES))
        self.assertIsNone(race_ids([(-1, -1)], RACES))
        self.assertIsNone(race_ids([(0b11110000, 0), (0b1111, 0)], RACES), "every playable race")
        self.assertEqual(race_ids([(0b100, 0)], RACES), [3])
        self.assertEqual(race_ids([(-1321907123, 1427461461)], RACES), [1, 3, 4, 7])


class Pages:
    def __init__(self, pages):
        self.pages, self.asked = pages, []

    def page(self, kind, entry):
        self.asked.append((kind, entry))
        return self.pages.get((kind, entry), "")


class WowheadTest(unittest.TestCase):
    def test_listview(self):
        html = page(teaches_ability=[row(1, 2, 3)], teaches_other=[row(4, 0)])
        self.assertEqual(listview(html, "teaches-ability"), [row(1, 2, 3)])
        self.assertEqual(listview(html, "teaches-recipe"), [])

    def test_trainer_class(self):
        self.assertEqual(trainer_class([row(1, 1), row(2, 1), row(3, 1, reqclass=77)]), 7)
        self.assertIsNone(trainer_class([row(1, 1), row(2, 1, reqclass=MAGE)]), "no clear majority")
        self.assertIsNone(trainer_class([]))

    def test_crawl(self):
        """A trainer only another trainer's spell names is found, and a non-class or profession one left out; so is
        one only a spell new to Forever names."""
        new = {**row(1240000, 40), "envChange": {"status": "new"}}
        pages = Pages(
            {
                ("npc", 10): page(teaches_ability=[row(8056, 20, 2200), row(403, 1, 10)]),
                ("npc", 11): page(teaches_ability=[row(8056, 20, 2200)]),
                ("spell", 8056): page(taught_by_npc=[{"id": 10}, {"id": 20}, {"id": 30}, {"id": 31}]),
                ("npc", 20): page(teaches_ability=[row(8056, 20, 2000), new], teaches_other=[row(674, 0, reqclass=77)]),
                ("npc", 30): page(teaches_ability=[row(9, 1, 1, reqclass=0)]),
                ("npc", 31): page(teaches_ability=[row(8056, 20, 2200)], teaches_recipe=[row(3908, 0, 10)]),
                ("spell", 1240000): page(taught_by_npc=[{"id": 20}, {"id": 40}]),
                ("npc", 40): page(teaches_ability=[new]),
            }
        )
        with unittest.mock.patch("tools.gen_classspells.PROBES", 1):
            found = crawl({10, 11}, pages, {3908})
        self.assertEqual(found["trainers"], {"SHAMAN": [10, 11, 20, 40]})
        self.assertNotIn(("spell", 403), pages.asked, "only the most widely taught spell is asked for")
        self.assertEqual(
            found["spells"]["SHAMAN"],
            {
                "403": [[1, 10, "teaches-ability", 1]],
                "674": [[0, None, "teaches-other", 1]],
                "8056": [[20, 2000, "teaches-ability", 1], [20, 2200, "teaches-ability", 2]],
                "1240000": [[40, None, "teaches-ability", 2]],
            },
        )
        self.assertEqual(pages.asked.count(("spell", 8056)), 1, "each spell is asked once")


class GenerateTest(unittest.TestCase):
    def test_levels(self):
        tables = {
            "creature_template": [creature(10, 7), creature(11, 7, template=5), creature(12, 7, trainer_type=2)],
            "npc_trainer": [offer(10, 1324, 100, 8), offer(10, 9999, 50, 30, skill=40), offer(12, 7777, 1, 1)],
            "npc_trainer_template": [offer(5, 8057, 2000, 20)],
        }
        taught = teachings([learn(8057, 8056), learn(1324, 529)], [learn(8057, 1)])
        self.assertEqual(taught[8057], {8056}, "Classic Era's teaching spell wins over Forever's")
        levels = trainer_levels(tables, taught)
        self.assertEqual(dict(levels), {("SHAMAN", 529): Counter({8: 1}), ("SHAMAN", 8056): Counter({20: 1})})

    def test_shaman(self):
        found = {
            "trainers": {"SHAMAN": [10, 20]},
            "spells": {
                "SHAMAN": {
                    "8056": [[20, 2000, "teaches-ability", 1], [20, 2200, "teaches-ability", 2]],
                    "529": [[8, 100, "teaches-ability", 3]],
                    "1240000": [[40, None, "teaches-ability", 3]],  # Forever's own, no fee given
                    "674": [[0, None, "teaches-other", 3]],  # Dual Wield: CMaNGOS has the level
                    "3127": [[1, None, "teaches-other", 3]],  # none there: left out
                    "2835": [[30, None, "teaches-recipe", 3]],  # a tradeskill recipe
                    "877": [[1, 5, "teaches-ability", 1]],  # on no skill line of the class
                    "2645": [[20, 5, "teaches-ability", 1]],  # not in the client
                    "2649": [[1, None, "teaches-ability", 3]],  # Growl: the pet's tab lists it
                }
            },
        }
        levels = {("SHAMAN", 674): Counter({20: 2})}
        forever = {
            "Spell": [{"ID": "403", "NameSubtext_lang": "Rank 1"}, {"ID": "529", "NameSubtext_lang": "Rank 2"}],
            "SpellName": [
                {"ID": str(spell), "Name_lang": name}
                for spell, name in [
                    (8056, "Frost Shock"),
                    (403, "Lightning Bolt"),
                    (529, "Lightning Bolt"),
                    (1240000, "Earth Shield"),
                    (674, "Dual Wield"),
                    (3127, "Parry"),
                    (2835, "Deadly Poison"),
                    (877, "Elemental Fury"),
                    (2649, "Growl"),
                ]
            ],
            "SkillLine": [
                {"ID": "375", "DisplayName_lang": "Elemental Combat", "CategoryID": "7"},
                {"ID": "374", "DisplayName_lang": "Restoration", "CategoryID": "7"},
                {"ID": "208", "DisplayName_lang": "Pet - Wolf", "CategoryID": "7"},
                {"ID": "118", "DisplayName_lang": "Dual Wield", "CategoryID": "6"},
            ],
            "SkillLineAbility": [
                ability(8056, 375, low=0b100),
                ability(403, 375),
                ability(529, 375),
                ability(1240000, 374),
                ability(674, 118, class_mask=13),
                ability(674, 118),
                ability(3127, 95),
                ability(2835, 40, trivial=225),
                ability(877, 375, class_mask=1),
                ability(2649, 208, class_mask=0),
            ],
            "ChrRaces": RACES,
        }
        result, stats = generate(found, levels, forever)
        self.assertEqual(
            result["SHAMAN"],
            (
                [374, 375],
                [
                    (529, 8, 100, 375, [403], None),
                    (674, 20, None, 118, None, None),
                    (8056, 20, 2200, 375, None, [3]),
                    (1240000, 40, None, 374, None, None),
                ],
            ),
        )
        self.assertEqual(stats["SHAMAN_general"], 1, "Dual Wield goes on the General tab")
        self.assertEqual(
            [
                stats[key]
                for key in ("SHAMAN", "not_in_client", "recipe", "no_skill_line", "pet", "no_level", "trainers")
            ],
            [4, 1, 1, 1, 1, 1, 2],
        )


if __name__ == "__main__":
    unittest.main()
