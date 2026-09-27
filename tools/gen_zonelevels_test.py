"""A zone's range comes from its areas; a UiMapAssignment area AreaTable lacks is a broken export."""

import unittest

from tools.gen_zonelevels import exploration_range


def area(area_id, level):
    return {"ID": str(area_id), "ExplorationLevel": str(level)}


class ExplorationRangeTest(unittest.TestCase):
    def test_spans_the_areas_and_their_subzones(self):
        areas = {1: area(1, 10), 2: area(2, 0), 3: area(3, 20)}
        self.assertEqual(exploration_range(5, {(5, 1), (5, 2)}, areas, {2: [3]}), (10, 20))

    def test_an_assignment_to_an_unknown_area_fails(self):
        with self.assertRaisesRegex(ValueError, "area 9"):
            exploration_range(5, {(5, 1), (5, 9)}, {1: area(1, 10)}, {})


if __name__ == "__main__":
    unittest.main()
