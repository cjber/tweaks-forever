"""API destinations keep their own first zone projection when map pins merge."""

import unittest
from unittest.mock import patch

from tools.gen_dungeons import ZONES, generate, render


def instance(instance_id, x, y, corpse_map=0):
    return {
        "ID": str(instance_id),
        "InstanceType": "1",
        "MapName_lang": f"Instance {instance_id}",
        "CorpseMapID": str(corpse_map),
        "Corpse_0": str(x),
        "Corpse_1": str(y),
    }


def tables(instances):
    maps = [(1415, 1000), (1427, 200), (1428, 100)]
    return {
        "Map": instances,
        "UiMap": [
            {
                "ID": str(ui_map),
                "Name_lang": f"Map {ui_map}",
                "ParentUiMapID": "947" if ui_map == 1415 else "1415",
                "Type": "2" if ui_map == 1415 else "3",
            }
            for ui_map, _ in maps
        ],
        "UiMapAssignment": [
            {
                "UiMapID": str(ui_map),
                "MapID": "0",
                "Region_0": "0",
                "Region_1": "0",
                "Region_3": str(size),
                "Region_4": str(size),
                "UiMin_0": "0",
                "UiMax_0": "1",
                "UiMin_1": "0",
                "UiMax_1": "1",
            }
            for ui_map, size in maps
        ],
        "UiMapXMapArt": [{"UiMapID": str(ui_map), "UiMapArtID": "1", "PhaseID": "0"} for ui_map, _ in maps],
        "UiMapArt": [{"ID": "1", "UiMapArtStyleID": "1"}],
        "UiMapArtStyleLayer": [{"UiMapArtStyleID": "1", "LayerIndex": "0", "LayerWidth": "697", "LayerHeight": "465"}],
    }


class GenerateTest(unittest.TestCase):
    def test_complex_keeps_first_curated_zone_and_individual_destinations(self):
        source = tables([instance(229, 20, 30), instance(230, 60, 70)])
        # Curated order wins over numeric map order, including the continent.
        with patch.dict(ZONES, {229: [1428, 1427], 230: [1428, 1427]}, clear=True):
            entrances, pins, raids, names, ui_maps, unplaced = generate(source)
        self.assertEqual(entrances, {229: (1428, 0.7, 0.8), 230: (1428, 0.3, 0.4)})
        self.assertEqual(len(pins[1428]), 1)
        pin = pins[1428][0]
        self.assertEqual((pin.x, pin.y, pin.area), (0.5, 0.6, 25))
        self.assertEqual(unplaced, [])
        lua = render(entrances, pins, raids, names, ui_maps, {25: "Blackrock Mountain"})
        self.assertIn("ns.InstanceEntrances = {", lua)
        self.assertIn("[229] = { map = 1428, x = 0.7, y = 0.8 }", lua)
        self.assertIn("[230] = { map = 1428, x = 0.3, y = 0.4 }", lua)
        self.assertIn("x = 0.5, y = 0.6, instances = { 229, 230 }, area = 25", lua)

    def test_overlapping_pins_keep_individual_destinations(self):
        source = tables([instance(47, 20, 30), instance(129, 21, 31)])
        with patch.dict(ZONES, {47: [1428], 129: [1428]}, clear=True):
            entrances, pins, *_ = generate(source)
        self.assertEqual(entrances, {47: (1428, 0.7, 0.8), 129: (1428, 0.69, 0.79)})
        self.assertEqual(len(pins[1428]), 1)
        pin = pins[1428][0]
        self.assertEqual((pin.x, pin.y, pin.area), (0.695, 0.795, None))

    def test_unplaced_and_skipped_instances_have_no_destination(self):
        source = tables([instance(229, 20, 30), instance(44, 20, 30), instance(999, 0, 0), instance(1000, 20, 30, -1)])
        with patch.dict(ZONES, {229: [1428]}, clear=True):
            entrances, _, _, _, _, unplaced = generate(source)
        self.assertEqual(entrances, {229: (1428, 0.7, 0.8)})
        self.assertEqual(unplaced, ["Instance 999", "Instance 1000"])


if __name__ == "__main__":
    unittest.main()
