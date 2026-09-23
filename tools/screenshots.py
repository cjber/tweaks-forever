"""Render the README screenshots from the client's own UI art.

    python3 tools/screenshots.py

Needs Pillow and the wowmock library (env WOWMOCK, default ~/.claude/skills/wow-mock-screenshots). Assets
are fetched from wago.tools once and cached under ~/.cache/wowmock/<build>/.
"""

import os
import re
import sys
from pathlib import Path

WOWMOCK = Path(os.environ.get("WOWMOCK", Path.home() / ".claude" / "skills" / "wow-mock-screenshots"))
if not (WOWMOCK / "wowmock.py").exists():
    sys.exit(f"wowmock.py not found in {WOWMOCK}; set WOWMOCK to the directory that holds it")
sys.path.insert(0, str(WOWMOCK))

# wowmock resolves from $WOWMOCK at runtime (sys.path above), so ty cannot see it.
from wowmock import (  # ty: ignore[unresolved-import]
    FONTS,
    NORMAL,
    MenuButton,
    MenuCheckbox,
    MenuDivider,
    MenuTitle,
    TooltipLine,
    Ui,
    close_button,
    colored,
    container_frame,
    context_menu,
    dialog_border,
    draw_nine_slice,
    draw_overlay,
    edit_mode_checkbox,
    edit_mode_selection,
    item_tooltip_lines,
    map_art,
    map_art_id,
    map_overlays,
    minimal_scrollbar,
    minimal_slider,
    panel_tabs,
    scene,
    tooltip,
    ui_panel_button,
    unique_corners_layout,
    world_map_frame,
)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "screenshots"
PLAYER_LEVEL = 22
MARGIN = 28

# Gear.lua PALETTE, taken in turn as the groups were created.
GROUPS = {
    "DPS": (243 / 255, 139 / 255, 168 / 255),
    "Levelling": (148 / 255, 226 / 255, 213 / 255),
    "Tank": (180 / 255, 190 / 255, 254 / 255),
}
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


REDRIDGE = 1433
# A level 22 character who has walked in from Lakeshire but not yet ridden east past Alther's Mill.
EXPLORED = {"Three Corners", "Lakeridge Highway", "Lake Everstill", "Lakeshire", "Redridge Canyons", "Alther's Mill"}
# Exploration.lua: the unexplored overlays' vertex colour.
REVEAL_TINT = (0.55, 0.65, 0.85, 0.8)


def addon_overlays(art):
    """Exploration.lua's areas for one map art, decoded from the addon's own Data/Overlays.lua (layer 1 only)."""
    source = (ROOT / "Data" / "Overlays.lua").read_text()
    entry = re.search(rf"\[{art}\] = ((?:\"[^\"]*\"\s*(?:\.\.\s*)?)+)", source)
    if not entry:
        sys.exit(f"Data/Overlays.lua has no entry for map art {art}")
    encoded = "".join(re.findall(r'"([^"]*)"', entry.group(1)))
    areas = []
    for record in filter(None, encoded.split(";")):
        layer, x, y, width, height, *files = (int(v) for v in record.split(","))
        if layer == 1:
            areas.append((x, y, width, height, files))
    return areas


def exploration(ui):
    """The world map on Redridge with Reveal unexplored areas on: Blizzard's explored overlays at full colour
    over the addon's tinted unexplored ones, which sit a sublevel below them (ARTWORK -1)."""
    art = map_art(ui, REDRIDGE)
    areas = ui.table("AreaTable")
    overlays = ui.table("WorldMapOverlay")
    explored = set()
    for overlay in map_overlays(ui, REDRIDGE):
        row = overlays[str(overlay.id)]
        names = {areas[row[f"AreaID_{i}"]]["AreaName_lang"] for i in range(4) if row[f"AreaID_{i}"] != "0"}
        if names & EXPLORED:
            explored.add(overlay.key)
    for x, y, width, height, files in addon_overlays(map_art_id(ui, REDRIDGE)):
        if f"{x}:{y}:{width}:{height}" not in explored:
            draw_overlay(ui, art, x, y, width, height, files, REVEAL_TINT)
    for overlay in map_overlays(ui, REDRIDGE):
        if overlay.key in explored:
            draw_overlay(ui, art, overlay.offset_x, overlay.offset_y, overlay.width, overlay.height, overlay.tiles)
    nav = ("World", "Eastern Kingdoms", "Redridge Mountains")
    frame, _ = world_map_frame(ui, art, nav, arrows=nav[1:])
    scene(ui, [(frame, 0, 0)], MARGIN).save(OUT / "exploration.png")


