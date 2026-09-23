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
    ARIALN,
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
    atlas_markup,
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
ASHENVALE = 1440
# AreaLabelFrameTemplate (scale 0.695): its Name, WorldMapTextFont (Friz 32, thick outline, AREA_NAME_FONT_COLOR),
# sits TOP (0, -20) in a frame anchored TOP (0, -10) on the map's canvas container.
LABEL_SCALE = 0.695
AREA_LABEL_FONT = Font(FRIZQT, round(32 * LABEL_SCALE), (1.0, 0.9294, 0.7607), None, outline=True)
AREA_LABEL_TOP = (10 + 20) * LABEL_SCALE
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
    """ZoneLevels.lua's colour: Model.ChallengeLevel fed to GetRelativeDifficultyColor."""
    challenge = low if level < low else high - 2 if level > high else level
    diff = challenge - level
    if diff >= 5:
        return DIFFICULTY["impossible"]
    if diff >= 3:
        return DIFFICULTY["verydifficult"]
    if diff >= -4:
        return DIFFICULTY["difficult"]
    return DIFFICULTY["standard" if -diff <= TRIVIAL_RANGE else "trivial"]


def zone_levels(ui):
    """Kalimdor with the cursor on Ashenvale: Blizzard's hover label with the addon's range after the name."""
    art = map_art(ui, KALIMDOR)
    nav = ("World", "Kalimdor")
    frame, rects = world_map_frame(ui, art, nav, arrows=nav[1:])
    mx, my, mw, _ = rects["map"]
    low, high = zone_ranges()[ASHENVALE]
    name = ui.table("UiMap")[str(ASHENVALE)]["Name_lang"]
    text = name + colored(f" ({low}-{high})", difficulty(PLAYER_LEVEL, low, high))
    frame.text(mx, my + AREA_LABEL_TOP, text, AREA_LABEL_FONT, justify="CENTER", width=mw)
    scene(ui, [(frame, 0, 0)], MARGIN).save(OUT / "zonelevels.png")


EASTERN_KINGDOMS = 1415
BLACKROCK_MOUNTAIN = 25  # AreaTable ID
ENTRANCE_ICON = 32  # the Dungeon and Raid atlases' size; SetScalingLimits(1, 1.0, 1.2) keeps it on screen at min zoom


def entrances(ui_map):
    """Data/DungeonEntrances.lua for one map: [(x, y, instances, area)]."""
    source = (ROOT / "Data" / "DungeonEntrances.lua").read_text()
    block = re.search(rf"\[{ui_map}\] = \{{(.*?)\n\t\}},", source, re.S)
    if not block:
        raise KeyError(f"no entrances for {ui_map}")
    pattern = r"x = ([\d.]+), y = ([\d.]+), instances = \{ ([\d, ]+) \}(?:, area = (\d+))?"
    return [
        (float(x), float(y), [int(i) for i in ids.split(", ")], int(area) if area else None)
        for x, y, ids, area in re.findall(pattern, block.group(1))
    ]


def raid_instances():
    source = (ROOT / "Data" / "DungeonEntrances.lua").read_text()
    return {int(i) for i in re.findall(r"\[(\d+)\] = true", source.split("ns.RaidInstances", 1)[1])}


