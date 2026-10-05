import tempfile
import unittest
from pathlib import Path
from unittest import mock

import gen_dungeons
import gen_overlays
import gen_zonelevels


def cached(module, name, text, call, *args):
    with tempfile.TemporaryDirectory() as directory:
        cache = Path(directory)
        (cache / f"{name}-{module.BUILD}.csv").write_text(text, encoding="utf-8")
        with mock.patch.object(module, "CACHE", cache):
            return call(name, *args, offline=True)


class StrictDb2Test(unittest.TestCase):
    def test_valid_export_is_read(self):
        self.assertEqual(cached(gen_zonelevels, "UiMap", "ID,A\n1,x\n", gen_zonelevels.db2), [{"ID": "1", "A": "x"}])

    def test_every_generator_rejects_the_duplicate_column_repro(self):
        for module, name in ((gen_zonelevels, "UiMap"), (gen_dungeons, "Map")):
            with self.subTest(module=module.__name__), self.assertRaisesRegex(ValueError, "duplicate columns"):
                cached(module, name, "ID,Value,Value\n1,2,3\n", module.db2)

    def test_rejects_duplicate_ids_and_short_rows(self):
        for text, message in (("ID,A\n1,x\n1,y\n", "duplicate ID"), ("ID,A\n1\n", "malformed CSV row")):
            with self.subTest(text=text), self.assertRaisesRegex(ValueError, message):
                cached(gen_dungeons, "Map", text, gen_dungeons.db2)

    def test_overlays_keep_exact_integer_ids(self):
        valid = "ID,UiMapArtStyleID\n5,7\n"
        rows = cached(gen_overlays, "UiMapArt", valid, gen_overlays.db2)
        self.assertEqual(rows, {5: {"ID": 5, "UiMapArtStyleID": 7}})
        for text in ("ID,UiMapArtStyleID\n5.0,7\n", "ID,UiMapArtStyleID\n0,7\n", "ID,UiMapArtStyleID,ID\n5,7,5\n"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                cached(gen_overlays, "UiMapArt", text, gen_overlays.db2)


if __name__ == "__main__":
    unittest.main()