# Junk.lua marks (account-wide): things this character sells rather than uses. Greys would only show their coin
# at a merchant, so the bag has none, and every coin here is the addon's.
JUNK_BAG = [
    (6948, None, False),  # Hearthstone
    (1189, None, True),  # Overseer's Ring
    (2589, 14, True),  # Linen Cloth
    (2672, 6, True),  # Stringy Wolf Meat
    (769, 4, True),  # Chunk of Boar Meat
    (1468, 3, True),  # Murloc Fin
    (2592, 9, False),  # Wool Cloth
    (2318, 11, False),  # Light Leather
    (858, 4, False),  # Lesser Healing Potion
    (2581, 10, False),  # Heavy Linen Bandage
    (4541, 12, False),  # Freshly Baked Bread
    (1179, 8, False),  # Ice Cold Milk
    (2770, 7, False),  # Copper Ore
    (774, None, False),  # Malachite
    (None, None, False),
    (None, None, False),
]
JUNK_HOVERED = 1
JUNK_LINE = "Marked as junk \u2013 Alt+Right-click to unmark"


def junk(ui):
    marked = {i for i, (_, _, mark) in enumerate(JUNK_BAG) if mark}
    slots = [(item, count) for item, count, _ in JUNK_BAG]
    bag, rects = container_frame(ui, "Backpack", 133633, slots, MONEY, hover=JUNK_HOVERED, junk=marked)
    item = ui.item(JUNK_BAG[JUNK_HOVERED][0])
    # Junk.lua's SetBagItem post-hook: AddLine(text, 1, 0.82, 0, true).
    tip = tooltip(ui, item_tooltip_lines(ui, item, PLAYER_LEVEL) + [TooltipLine(JUNK_LINE, (1, 0.82, 0))])
    slot_x, slot_y, _, _ = rects["slots"][JUNK_HOVERED]
    scene(ui, [(bag, 0, 0), (tip, slot_x - tip.width, slot_y - tip.height)], MARGIN).save(OUT / "junk.png")


# Campsites.lua for a Mana Well (object 651948, aura 1230587). The aura's Description is empty in this build, so
# C_Spell.GetSpellDescription gives "" and the line falls back to the aura's name; the aura lasts an hour.
CAMP_FEATURE = "Mana Well"
CAMP_AURA = 1230587
CAMP_MINUTES_LEFT = 48


def campsite(ui):
    green = ui.global_color("GREEN_FONT_COLOR")[:3]
    aura = ui.table("SpellName")[str(CAMP_AURA)]["Name_lang"]
    assert not ui.table("Spell").get(str(CAMP_AURA), {}).get("Description_lang"), "the aura has a description now"
    # SecondsToTime(left, true): MINUTES_ABBR "%d Min".
    lines = [
        TooltipLine(CAMP_FEATURE),
        TooltipLine(f"Sitting nearby: {aura}", green),
        TooltipLine(f"Active: {CAMP_MINUTES_LEFT} Min", green),
    ]
    scene(ui, [(tooltip(ui, lines), 0, 0)], MARGIN).save(OUT / "campsite.png")


