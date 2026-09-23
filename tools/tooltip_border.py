"""Draw media/TooltipBorder.tga, the border Retail-style tooltips put on a tooltip's NineSlice.

    python3 tools/tooltip_border.py

A 16x16-unit rounded rectangle at 2 texels per unit: a one-unit line 2.5 units in from the edge with a
3.5-unit corner radius, lit brighter along the top as the retail tooltip's is. Blizzard starts the tooltip's
centre 3 units in, so the line's inner side meets the background and everything outside the line is clear.
There is no shadow on either side of the line: tooltips turn pixel snapping off (SharedTooltip_OnLoad ->
NineSliceUtil.DisableSharpening), so an edge that lands between screen pixels is filtered into whatever
texels sit beside the line, and a dark shadow there shows as a black strip down the tooltip's sides. Two
texels per unit keeps the line's own edges sharp at the usual UI scales. The 7-unit corners are the
NineSlice's corner pieces and the 2-unit middle row and column its edges, which Tooltips.lua stretches. The
line is grey-white; the addon tints it with SetVertexColor. Stdlib only, and the output is byte-identical
between runs.
"""

import math
import struct
from pathlib import Path

UNITS = 16
TEXELS = 2  # per unit
SIZE = UNITS * TEXELS
INSET = 2.5  # the line's centre, in units from the outer edge
RADIUS = 3.5
TOP, SIDE = 255, 185  # the line's brightness facing up and facing sideways or down
SAMPLES = 8
OUTPUT = Path(__file__).resolve().parent.parent / "media" / "TooltipBorder.tga"


def distance(x: float, y: float) -> tuple[float, float]:
    """Signed distance in units from the line's centre (negative inside) and how far the nearest part faces up."""
    centre, half = UNITS / 2, UNITS / 2 - INSET
    qx, qy = abs(x - centre) - (half - RADIUS), abs(y - centre) - (half - RADIUS)
    outside = math.hypot(max(qx, 0), max(qy, 0))
    signed = outside + min(max(qx, qy), 0) - RADIUS
    if qx > 0 and qy > 0:
        up = qy / outside if y < centre else 0.0
    else:
        up = 1.0 if qy >= qx and y < centre else 0.0
    return signed, up


def pixel(px: int, py: int) -> tuple[int, int, int, int]:
    """Supersample one texel: the line's coverage, as straight-alpha grey."""
    light = covered = 0.0
    for sy in range(SAMPLES):
        for sx in range(SAMPLES):
            x, y = (px + (sx + 0.5) / SAMPLES) / TEXELS, (py + (sy + 0.5) / SAMPLES) / TEXELS
            d, up = distance(x, y)
            if abs(d) <= 0.5:
                light += SIDE + (TOP - SIDE) * up
                covered += 1
    # A clear texel takes the line's colour, so filtering at the line's edge fades it rather than darkening it.
    value = round(light / covered) if covered else SIDE
    return value, value, value, round(covered / (SAMPLES * SAMPLES) * 255)


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
