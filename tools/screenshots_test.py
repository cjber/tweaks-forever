"""Check emitted map geometry without downloading the screenshot art."""

import ast
import unittest
from pathlib import Path
from unittest.mock import Mock


class DungeonMapGeometryTest(unittest.TestCase):
    def test_square_tiles_fit_wide_and_tall_containers(self):
        source = Path(__file__).with_name("screenshots.py").read_text()
        tree = ast.parse(source)
        function = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "dungeon_map")
        # Execute the real drawing function with art replaced by recording mocks. CI has no asset cache.
        for width, height in ((800, 400), (400, 800)):
            with self.subTest(width=width, height=height):
                frame, ui = Mock(), Mock()
                scope = {
                    "ASHENVALE": 43,
                    "FONTS": {"GameFontNormalLarge": object()},
                    "map_art": Mock(),
                    "ui_panel_button": Mock(),
                    "world_map_frame": Mock(return_value=(frame, {"container": (20, 30, width, height)})),
                }
                exec(compile(ast.Module(body=[function], type_ignores=[]), "screenshots.py", "exec"), scope)
                draw = scope["dungeon_map"]
                assert callable(draw)
                draw(ui)
                self.assertEqual(frame.draw.call_count, 12)
                rectangles = [call.args[1:5] for call in frame.draw.call_args_list]
                self.assertEqual(len(set(rectangles)), 12)
                for x, y, tile_width, tile_height in rectangles:
                    self.assertAlmostEqual(tile_width, tile_height)
                    self.assertGreaterEqual(x, 20 + 12)
                    self.assertGreaterEqual(y, 30 + 46)
                    self.assertLessEqual(x + tile_width, 20 + width - 12)
                    self.assertLessEqual(y + tile_height, 30 + height - 12)


if __name__ == "__main__":
    unittest.main()
