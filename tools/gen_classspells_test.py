"""The class trainer generator: dump parsing, teaching spells, ranks, races, pet families and what it leaves out."""

import unittest
from collections import Counter

from tools.gen_classspells import (
    CREATURE_COLUMNS,
    PET_TRAINING_COST,
    generate,
    generate_pets,
    race_ids,
    teachings,
    values,
)


def creature(entry, trainer_class, template=0, trainer_type=0, name="Trainer"):
    row = ["0"] * CREATURE_COLUMNS
    row[0], row[1], row[71], row[73], row[75] = (str(entry), name, str(trainer_type), str(trainer_class), str(template))
    return row


def offer(entry, spell, cost, level, skill=0):
    return [str(entry), str(spell), str(cost), str(skill), "0", str(level), "NULL", "NULL", "NULL", "0"]


def ability(spell, line, class_mask=64, low=0, high=0, cost=None):
    row = {
        "Spell": str(spell),
        "SkillLine": str(line),
        "ClassMask": str(class_mask),
        "RaceMasks_0": str(low),
        "RaceMasks_1": str(high),
    }
    if cost is not None:
        row[PET_TRAINING_COST] = str(cost)
    return row


def family(family_id, food, line, generic=270, name="Wolf"):
    return {
        "ID": str(family_id),
        "Name_lang": name,
        "PetFoodMask": str(food),
        "SkillLine_0": str(line),
        "SkillLine_1": str(generic),
    }


def skill(line_id, category=7, name="Pet - Wolf"):
    return {"ID": str(line_id), "DisplayName_lang": name, "CategoryID": str(category)}


def spell_level(spell, level, base=0, difficulty=0):
    return {"SpellID": str(spell), "DifficultyID": str(difficulty), "SpellLevel": str(level), "BaseLevel": str(base)}


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
            (
                [375],
                [(529, 8, 100, 375, [403], None), (8056, 20, 2200, 375, None, [3])],
                [10, 11],
            ),
        )
        self.assertEqual((stats["SHAMAN"], stats["not_in_client"], stats["skill_gated"]), (2, 1, 1))
        self.assertEqual(stats["trainers"], 2)


class PetFamiliesTest(unittest.TestCase):
    def build(self, families, abilities, levels, spells=None):
        """A Forever export with the pet tables, a family line (208), the generic line (270) and a non-pet line."""
        ranks = {
            100: "Rank 1",
            101: "Rank 2",
            200: "Rank 1",
            201: "Rank 1",
            300: "",
            400: "Rank 1",
            500: "Rank 1",
        }
        if spells is not None:
            ranks = spells
        return {
            "Spell": [{"ID": str(spell), "NameSubtext_lang": rank} for spell, rank in ranks.items()],
            "SpellName": [{"ID": str(spell), "Name_lang": f"Ability {spell}"} for spell in ranks if spell != 500],
            "SkillLine": [skill(208), skill(270, name="Pet - Generic"), skill(300, category=0, name="Other")],
            "SkillLineAbility": abilities,
            "SpellLevels": levels,
            "CreatureFamily": families,
        }

    def test_a_tameable_family_gets_its_own_and_generic_ranks(self):
        families = [family(1, 1, 208), family(2, 0, 209), family(3, 1, 300, generic=0)]
        abilities = [
            ability(100, 208, cost=5),
            ability(101, 208, cost=10),
            ability(200, 270, cost=0),
            ability(201, 270, cost=2),
            ability(300, 270),  # no rank
            ability(400, 208),  # no pet level
            ability(500, 208),  # not in the client's SpellName
        ]
        levels = [
            spell_level(100, 1),
            spell_level(101, 8),
            spell_level(200, 1),
            spell_level(201, 20),
            spell_level(300, 1),
            spell_level(400, 0),
            spell_level(500, 1),
        ]
        stats = Counter()
        result = generate_pets(self.build(families, abilities, levels), stats)
        self.assertEqual(
            result,
            {1: ([208, 270], [(100, 1, 5), (200, 1, 0), (101, 8, 10), (201, 20, 2)])},
            "the family line then the generic line, by pet level",
        )
        self.assertNotIn(2, result, "a family that eats nothing is not a hunter pet")
        self.assertNotIn(3, result, "a family line outside the pet category teaches nothing")
        self.assertEqual((stats["pet_families"], stats["pet_abilities"]), (1, 4))
        self.assertEqual((stats["pet_not_a_rank"], stats["pet_not_in_client"]), (2, 1))

    def test_a_cost_the_client_lacks_stays_nil_and_base_level_fills_in(self):
        abilities = [ability(100, 208)]
        levels = [spell_level(100, 0, base=30)]
        stats = Counter()
        result = generate_pets(self.build([family(1, 1, 208)], abilities, levels), stats)
        self.assertEqual(result[1][1], [(100, 30, None)], "no cost column, and SpellLevel 0 falls back to BaseLevel")


class TrainersTest(unittest.TestCase):
    def generate_trainers(self, trainers):
        tables = {
            "creature_template": trainers,
            "npc_trainer": [offer(entry, 8057, 100, 20) for entry in (100, 101)],
            "npc_trainer_template": [],
        }
        forever = {
            "Spell": [],
            "SpellName": [{"ID": "1", "Name_lang": "Frost Shock"}],
            "SkillLine": [{"ID": "375", "DisplayName_lang": "Elemental Combat", "CategoryID": "7"}],
            "SkillLineAbility": [ability(1, 375)],
            "ChrRaces": RACES,
        }
        taught = teachings([learn(8057, 1)], [])
        return generate(tables, taught, forever)

    def test_keeps_each_trainer_by_id_and_drops_unused_templates(self):
        result, stats = self.generate_trainers(
            [creature(101, 7, name="Murak"), creature(100, 7, name="Siln"), creature(102, 7, name="[UNUSED] Test")]
        )
        self.assertEqual(result["SHAMAN"][2], [100, 101])
        self.assertEqual((stats["unused"], stats["kept"]), (1, 2))


if __name__ == "__main__":
    unittest.main()