# Frames.lua's Edit Mode editor on a 1366x768 UIParent, the Character window picked on the Windows tab.
UI_WIDTH = 1366
MANAGER_WIDTH, MANAGER_TOP = 510, 100  # EditModeManagerFrame: fixedWidth, anchored TOP (0, -100)
SHEET_HEIGHT = 420  # SHEET_MIN_HEIGHT, which the manager's own height does not exceed at this size
CHARACTER_SIZE = (398, 484)  # CHARACTER_FRAME_COLLAPSED_WIDTH x CHARACTER_FRAME_HEIGHT
PANEL_LEFT, PANEL_TOP = 16, 116  # UIPanel layout LEFT_OFFSET, TOP_OFFSET for a "left" area panel


def window_labels():
    """The Windows tab's labels, in Frames.lua's order."""
    source = (ROOT / "Frames.lua").read_text()
    block = source[source.index("local windows = {") : source.index("\n}", source.index("local windows = {"))]
    return re.findall(r'\{ "\w+", "([^"]+)"', block)


def editmode(ui):
    canvas = ui.canvas(UI_WIDTH, 768)
    labels = window_labels()
    # The selected window's preview: the Character frame where the panel manager opens it.
    edit_mode_selection(canvas, PANEL_LEFT, PANEL_TOP, *CHARACTER_SIZE, labels[0])
    x, y, w, h = (UI_WIDTH - MANAGER_WIDTH) / 2, MANAGER_TOP, MANAGER_WIDTH, SHEET_HEIGHT
    # The tabs sit below the sheet (manager level vs +20), TOPLEFT at its BOTTOMLEFT (11, 2).
    panel_tabs(canvas, x + 11, y + h - 2, ["HUD", "Windows"], selected=1)
    dialog_border(canvas, x, y, w, h)
    large, normal_large = FONTS["GameFontHighlightLarge"], FONTS["GameFontNormalLarge"]
    canvas.text(x, y + 15, "Edit Mode", large, justify="CENTER", width=w)
    canvas.text(
        x + 25,
        y + 48,
        "Show a window to move and scale it. Changes save at once for this layout.",
        FONTS["GameFontHighlight"],
    )
    ix, iy, iw, ih = x + 25, y + 84, w - 50, h - 84 - 24
    draw_nine_slice(canvas, unique_corners_layout("OptionsFrame"), ix, iy, iw, ih)
    canvas.text(ix + 10, iy + 8, "Windows", normal_large)
    # ScrollFrameTemplate (4, -36) to (-24, 6); its MinimalScrollBar at TOPRIGHT (6, 2) to BOTTOMRIGHT (6, 5).
    sx, sy, sw, sh = ix + 4, iy + 36, iw - 28, ih - 42
    rows = ui.canvas(sw, sh)
    for index, label in enumerate(labels):
        edit_mode_checkbox(rows, index % 2 * 215, index // 2 * 32, label, checked=index == 0)
    canvas.paste(rows, sx, sy)
    content = (len(labels) + 1) // 2 * 32
    minimal_scrollbar(canvas, sx + sw + 6, sy - 2, sh + 2 - 5, visible=sh / content)
    # The window dialog, MakePanel(320, 164) at the manager's TOPRIGHT (8, 0).
    dx, dy = x + w + 8, y
    dialog_border(canvas, dx, dy, 320, 164)
    canvas.text(dx + 18, dy + 18, labels[0], large)
    canvas.text(dx + 18, dy + 55, "Scale", FONTS["GameFontHighlightMedium"])
    minimal_slider(canvas, dx + 80, dy + 46, 180, 32, 100, 50, 150)
    canvas.text(dx + 267, dy + 55, "100%", FONTS["GameFontHighlightSmall"])
    ui_panel_button(canvas, dx + 18, dy + 94, 284, 24, "Reset To Default Position")
    canvas.text(dx + 18, dy + 133, "Reset also restores the original scale.", FONTS["GameFontHighlightSmall"])
    close_button(canvas, dx + 320, dy)
    scene(ui, [(canvas, 0, 0)], MARGIN).save(OUT / "editmode.png")


def main():
    ui = Ui(scale=2)
    gear(ui)
    menu(ui)
    exploration(ui)
    junk(ui)
    campsite(ui)
    editmode(ui)


if __name__ == "__main__":
    main()
