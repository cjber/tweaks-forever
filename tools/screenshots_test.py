"""Check emitted map geometry without downloading the screenshot art."""

import ast
import unittest
from pathlib import Path
from unittest.mock import Mock

# Map/DungeonMaps.lua: the art's canvas, and the padded tile each of the four by three textures holds.
ART_WIDTH, ART_HEIGHT, TEXEL = 1002, 668, 256
# The decoded size of a tile texture, whatever the art's canvas is: texcoords are fractions of it.
TEXTURE = 512
# The world map's scroll container, and its maximized size. forever-core's wowmock sizes it WORLD_MAP_WIDTH 702 - 5 by
# WORLD_MAP_HEIGHT 534 - 2 - 67, and Blizzard scales to the same ratio when maximized: the art is never stretched.
CONTAINER, MAXIMIZED = (697, 465), (1394, 930)
SIZES = (CONTAINER, MAXIMIZED)


class FakeTexture:
    """A decoded tile texture without the art: TEXTURE square, and cropped to the size of whatever box it is given."""

    def __init__(self, size=(TEXTURE, TEXTURE)):
        self.size = size

    def crop(self, box):
        return FakeTexture((box[2] - box[0], box[3] - box[1]))


def dungeon_map(width, height):
    """`dungeon_map` from tools/screenshots.py, with the art a fake texture and the map stubbed."""
    source = Path(__file__).with_name("screenshots.py").read_text()
    tree = ast.parse(source)
    function = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "dungeon_map")
    frame, ui = Mock(), Mock()
    ui.texture.return_value = FakeTexture()
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
    return frame


class DungeonMapGeometryTest(unittest.TestCase):
    def test_tiles_fill_the_container_in_four_by_three(self):
        # Each tile covers its own slice of the art canvas, so a row spans the container's width edge to edge.
        for width, height in SIZES:
            with self.subTest(width=width, height=height):
                frame = dungeon_map(width, height)
                self.assertEqual(frame.draw.call_count, 12)
                tiles = [call.args[1:5] for call in frame.draw.call_args_list]
                rows = [tiles[at : at + 4] for at in range(0, 12, 4)]
                self.assertAlmostEqual(rows[0][0][0], 20)
                self.assertAlmostEqual(rows[0][0][1], 30)
                for row in rows:
                    for left, right in zip(row, row[1:], strict=False):
                        self.assertAlmostEqual(left[0] + left[2], right[0], places=6)
                    self.assertAlmostEqual(row[-1][0] + row[-1][2], 20 + width, places=6)
                for upper, lower in zip(rows, rows[1:], strict=False):
                    for above, below in zip(upper, lower, strict=True):
                        self.assertAlmostEqual(above[1] + above[3], below[1], places=6)
                self.assertAlmostEqual(rows[-1][-1][1] + rows[-1][-1][3], 30 + height, places=6)
                # The whole art, from the first tile's top-left to the last tile's bottom-right, keeps the art's ratio:
                # the map is never deformed.
                art_left, art_top = rows[0][0][0], rows[0][0][1]
                art_right = rows[-1][-1][0] + rows[-1][-1][2]
                art_bottom = rows[-1][-1][1] + rows[-1][-1][3]
                self.assertAlmostEqual(
                    (art_right - art_left) / (art_bottom - art_top),
                    ART_WIDTH / ART_HEIGHT,
                    delta=ART_WIDTH / ART_HEIGHT * 0.005,
                )

    def test_tiles_are_the_art_canvas_slices(self):
        # Each tile is the slice of the art canvas it holds, in a container that has the art's own ratio.
        for width, height in SIZES:
            with self.subTest(width=width, height=height):
                frame = dungeon_map(width, height)
                tiles = [call.args[1:5] for call in frame.draw.call_args_list]
                for index, (_, _, tile_width, tile_height) in enumerate(tiles):
                    left, top = index % 4 * TEXEL, index // 4 * TEXEL
                    self.assertAlmostEqual(tile_width, width * min(TEXEL, ART_WIDTH - left) / ART_WIDTH, places=6)
                    self.assertAlmostEqual(tile_height, height * min(TEXEL, ART_HEIGHT - top) / ART_HEIGHT, places=6)

    def test_tiles_are_cropped_to_their_texcoords(self):
        # Layout crops the padded texture: the last column keeps 234 of the art's 1002 pixels, the last row 156 of 668.
        for width, height in SIZES:
            with self.subTest(width=width, height=height):
                crops = [call.args[0].size for call in dungeon_map(width, height).draw.call_args_list]
                self.assertEqual(crops[0], (TEXTURE, TEXTURE))
                self.assertEqual(crops[3], (round(TEXTURE * 234 / TEXEL), TEXTURE))
                self.assertEqual(crops[8], (TEXTURE, round(TEXTURE * 156 / TEXEL)))
                self.assertEqual(crops[11], (round(TEXTURE * 234 / TEXEL), round(TEXTURE * 156 / TEXEL)))


if __name__ == "__main__":
    unittest.main()
