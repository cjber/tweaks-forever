"""Render the README screenshots for Gear groups from the client's own UI art.

    python3 tools/screenshots.py

Needs Pillow and the wowmock library (env WOWMOCK, default ~/.claude/skills/wow-mock-screenshots). Assets
are fetched from wago.tools once and cached under ~/.cache/wowmock/<build>/.
"""

import os
import sys
from pathlib import Path

WOWMOCK = Path(os.environ.get("WOWMOCK", Path.home() / ".claude" / "skills" / "wow-mock-screenshots"))
if not (WOWMOCK / "wowmock.py").exists():
    sys.exit(f"wowmock.py not found in {WOWMOCK}; set WOWMOCK to the directory that holds it")
sys.path.insert(0, str(WOWMOCK))

from wowmock import (
    NORMAL,
    MenuButton,
    MenuCheckbox,
    MenuDivider,
    MenuTitle,
    TooltipLine,
    Ui,
    colored,
    container_frame,
    context_menu,
    item_tooltip_lines,
    scene,
    tooltip,
)

OUT = Path(__file__).resolve().parent.parent / "docs" / "screenshots"
PLAYER_LEVEL = 22
MARGIN = 28

# Gear.lua PALETTE, taken in turn as the groups were created.
GROUPS = {"DPS": (243 / 255, 139 / 255, 168 / 255), "Levelling": (148 / 255, 226 / 255, 213 / 255), "Tank": (180 / 255, 190 / 255, 254 / 255)}
HOVERED = 4
# Backpack slots in order: (itemID, stack count, groups).
BAG = [
    (6948, None, ()),  # Hearthstone
    (2194, None, ("Tank",)),  # Diamond Hammer
    (4818, None, ("DPS",)),  # Executioner's Sword
    (7956, None, ("Levelling",)),  # Bronze Warhammer
    (281927, None, ("DPS", "Levelling")),  # Boulderheart Band
    (4821, None, ("Tank",)),  # Bear Buckler
    (2870, None, ("DPS",)),  # Shining Silver Breastplate
    (4800, None, ("Tank",)),  # Mighty Chain Pants
    (3481, None, ("Tank",)),  # Silvered Bronze Shoulders
    (3482, None, ("Levelling",)),  # Silvered Bronze Boots
    (2589, 17, ()),  # Linen Cloth
    (2592, 8, ()),  # Wool Cloth
    (118, 5, ()),  # Minor Healing Potion
    (2581, 12, ()),  # Heavy Linen Bandage
    (159, 9, ()),  # Refreshing Spring Water
    (None, None, ()),
]
MONEY = 3 * 10000 + 47 * 100 + 12


def strip(canvas, x, y, index):
    """Gear.lua's Strip: a dark backing and one segment per group, along the slot's bottom edge."""
    groups = BAG[index][2]
    if not groups:
        return
    size = 37
    canvas.fill(x + 2, y + size - 2 - 5, size - 4, 5, (0, 0, 0, 0.8))
    width = (size - 6) / len(groups)
    for i, name in enumerate(groups):
        canvas.fill(x + 3 + i * width, y + size - 3 - 3, width, 3, GROUPS[name])


def backpack(ui):
    return container_frame(
        ui, "Backpack", 133633, [(item, count) for item, count, _ in BAG], MONEY, hover=HOVERED, artwork=strip
    )


def gear(ui):
    item = ui.item(BAG[HOVERED][0])
    names = ", ".join(colored(name, GROUPS[name]) for name in BAG[HOVERED][2])
    tip = tooltip(ui, item_tooltip_lines(ui, item, PLAYER_LEVEL) + [TooltipLine("Gear: " + names, NORMAL)])
    bag, rects = backpack(ui)
    slot_x, slot_y, _, _ = rects["slots"][HOVERED]
    # A bag on the right half of the screen puts the tooltip's BOTTOMRIGHT on the button's TOPLEFT
    # (ContainerFrameItemButton_CalculateItemTooltipAnchors).
    scene(ui, [(bag, 0, 0), (tip, slot_x - tip.width, slot_y - tip.height)], MARGIN).save(OUT / "gear.png")


def menu(ui):
    item_id, _, groups = BAG[HOVERED]
    entries = [MenuTitle(ui.item(item_id).name)]
    entries += [MenuCheckbox(colored(name, GROUPS[name]), name in groups) for name in sorted(GROUPS)]
    entries += [MenuButton("New group…"), MenuDivider()]
    entries += [MenuButton("Equip " + name) for name in groups]
    entries += [MenuButton("Colour", submenu=True, hover=True)]
    panel, menu_rects = context_menu(ui, entries)
    bag, rects = backpack(ui)
    slot_x, slot_y, slot_w, slot_h = rects["slots"][HOVERED]
    # A context menu opens with its top-left at the cursor, here over the middle of the slot.
    menu_x, menu_y, _, _ = menu_rects["menu"]
    cursor = (slot_x + slot_w / 2 - menu_x, slot_y + slot_h / 2 - menu_y)
    scene(ui, [(bag, 0, 0), (panel, *cursor)], MARGIN).save(OUT / "menu.png")


def main():
    ui = Ui(scale=2)
    gear(ui)
    menu(ui)


if __name__ == "__main__":
    main()