def dungeon_entrances(ui):
    """The Eastern Kingdoms with every entrance pinned, pointing at Blackrock Mountain: the POI area label and
    the pin's tooltip (ANCHOR_RIGHT), titled by the complex with its instances in NORMAL_FONT_COLOR."""
    art = map_art(ui, EASTERN_KINGDOMS)
    nav = ("World", "Eastern Kingdoms")
    frame, rects = world_map_frame(ui, art, nav, arrows=nav[1:])
    mx, my, mw, mh = rects["map"]
    raids, maps = raid_instances(), ui.table("Map")
    hovered = None
    for x, y, instances, area in entrances(EASTERN_KINGDOMS):
        atlas = "Raid" if all(i in raids for i in instances) else "Dungeon"
        px, py = mx + x * mw - ENTRANCE_ICON / 2, my + y * mh - ENTRANCE_ICON / 2
        frame.draw(ui.atlas(atlas), px, py, ENTRANCE_ICON, ENTRANCE_ICON)
        if area == BLACKROCK_MOUNTAIN:
            hovered = (px, py, instances)
            # The HIGHLIGHT layer: the same atlas drawn ADD at alpha 0.4.
            frame.draw(ui.atlas(atlas), px, py, ENTRANCE_ICON, ENTRANCE_ICON, color=(1, 1, 1, 0.4), blend="ADD")
    if hovered is None:
        raise KeyError("no Blackrock Mountain pin on the Eastern Kingdoms")
    px, py, instances = hovered
    title = ui.table("AreaTable")[str(BLACKROCK_MOUNTAIN)]["AreaName_lang"]
    frame.text(mx, my + AREA_LABEL_TOP, title, AREA_LABEL_FONT, justify="CENTER", width=mw)
    icons = {i: atlas_markup("Raid" if i in raids else "Dungeon", 16, 16) for i in instances}
    names = [f"{icons[i]} {maps[str(i)]['MapName_lang']}" for i in instances]
    lines = [TooltipLine(title)] + [TooltipLine(name, NORMAL) for name in names]
    tip = tooltip(ui, lines)
    scene(ui, [(frame, 0, 0), (tip, px + ENTRANCE_ICON, py - tip.height)], MARGIN).save(OUT / "dungeons.png")


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
# The Campfire Nearby aura (1283391) as the game describes it, and the way to the campfire in the scene.
CAMPFIRE_NEARBY = "The pleasant smoke of a campfire drifts in the air from somewhere nearby."
CAMPFIRE_WAY = "Campfire: about 35 yd ahead to your left"
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
    """AddNearby's benefit rows: only those the player has, green with their time left, in the game's order."""
    green = ui.global_color("GREEN_FONT_COLOR")[:3]
    lines = []
    for aura, feature, effect, seconds in camp_benefits():
        left = CAMP_HAVE.get(aura)
        if left is None:
            continue
        if seconds is None:
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


def campfire_buff(ui):
    # The buff's own name and gold description, then AddNearby: a blank line, the way to the fire, the benefits.
    lines = [TooltipLine("Campfire Nearby")] + wrapped(ui, CAMPFIRE_NEARBY, NORMAL)
    lines += [TooltipLine(" "), TooltipLine(CAMPFIRE_WAY)] + camp_rows(ui)
    scene(ui, [(tooltip(ui, lines), 0, 0)], MARGIN).save(OUT / "camp.png")


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


# Nameplates.lua at the Medium size: a 190-wide plate less Blizzard's 12 inset each side, health 16 over a 2 gap
# and a 12 cast bar, name and level 2 above the bar, a 5-unit glow on the target, the others at 0.6 alpha.
PLATE_W, PLATE_HEALTH, PLATE_CAST, PLATE_GAP, PLATE_DIMMED = 166, 16, 12, 2, 0.6
HOSTILE, ROGUE = (1.0, 0.0, 0.0), (1.0, 0.96, 0.41)
FAIR, EASY = (1.0, 0.82, 0.0), (0.25, 0.75, 0.25)
FIREBALL, REND, SUNDER = 135812, 132155, 132363
# A level 15 warrior in Westfall, targeting a Pillager casting Fireball: (name, level, level colour, health colour,
# health, target, (spell, icon, progress) or None, [(icon, stacks, remaining)]).
PLATES = [
    (
        "Defias Pillager",
        15,
        FAIR,
        HOSTILE,
        0.62,
        True,
        ("Fireball", FIREBALL, 0.55),
        [(REND, None, 0.4), (SUNDER, 3, 0.8)],
    ),
    ("Defias Tide Crawler", 12, EASY, HOSTILE, 1.0, False, None, []),
    ("Grimtusk", 16, FAIR, ROGUE, 0.45, False, None, []),
]
PLATE_POSITIONS = [(40, 60), (270, 140), (-150, 150)]


def spell_icon(ui, canvas, fdid, x, y, size, crop=0.08):
    image = ui.texture(fdid)
    w, h = image.size
    canvas.draw(
        image.crop((round(crop * w), round(crop * h), round((1 - crop) * w), round((1 - crop) * h))), x, y, size, size
    )


