"""Draw media/TooltipBorder.tga, the whole tooltip Retail-style tooltips draw on a tooltip's NineSlice.

    python3 tools/tooltip_border.py

A 16x16-unit rounded rectangle at 2 texels per unit: a one-unit grey line 2.5 units in from the edge with a
3.5-unit corner radius, lit brighter along the top as the retail tooltip's is, and the tooltip's background
filling everything inside it. Tooltips.lua cuts all nine NineSlice pieces from this one file, the Center
included: the 7-unit corners are the corner pieces and the 2-unit middle row, column and square are the
edges and the Center, which it stretches. The line and the background are one image, so no edge between two
separately placed textures runs along the line for a stray sub-pixel to open. Everything outside the line is
clear, in the line's colour, so filtering at its outer edge fades it rather than darkening it. The colours are
final (the addon draws the file untinted). Stdlib only, and the output is byte-identical between runs.
"""

import math
import struct
from pathlib import Path

UNITS = 16
TEXELS = 2  # per unit
SIZE = UNITS * TEXELS
INSET = 2.5  # the line's centre, in units from the outer edge
RADIUS = 3.5
TOP, SIDE = 255, 185  # the line's brightness facing up and facing sideways or down, before TINT
TINT = (0.6, 0.62, 0.65)  # brings the line to the retail grey
# Blizzard's tooltip background: the Tooltip-NineSlice-Center texel (141, 142, 141, alpha 195) under
# TOOLTIP_DEFAULT_BACKGROUND_COLOR (GlobalColor 0xFF171730), as SharedTooltip_SetBackdropStyle colours it.
FILL = (141 * 0x17 / 255, 142 * 0x17 / 255, 141 * 0x30 / 255, 195 / 255)
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
    """Supersample one texel: the line over the background inside it, as straight-alpha colour."""
    colour, alpha = [0.0, 0.0, 0.0], 0.0
    for sy in range(SAMPLES):
        for sx in range(SAMPLES):
            d, up = distance((px + (sx + 0.5) / SAMPLES) / TEXELS, (py + (sy + 0.5) / SAMPLES) / TEXELS)
            if abs(d) <= 0.5:
                grey = SIDE + (TOP - SIDE) * up
                rgb, a = [grey * t for t in TINT], 1.0
            elif d < 0:
                rgb, a = list(FILL[:3]), FILL[3]
            else:
                continue
            colour = [c + v * a for c, v in zip(colour, rgb, strict=True)]
            alpha += a
    if not alpha:
        # Clear: the side line's colour, so bilinear filtering at the line's outer edge only fades it.
        r, g, b = (round(SIDE * t) for t in TINT)
        return r, g, b, 0
    r, g, b = (round(c / alpha) for c in colour)
    return r, g, b, round(alpha / (SAMPLES * SAMPLES) * 255)


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
