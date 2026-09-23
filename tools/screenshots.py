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
    FRIZQT,
    NORMAL,
    Font,
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
    wrap_text,
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


KALIMDOR = 1414
# ZoneLevels.lua's font: GameFontNormalSmallOutline (SystemFont_Shadow_Small_Outline), recoloured per zone.
LABEL_FONT = Font(FRIZQT, 10, NORMAL, (1, -1), outline=True)
# QuestDifficultyColors, as Blizzard's Constants.lua defines them.
DIFFICULTY = {
    "impossible": (1.00, 0.10, 0.10),
    "verydifficult": (1.00, 0.50, 0.25),
    "difficult": (1.00, 0.82, 0.00),
    "standard": (0.25, 0.75, 0.25),
    "trivial": (0.50, 0.50, 0.50),
}
# UnitQuestTrivialLevelRange at the screenshot's level: the classic green band (5 + level // 10 below 40).
TRIVIAL_RANGE = 5 + PLAYER_LEVEL // 10


def zone_ranges():
    """Data/ZoneLevels.lua: {uiMapID: (low, high)}."""
    source = (ROOT / "Data" / "ZoneLevels.lua").read_text()
    return {int(i): (int(lo), int(hi)) for i, lo, hi in re.findall(r"\[(\d+)\] = \{ (\d+), (\d+) \}", source)}


def difficulty(level, low, high):
    """ZoneLevels.lua's Color: Model.ChallengeLevel fed to GetRelativeDifficultyColor."""
    challenge = low if level < low else high - 2 if level > high else level
    diff = challenge - level
    if diff >= 5:
        return DIFFICULTY["impossible"]
    if diff >= 3:
        return DIFFICULTY["verydifficult"]
    if diff >= -4:
        return DIFFICULTY["difficult"]
    return DIFFICULTY["standard" if -diff <= TRIVIAL_RANGE else "trivial"]


def map_rect_on_map(ui, child, parent):
    """C_Map.GetMapRectOnMap from UiMapAssignment: the child's world rectangle in the parent's normalised
    coordinates (map x runs along world -Y, map y along world -X)."""

    def assignment(map_id):
        rows = [r for r in ui.table("UiMapAssignment").values() if r["UiMapID"] == str(map_id)]
        return min(rows, key=lambda r: int(r["OrderIndex"]))

    def region(row):
        return [float(row[f"Region_{i}"]) for i in range(6)]

    x0, y0, _, x1, y1, _ = region(assignment(child))
    p = assignment(parent)
    px0, py0, _, px1, py1, _ = region(p)
    u0, v0, u1, v1 = (float(p[k]) for k in ("UiMin_0", "UiMin_1", "UiMax_0", "UiMax_1"))

    def project(wx, wy):
        return u0 + (py1 - wy) / (py1 - py0) * (u1 - u0), v0 + (px1 - wx) / (px1 - px0) * (v1 - v0)

    (ax, ay), (bx, by) = project(x1, y1), project(x0, y0)
    return ax, bx, ay, by


def zone_levels(ui):
    """Kalimdor at a level 22 character's zoom-out: every zone's range at the centre of its rectangle."""
    art = map_art(ui, KALIMDOR)
    nav = ("World", "Kalimdor")
    frame, rects = world_map_frame(ui, art, nav, arrows=nav[1:])
    mx, my, mw, mh = rects["map"]
    ranges = zone_ranges()
    for row in ui.table("UiMap").values():
        map_id = int(row["ID"])
        if row["ParentUiMapID"] != str(KALIMDOR) or map_id not in ranges:
            continue
        low, high = ranges[map_id]
        min_x, max_x, min_y, max_y = map_rect_on_map(ui, map_id, KALIMDOR)
        x, y = mx + (min_x + max_x) / 2 * mw, my + (min_y + max_y) / 2 * mh
        text = f"{low}-{high}" if low != high else str(low)
        width = frame.text_width(text, LABEL_FONT)
        frame.text(x - width / 2, y - LABEL_FONT.height / 2, text, LABEL_FONT, difficulty(PLAYER_LEVEL, low, high))
    scene(ui, [(frame, 0, 0)], MARGIN).save(OUT / "zonelevels.png")


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