def nameplate(ui, name, level, level_colour, colour, health, target, cast, debuffs):
    """One nameplate as Nameplates.lua lays out Blizzard's, with the Health Percent option on."""
    c = ui.canvas(240, 120)
    x, w = 37, PLATE_W
    cast_y = 110 - PLATE_CAST
    y = cast_y - PLATE_GAP - PLATE_HEALTH
    # Retail's bar art as its default style lays it out: the trough 2 left, 3 above, 6 right and 6 below the bar,
    # and the target outline 1 outside the trough's top left and 3 inside its bottom right.
    c.draw(ui.atlas("UI-HUD-CoolDownManager-Bar-BG"), x - 2, y - 3, w + 8, PLATE_HEALTH + 9)
    c.draw(ui.atlas("UI-HUD-CoolDownManager-Bar"), x, y, w * health, PLATE_HEALTH, color=(*colour, 1))
    if target:
        c.draw(ui.atlas("UI-HUD-Nameplates-Selected"), x - 3, y - 4, w + 6, PLATE_HEALTH + 7)
    c.text(
        x,
        y,
        f"{round(health * 100)}%",
        Font(FRIZQT, 11, (1, 1, 1), None, True),
        box_height=PLATE_HEALTH,
        justify="RIGHT",
        width=w - 4,
    )

    # The full name centred above the bar, and Blizzard's 28-wide level frame, without its box, 4 into its end.
    name_y = y - 4 - 14
    font = Font(FRIZQT, 14, (1, 1, 1), (1, -1))
    name_w = c.text_width(name, font)
    name_x = x + (w - name_w) / 2
    c.text(name_x, name_y, name, font)
    c.text(
        name_x + name_w - 4,
        name_y,
        str(level),
        Font(FRIZQT, 10, level_colour, None, True),
        box_height=14,
        justify="CENTER",
        width=28,
    )

    # Blizzard's own debuff tiles, untouched: 25 square, cooldown-manager mask and frame, stacks bottom right.
    for i, (fdid, count, remaining) in enumerate(debuffs):
        tx, ty = x + i * 25, name_y - 25
        tile = ui.canvas(25, 25)
        spell_icon(ui, tile, fdid, 0, 0, 25, crop=0)
        tile.fill(0, 0, 25, 25 * (1 - remaining), (0, 0, 0, 0.5))
        tile.mask(ui.atlas("UI-HUD-CoolDownManager-Mask").image, 0, 0, 25, 25)
        c.paste(tile, tx, ty)
        c.draw(ui.atlas("UI-HUD-CoolDownManager-IconOverlay"), tx - 6, ty - 5, 37, 35)
        if count:
            c.text(tx + 13, ty + 14, str(count), Font(ARIALN, 12, (1, 1, 1), None, True), justify="RIGHT", width=12)

    if cast:
        spell, fdid, progress = cast
        c.draw(ui.atlas("ui-castingbar-background"), x + 1, cast_y, w - 2, PLATE_CAST)
        c.draw(ui.atlas("ui-castingbar-filling-standard"), x, cast_y, w * progress, PLATE_CAST)
        c.draw(ui.atlas("ui-castingbar-pip"), x + w * progress - 2, cast_y, 4, PLATE_CAST)
        spell_icon(ui, c, fdid, x, cast_y, PLATE_CAST)
        c.text(x + PLATE_CAST + 3, cast_y, spell, Font(FRIZQT, 10, (1, 1, 1), None, True), box_height=PLATE_CAST)
    if not target:
        c.image.putalpha(c.image.getchannel("A").point(lambda a: round(a * PLATE_DIMMED)))
    return c


def nameplates(ui):
    layers = [(nameplate(ui, *plate), px, py) for plate, (px, py) in zip(PLATES, PLATE_POSITIONS, strict=True)]
    scene(ui, layers, MARGIN).save(OUT / "nameplates.png")


def main():
    ui = Ui(scale=2)
    gear(ui)
    menu(ui)
    exploration(ui)
    zone_levels(ui)
    dungeon_entrances(ui)
    junk(ui)
    campsite(ui)
    campfire_buff(ui)
    editmode(ui)
    nameplates(ui)


if __name__ == "__main__":
    main()
