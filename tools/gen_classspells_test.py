"""The class trainer generator: dump parsing, teaching spells, ranks, races and what it leaves out."""

import unittest

from tools.gen_classspells import CREATURE_COLUMNS, generate, race_ids, teachings, values


def creature(entry, trainer_class, template=0, trainer_type=0):
    row = ["0"] * CREATURE_COLUMNS
    row[0], row[71], row[73], row[75] = str(entry), str(trainer_type), str(trainer_class), str(template)
    return row


def offer(entry, spell, cost, level, skill=0):
    return [str(entry), str(spell), str(cost), str(skill), "0", str(level), "NULL", "NULL", "NULL", "0"]


def ability(spell, line, class_mask=64, low=0, high=0):
    return {
        "Spell": str(spell),
        "SkillLine": str(line),
        "ClassMask": str(class_mask),
        "RaceMasks_0": str(low),
        "RaceMasks_1": str(high),
    }


def learn(teacher, taught):
    return {"SpellID": str(teacher), "Effect": "36", "DifficultyID": "0", "EffectTriggerSpell": str(taught)}


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


class GenerateTest(unittest.TestCase):
    def test_shaman(self):
        tables = {
            "creature_template": [creature(10, 7), creature(11, 7, template=5), creature(12, 7, trainer_type=2)],
            "npc_trainer": [
                offer(10, 8057, 2200, 20),  # teaches Frost Shock
                offer(10, 1324, 100, 8),  # teaches Lightning Bolt rank 2
                offer(10, 9999, 50, 30, skill=40),  # skill-gated
                offer(12, 7777, 1, 1),  # a profession trainer
            ],
            "npc_trainer_template": [offer(5, 8057, 2000, 20), offer(5, 8057, 2200, 20), offer(5, 20608, 7000, 30)],
        }
        taught = teachings([learn(8057, 8056), learn(1324, 529)], [learn(8057, 1), learn(20609, 20608)])
        self.assertEqual(taught[8057], {8056}, "Classic Era's teaching spell wins over Forever's")
        forever = {
            "Spell": [{"ID": "403", "NameSubtext_lang": "Rank 1"}, {"ID": "529", "NameSubtext_lang": "Rank 2"}],
            "SpellName": [
                {"ID": "8056", "Name_lang": "Frost Shock"},
                {"ID": "403", "Name_lang": "Lightning Bolt"},
                {"ID": "529", "Name_lang": "Lightning Bolt"},
            ],
            "SkillLine": [
                {"ID": "375", "DisplayName_lang": "Elemental Combat", "CategoryID": "7"},
                {"ID": "208", "DisplayName_lang": "Pet - Wolf", "CategoryID": "7"},
            ],
            "SkillLineAbility": [ability(8056, 375, low=0b100), ability(403, 375), ability(529, 375)],
            "ChrRaces": RACES,
        }
        result, stats = generate(tables, taught, forever)
        self.assertEqual(
            result["SHAMAN"],
            ([375], [(529, 8, 100, 375, [403], None), (8056, 20, 2200, 375, None, [3])]),
        )
        self.assertEqual((stats["SHAMAN"], stats["not_in_client"], stats["skill_gated"]), (2, 1, 1))
        self.assertEqual(stats["trainers"], 2)


if __name__ == "__main__":
    unittest.main()
