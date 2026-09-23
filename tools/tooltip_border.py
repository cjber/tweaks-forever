"""Draw media/TooltipBorder.tga, the border Retail-style tooltips put on a tooltip's NineSlice.

    python3 tools/tooltip_border.py

A 16x16 rounded rectangle: a one-pixel line 2.5 pixels in from the edge with a 3.5-pixel corner radius, a
soft shadow either side of it, and the line lit brighter along the top as the retail tooltip's is. The
7-pixel corners are the NineSlice's corner pieces and the 2-pixel middle row and column its edges, which
Tooltips.lua stretches. The line is grey-white; the addon tints it with SetVertexColor. Stdlib only, and the
output is byte-identical between runs.
"""

import math
import struct
from pathlib import Path

SIZE = 16
INSET = 2.5  # the line's centre, from the outer edge
RADIUS = 3.5
TOP, SIDE = 255, 185  # the line's brightness facing up and facing sideways or down
OUTER, INNER = (0.55, 2.0), (0.6, 3.0)  # shadow (strongest alpha, reach in pixels) outside and inside the line
SAMPLES = 8
OUTPUT = Path(__file__).resolve().parent.parent / "media" / "TooltipBorder.tga"


def distance(x: float, y: float) -> tuple[float, float]:
    """Signed distance from the line's centre (negative inside) and how far the nearest part faces up."""
    centre, half = SIZE / 2, SIZE / 2 - INSET
    qx, qy = abs(x - centre) - (half - RADIUS), abs(y - centre) - (half - RADIUS)
    outside = math.hypot(max(qx, 0), max(qy, 0))
    signed = outside + min(max(qx, qy), 0) - RADIUS
    if qx > 0 and qy > 0:
        up = qy / outside if y < centre else 0.0
    else:
        up = 1.0 if qy >= qx and y < centre else 0.0
    return signed, up


def pixel(px: int, py: int) -> tuple[int, int, int, int]:
    """Supersample one pixel: the line over its shadow, as straight-alpha grey."""
    light = alpha = 0.0
    for sy in range(SAMPLES):
        for sx in range(SAMPLES):
            d, up = distance(px + (sx + 0.5) / SAMPLES, py + (sy + 0.5) / SAMPLES)
            if abs(d) <= 0.5:
                light += SIDE + (TOP - SIDE) * up
                alpha += 1
            else:
                strength, reach = OUTER if d > 0 else INNER
                alpha += strength * max(0.0, 1 - (abs(d) - 0.5) / reach)
    count = SAMPLES * SAMPLES
    value = round(light / alpha) if alpha else 0
    return value, value, value, round(alpha / count * 255)


def main() -> None:
    # Uncompressed true-colour, 32 bits with 8 of alpha, rows from the top (descriptor 0x28), like Icon.tga.
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28)
    body = bytearray()
    for py in range(SIZE):
        for px in range(SIZE):
            r, g, b, a = pixel(px, py)
            body += bytes((b, g, r, a))
    OUTPUT.write_bytes(header + body)
    print(f"wrote {OUTPUT.relative_to(Path.cwd()) if OUTPUT.is_relative_to(Path.cwd()) else OUTPUT}")


if __name__ == "__main__":
    main()
