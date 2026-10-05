Developed with AI assistance; changes are reviewed and checked with automated tests, linting and type checks.

I got tired of running a pile of small addons for things that feel like they should be in the default settings, so I put them in one. Everything is made to look like it came with the game: the options are a page in Options → AddOns, moving windows is a tab in Edit Mode, and the map uses retail's own dungeon icons.

If you already run Leatrix Plus, Questie, BlizzMove, Peddler, FishingBuddy or similar, the overlapping option greys out and names the addon that has it, so the two never fight. Repairs, selling junk and faster auto loot start on; everything else that acts for you is off until you turn it on.

![Dungeon entrances on the map, then enemy nameplates, then a backpack with a ring marked as junk](https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/demo.gif)

Dungeon entrances on the map, nameplates, and the junk coin in your bags.

![The Eastern Kingdoms map with an icon at every dungeon entrance and Blackrock Mountain's tooltip](https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/dungeons.png)

Every dungeon and raid entrance, with retail's icons. Blackrock Mountain lists all four.

![Three enemy nameplates, the target outlined in white with a quest icon and a Fireball cast](https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/nameplates.png)

Nameplates in retail's own frame, with your target outlined, casts in a slim bar and a quest icon on what you still need.

![An enemy's tooltip with a red health bar at 72% and a Horde shaman's with a blue bar at 412 / 520](https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/tooltips.png)

Unit tooltips with the health bar inside, in the retail game's own bar and frame.

![Kalimdor with the Ashenvale label reading Ashenvale (18-30)](https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/zonelevels.png)

Zone level ranges on the world map, coloured like quest levels.

![A backpack with coloured gear group strips under each slot](https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/gear.png)

Gear groups mark each item with a strip in the group's colour.

![Edit Mode's Windows tab and the Character window's Scale slider](https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/editmode.png)

Move and scale Blizzard windows from a tab in Edit Mode.

![A backpack with the game's gold junk coin on a ring and grey items](https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/junk.png)

The game's junk coin on greys and on anything you mark yourself.

![A Mana Well tooltip saying what sitting nearby restores](https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/campsite.png)

Camp tooltips say what sitting nearby gives you.

## Features

- **Automation**: accept and turn in quests (hold Shift to talk normally), skip single-option gossip, go straight to the flight map at a flight master, accept summons and group resurrections, release in battlegrounds, decline duels. Faster auto loot is on by default. Off until you turn it on: invite anyone who whispers a keyword you pick (inv, invite or group), and skip the game's warning when you roll Need or Disenchant and when you loot a Bind on Pickup item.
- **Vendors**: repair automatically (from guild funds when allowed) and sell junk so it all stays in buyback. Alt+Right-click marks anything as junk.
- **Gear groups**: Ctrl+Right-click a bag item to put it in a group such as Healing or DPS, then equip the whole group from the same menu.
- **Maps**: every dungeon and raid entrance gets retail's icon; click one to travel there. Zones show their level range, and unexplored areas are revealed in a blue tint.
- **Nameplates**: a taller bar with name and level above, your target outlined, and casts in a slim bar.
- **Spell reach** (off until you turn it on): a small icon for each attack you track on every enemy nameplate, full colour when the spell can reach and solid red when it cannot, melee included. Pick your spells from a list by icon and name, and choose where the icons sit, their size, the out of range look and whether they show on every enemy or only your target.
- **Tooltips**: a thin rounded border over charcoal, class-coloured player names, and the health bar inside.
- **Windows**: move and scale Blizzard windows from Edit Mode, saved per layout.
- **Camera and glow** (off until you turn it on): pull the camera back further than the game's own Max Camera Distance allows, and turn off the full screen glow effect.
- **Trainer**: a Train all button beside the class trainer's Train button buys every spell the trainer offers that your gold covers, in one click.
- **Quests and camps**: the quest tracker sorts nearest first. With [Questie](https://www.curseforge.com/wow/addons/questie) installed (or just its QuestieDB addon), a creature you need shows your progress in its tooltip and a quest icon by its nameplate. Camp features say what they give and whether you have it.
- **Spellbook and bags**: the spellbook shows spells you haven't learned yet, as retail does. The reagent bag joins the combined bag.
- **Fishing**: double right-click with a pole to cast, or to put on your best lure.
- **Also**: quiet the errors a spammed macro repeats, hide macro names, and `/rl` reloads.

Beyond hiding macro names if you ask, it leaves your action bars alone, and it adds nothing to your target frame or nameplates beyond the optional spell reach icons.

## Usage

Everything is under Options → AddOns → Tweaks Forever. `/tweaks`, `/tweaksforever` or the addon compartment on the minimap opens it.

Translations are welcome as a pull request, or pasted into an issue, on [GitHub](https://github.com/cjber/tweaks-forever/tree/main/Locales); anything not translated yet shows in English.

Works with [Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever): click a dungeon entrance on the map and it plans the way there.

Bug reports and ideas are welcome. Source code and issues: [github.com/cjber/tweaks-forever](https://github.com/cjber/tweaks-forever) (GPL-3.0).
