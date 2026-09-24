I got tired of running a pile of small addons for things that feel like they should be in the default settings, so I put them in one. Everything is made to look like it came with the game: the options are a page in Options → AddOns, moving windows is a tab in Edit Mode, and the map uses retail's own dungeon icons.

If you already run Leatrix Plus, Questie, BlizzMove, Peddler, FishingBuddy or similar, the overlapping option greys out and names the addon that has it, so the two never fight. Anything that acts for you is off until you turn it on.

![The Eastern Kingdoms on the world map with a dungeon or raid icon at every entrance, and the cursor on Blackrock Mountain: its tooltip lists Blackrock Spire, Blackrock Depths, Molten Core and Blackwing Lair](https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/dungeons.png)

Every dungeon and raid entrance, with retail's icons. Blackrock Mountain lists all four.

![Three enemy nameplates: the targeted Defias Pillager outlined in white in retail's bronze-rimmed bar, its name centred above with level 15 in yellow after it and 62% inside the bar, two debuffs above and a Fireball cast in a slim bar below with the spell's icon inside; the other two faded back](https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/nameplates.png)

Nameplates in retail's own frame, with your target outlined and casts in a slim bar.

![Kalimdor on the world map with the cursor on Ashenvale: the label at the top reads Ashenvale (18-30), the range in yellow for a level 22 character](https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/zonelevels.png)

Zone level ranges on the world map, coloured like quest levels.

![A backpack with gear groups marked by coloured strips along the bottom of each slot, and a ring's tooltip ending Gear: DPS, Levelling in the groups' colours](https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/gear.png)

Gear groups mark each item with a strip in the group's colour.

![The Ctrl+Right-click menu on a ring: group checkboxes, New group, Equip DPS, Equip Levelling and Colour](https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/menu.png)

Ctrl+Right-click an item to group it, or to equip a whole group.

![Edit Mode's Windows tab: a checkbox for each of 21 Blizzard windows, the Character window's outline selected on the left, and a Character dialog with a Scale slider at 100% and Reset To Default Position](https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/editmode.png)

Move and scale Blizzard windows from a tab in Edit Mode.

![The Redridge Mountains map with its unexplored east revealed in a cool blue tint, beside the explored areas in full colour](https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/exploration.png)

Unexplored areas revealed in a blue tint, so you can still tell where you've been.

![A backpack with the game's gold junk coin on a ring and on stacks of cloth, meat and fins, and the ring's tooltip ending Marked as junk – Alt+Right-click to unmark](https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/junk.png)

The game's junk coin on greys and on anything you mark yourself.

![The Campfire Nearby buff tooltip: the game's description, then Campfire: about 35 yd ahead to your left, and the three benefits you have in green with their time left, such as First Aid Kit (52 Min): Stamina increased by 56](https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/camp.png)

Your Campfire Nearby buff says which way the fire is and what you have from it.

![A Mana Well tooltip in green: Sitting nearby: Restores 29 Mana every 5 seconds for 1 Hr, and Active: 48 Min](https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/campsite.png)

Camp tooltips say what sitting nearby gives you.

## Features

- **Automation**: accept and turn in quests (hold Shift to talk normally), skip single-option gossip and go straight to the flight map at a flight master, accept summons, accept resurrections from your group (never mid-combat), release in battlegrounds, decline duels. Faster auto loot is on by default.
- **Vendors**: repair automatically (from guild funds when allowed) and sell junk, up to 12 stacks so it all stays in buyback. Grey items show the game's junk coin all the time, and Alt+Right-click marks anything else as junk.
- **Gear groups**: Ctrl+Right-click a bag item to put it in a group such as Healing or DPS, and equip a whole group from the same menu. Each group has its own colour on the bag slot and in the tooltip, and the combined bag gathers each group under its own heading. Equipping a fishing pole remembers the weapons it replaced.
- **Maps**: every dungeon and raid entrance gets retail's icon, named when you point at it; click one to travel there with Shortest Path Forever, or with the game's own waypoint without it. Zones show their level range after the name, coloured like quest levels. Unexplored areas are revealed, tinted so explored ground still stands out.
- **Nameplates**: a taller bar with the name and level above it, your target outlined in white and your focus in gold, the rest faded back, and casts in a slim bar with the spell inside.
- **Tooltips**: a thin rounded border over charcoal, retail's navy or the game's own; player names in class colour with race and class on one line; the health bar inside, with numbers or a percentage.
- **Windows**: move and scale Blizzard windows from a Windows tab in Edit Mode, saved per layout.
- **Quests and camps**: the quest tracker sorts nearest first, with distances. With QuestieDB installed, pointing at a ! or ? on the minimap lists that giver's quests for you. Campsite features say what they give and whether you have it, and the Campfire Nearby buff lists your camp benefits and which way the fire is.
- **Spellbook and bags**: the spellbook shows spells you haven't learned yet, greyed out after your own, as retail does. The reagent bag joins the bottom of the combined bag.
- **Fishing**: double right-click the world with a pole to cast; with no lure on, the same double-click puts on the best one you can use.
- **Also**: quiet the errors a spammed macro repeats, and `/rl` reloads.

It doesn't touch your action bars or unit frames, and isn't trying to.

## Usage

Everything is under Options → AddOns → Tweaks Forever, with a page per section. `/tweaks` or the addon compartment on the minimap opens it.

Bug reports and ideas are welcome. Source code and issues: [github.com/cjber/tweaks-forever](https://github.com/cjber/tweaks-forever) (GPL-3.0).
