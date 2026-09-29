"""The class trainer generator: dump parsing, teaching spells, ranks, races and what it leaves out."""

import unittest

from tools.gen_classspells import CREATURE_COLUMNS, generate, place, race_ids, teachings, ui_maps, values


def creature(entry, trainer_class, template=0, trainer_type=0, name="Trainer"):
    row = ["0"] * CREATURE_COLUMNS
    row[0], row[1], row[71], row[73], row[75] = (str(entry), name, str(trainer_type), str(trainer_class), str(template))
    return row


def spawn(entry, map_id, x, y):
    return ["0", str(entry), str(map_id), "1", str(x), str(y), "0", "0", "300", "300", "0", "0"]


def zone_map(ui_map, map_id, x0, y0, x1, y1, ui_min=0.0, ui_max=1.0):
    return {
        "UiMapID": str(ui_map),
        "MapID": str(map_id),
        "Region_0": str(x0),
        "Region_1": str(y0),
        "Region_3": str(x1),
        "Region_4": str(y1),
        "UiMin_0": str(ui_min),
        "UiMax_0": str(ui_max),
        "UiMin_1": "0.0",
        "UiMax_1": "1.0",
    }


MAPS = ui_maps(
    {
        "UiMap": [{"ID": "1", "Type": "3"}, {"ID": "2", "Type": "3"}, {"ID": "947", "Type": "1"}],
        "UiMapAssignment": [zone_map(1, 0, 0, 0, 100, 100), zone_map(2, 0, 0, 0, 50, 50)],
    }
)


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
            "creature": [spawn(10, 0, 10, 10)],
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
        result, stats = generate(tables, taught, forever, MAPS)
        self.assertEqual(
            result["SHAMAN"],
            (
                [375],
                [(529, 8, 100, 375, [403], None), (8056, 20, 2200, 375, None, [3])],
                [{"npc": 10, "name": "Trainer", "map": 2, "x": 0.8, "y": 0.8}, {"npc": 11, "name": "Trainer"}],
            ),
        )
        self.assertEqual((stats["SHAMAN"], stats["not_in_client"], stats["skill_gated"]), (2, 1, 1))
        self.assertEqual(stats["trainers"], 2)


class ProjectTest(unittest.TestCase):
    def test_map_position_rounds_off_the_edge(self):
        assignment = zone_map(1, 0, 0, 0, 100, 100)
        self.assertEqual(place({0: [assignment]}, 0, 25, 75), {"map": 1, "x": 0.25, "y": 0.75})
        self.assertIsNone(place({0: [assignment]}, 0, 200, 0), "off the map")

    def test_smallest_zone_wins(self):
        self.assertEqual(place(MAPS, 0, 20, 20), {"map": 2, "x": 0.6, "y": 0.6}, "the city over the zone")
        self.assertEqual(place(MAPS, 0, 80, 80), {"map": 1, "x": 0.2, "y": 0.2}, "the zone alone")


class TrainersTest(unittest.TestCase):
    def generate_trainers(self, trainers, creature_rows):
        tables = {
            "creature_template": trainers,
            "creature": creature_rows,
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
        return generate(tables, taught, forever, MAPS)

    def test_places_one_spawn_and_keeps_an_unplaced_trainer(self):
        result, stats = self.generate_trainers(
            [creature(100, 7, name="Siln"), creature(101, 7, name="Murak"), creature(102, 7, name="[UNUSED] Test")],
            [spawn(100, 0, 10, 10), spawn(102, 0, 10, 10)],
        )
        self.assertEqual(
            result["SHAMAN"][2],
            [{"npc": 100, "name": "Siln", "map": 2, "x": 0.8, "y": 0.8}, {"npc": 101, "name": "Murak"}],
        )
        self.assertEqual((stats["unused"], stats["placed"], stats["unplaced"]), (1, 1, 1))


if __name__ == "__main__":
    unittest.main()