# Campsites.lua's texts, from Data/CampBenefits.lua. Wrapped tooltip lines stop at about spell-tooltip width
# (wowmock NOTES); the client leaves no gap between the lines of one wrapped string, the mock leaves 2 units.
TOOLTIP_WRAP = 250
CAMP_HINT = "Sit or craft near a camp feature for a minute to gain its benefit:"
# Seconds left on the benefits the player has in the scenes; SecondsToTime(left, true) gives MINUTES_ABBR "%d Min".
CAMP_HAVE = {1230124: 52 * 60, 1230587: 48 * 60, 1229451: 31 * 60}
CAMP_FEATURE = 1230587  # the Mana Well, hovered with 48 minutes left


def camp_benefits():
    """[(aura, feature, effect, seconds or None)] in Data/CampBenefits.lua's order."""
    source = (ROOT / "Data" / "CampBenefits.lua").read_text()
    body = source[source.index("ns.CampBenefits = {") :]
    entries = re.findall(r'\{\s*(\d+),\s*"([^"]+)",\s*((?:"[^"]*"\s*(?:\.\.\s*)?)+),?\s*(\d+)?,?\s*\}', body)
    return [(int(a), f, "".join(re.findall(r'"([^"]*)"', e)), int(s) if s else None) for a, f, e, s in entries]


def wrapped(ui, text, color):
    lines = wrap_text(ui.canvas(1, 1), text, FONTS["GameTooltipText"], TOOLTIP_WRAP)
    return [TooltipLine(line, color) for line in lines]


def minutes(seconds):
    return f"{seconds // 60} Min" if seconds < 3600 else f"{seconds // 3600} Hr"


def camp_rows(ui):
    """AddCampList: the hint, then the benefits the player has (green, time left), then the rest (grey)."""
    green, grey = ui.global_color("GREEN_FONT_COLOR")[:3], ui.global_color("GRAY_FONT_COLOR")[:3]
    benefits = camp_benefits()
    have = [b for b in benefits if b[0] in CAMP_HAVE] + [b for b in benefits if b[0] not in CAMP_HAVE]
    lines = wrapped(ui, CAMP_HINT, (1, 1, 1))
    for aura, feature, effect, seconds in have:
        left = CAMP_HAVE.get(aura)
        if left is None:
            lines += wrapped(ui, f"{feature}: {effect}", grey)
        elif seconds is None:
            lines += wrapped(ui, f"{feature}: rested, again in {minutes(left)}", green)
        else:
            lines += wrapped(ui, f"{feature} ({minutes(left)}): {effect}", green)
    return lines


def campsite(ui):
    green = ui.global_color("GREEN_FONT_COLOR")[:3]
    _, feature, effect, seconds = next(b for b in camp_benefits() if b[0] == CAMP_FEATURE)
    lines = [TooltipLine(feature)]
    lines += wrapped(ui, f"Sitting nearby: {effect} for {minutes(seconds)}", green)
    lines.append(TooltipLine(f"Active: {minutes(CAMP_HAVE[CAMP_FEATURE])}", green))
    scene(ui, [(tooltip(ui, lines), 0, 0)], MARGIN).save(OUT / "campsite.png")


def camp_panel(ui):
    # GameTooltip_SetTitle "Camp", then AddCampList; the close button at the TOPRIGHT (2, 2), as ItemRefTooltip's.
    panel = tooltip(ui, [TooltipLine("Camp")] + camp_rows(ui))
    close = ui.canvas(24, 24)
    close_button(close, 24, 0)
    scene(ui, [(panel, 0, 0), (close, panel.width + 2 - 24, -2)], MARGIN).save(OUT / "camp.png")


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
    zone_levels(ui)
    junk(ui)
    campsite(ui)
    camp_panel(ui)
    editmode(ui)


if __name__ == "__main__":
    main()
