# Changelog

What changed in each release, in the terms a player would notice. Dates are UTC.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). The entries are prose rather than bare
Added/Fixed lists. Each version's entry is also its release notes on GitHub, CurseForge and Wago.

## [Unreleased]

- **`/tweaksforever` opens the settings too.** It does the same as `/tweaks`, for when you can't remember which short name an addon uses.
- **Other addons can ask where a dungeon entrance is.** The version 1 public API returns each instance's own entrance, even when the map combines several into one pin or entrance pins are off.
- **Hide macro names.** Macros on your action bars can show just their icon, without the name across the bottom. The game has no option for it. Off by default; turn it on under Interface, and it applies straight away.
- **Quest progress on tooltips.** Pointing at a creature you need for a quest, to kill or for an item it drops, adds the quest and your progress under its tooltip, as the retail game does, such as " - Mangy Wolf slain: 3/10", white until that objective is done and grey after. It needs [QuestieDB](https://github.com/Questie/QuestieDB), which works on its own: you don't need Questie itself. It stays out of the way while Questie's own tooltips are on. Turn it off under Interface.
- **Quest icons on nameplates.** A small gold quest icon sits beside the nameplate of each creature you still need for a quest, and goes once you have enough. It needs QuestieDB too, and stays out of the way while Questie's own nameplate icons are on. Turn it off under Interface.
- **No more "blocked from an action" warnings.** Opening the bank, searching the settings (for Discord, say) and a few other places could make the game say Tweaks Forever had been blocked from an action only available to the Blizzard UI, or throw a Lua error from the map or a tooltip. Tweaks Forever no longer hooks into or rewrites any of the game's own interface code, only its own frames and the game's events, so those are gone.
- **Quest options say when QuestieDB is missing.** Without QuestieDB, quest progress, quest icons on nameplates and quests on minimap givers are greyed out in the settings, and their tooltip says so.

## [0.4.1] - 2026-09-25

Updated for Forever build 1.60.1.70009. The build changes none of the map overlays, dungeon entrances, camp benefits, zone levels or trainer spells the addon carries, so nothing looks different.

## [0.4.0] - 2026-09-25

- **Camp benefits are announced.** Gaining a camp benefit names it at the top of the screen, in the game's yellow, with what it gives you, such as "Camp benefit gained: Fish Bowl (all stats increased by 8%)". The numbers are the ones your buff actually has. Each benefit shows once as you gain it, never for the ones you already had when you logged in, and one gained mid-fight waits for the fight to end. Turn it off under Interface.
- **Flight masters go straight to the flight map.** With gossip skipping on, talking to a flight master opens the flight map even when they offer more than flying. The addon knows the flight option by the taxi icon the game gives it, not its words, so it works in any language. Quests still come first, and holding Shift shows the gossip as before.
- **Quests on minimap givers.** With QuestieDB installed, pointing at a quest giver on the minimap lists the quests they have for you, such as "[15] Dry Times", coloured like quest levels, with the next few levels' in grey and the level they open at. Only quests you can take now show: not done, not in your log, for your race and class, with their earlier steps done. A giver you owe a turn-in lists the quests in your log they take back, with a gold ? once one is ready to hand in. The minimap only names a giver, so the addon picks the one of that name standing within sight of you and stays quiet when two could be meant. Turn it off under Interface.
- **Larger, clearer nameplates.** Enemy and friendly nameplates get a taller health bar in the retail game's own frame, with the full name centred above it and the level after the name, coloured by difficulty with a skull for ??. Your target is outlined in white and your focus in gold, and the other plates fade back while you have one. Casts show in a slim bar with the spell's icon and name inside it, grey with a shield when they can't be interrupted. Health as a percentage or number sits inside the bar when the game's Nameplates options show it. Friendly plates inside dungeons belong to the game and keep its look. On by default; turn it off under Interface, which takes effect after a reload.
- **Dungeon and raid entrances on the world map.** Every dungeon and raid entrance is marked on its zone map and on the continent with retail's icons, and pointing at one names it. Clicking one sets off for it: Shortest Path Forever plans the journey when you have it, and otherwise the game's own waypoint marks the entrance. Blackrock Mountain and the Gates of Ahn'Qiraj are one pin each that lists everything inside. Blizzard's map asks the dungeon journal for entrances, and Forever has no journal, so the map was empty. The map's own Show instance entrances filter hides them, and an entrance steps aside where a flight master or a Shortest Path Forever portal or dock already sits on it. Legacy Forever draws the same portal with its shield on the corner where a Legacy step is left there. Forever's new instances have no entrance in the game's data yet, so Dalaran, the Ruins of Lordaeron, the Hall of Thanes and the Wetlands excavation have no pin. Turn it off under Maps.
- **Camps say what they give.** Hovering your Campfire Nearby buff lists the camp benefits you have, in green with their time left, and which way the campfire is, such as "Campfire: about 35 yd ahead to your left", once you have lit it or sat by it. Hovering a campfire lists every benefit a camp can give, a camp feature's tooltip gives its effect ("Sitting nearby: Stamina increased by 8 for 1 Hr") instead of just the aura's name, and your Camp Benefits buff adds the benefits you haven't gained yet. A benefit you have shows the numbers your buff carries. The game sets them when you gain it and its data doesn't say how, so one you haven't gained names what it raises without a number ("Stamina increased") rather than one your buff would then contradict. Turn it off under Interface.
- **Zone level ranges on the world map.** Pointing at a zone on the world map adds its level range after the name, such as Darkshore (10-20), coloured like quest levels: grey and green are below you, yellow is your level, orange and red are above. Forever's map data carries no ranges, so the original zones show the original game's, and Zephras Isle and Riverglades show the span of their subzones' exploration levels. Cities and battlegrounds show none. Turn it off under Maps.
- **The reagent bag joins the combined bag.** With Combine Bags on, its slots sit at the bottom of the bag, tinted green under a thin rule, instead of in a small window beside it, and the backpack key opens and closes both. Clicking it on the bag bar still opens it on its own. Turn it off under Interface.
- **Resurrections from outside your group wait for you.** The addon can only tell whether a group member is in combat, so a resurrection from anyone else is no longer auto-accepted, and a battle resurrection from a stranger is yours to time.
- **Modern tooltips.** The beige border gives way to a thin grey one with rounded corners, flush with the tooltip's edge, on unit, item and comparison tooltips alike, over a neutral charcoal that keeps the text crisp over any scenery. Pick Retail under Tooltip style for the retail game's navy, or Forever to keep the game's own border. A player's name is in their class colour, with the guild in grey brackets, race and class on the level line and the faction in Alliance blue or Horde red. A unit's health bar sits inside the bottom of its tooltip in an outlined track, in class or reaction colour, with health in the game's outlined number font, as numbers for players and a percentage for others. A comparison tooltip's Equipped label moves inside its top in grey. On by default; turn it off under Interface.
- **Grey items always show the junk coin.** The game's gold coin marks greys in your bags all the time, not only while a merchant is open. Turn it off under Vendors.
- **Nearest quests first.** The quest tracker re-sorts as you move and shows how far away each quest is in small grey text. The quest whose area you're standing in reads "here" with a soft gold highlight. It stays out of the way while Questie's own tracker is on. Turn it off under Interface.
- **Future spells in the spellbook.** As in the retail game, each spellbook tab ends with the spells you haven't learned yet under a Future Spells heading, greyed out: the ones your trainer can teach you now glow and say "See your trainer", and the rest name the level they come at. Only each spell's next rank shows, and its tooltip gives the training cost. It works from your first login and in every client language: every class trainer's list is built in, and visiting yours brings its levels and prices up to date. Turn it off under Interface.
- **Other addons can ask what your trainer teaches.** The version 1 public API lists the spells your level allows that you haven't learned, with each one's level, cost and spellbook tab (its name in your client's language and an ID that is the same in every language), so an addon such as Adventure Guide Forever can plan a trainer visit. It answers whether or not Future Spells is on.

## [0.3.0] - 2026-09-23

Campsites explain themselves. Hovering a camp feature, such as a Camp Tent, Mana Well or Anvil, shows what sitting nearby gives you and whether you have it, with the time left; hovering a campfire shows how long your camp benefits last. Upgrades such as the Master Forge name the benefit of the feature they replace. Turn it off under Interface.

## [0.2.1] - 2026-09-23

- **A softer palette for gear groups:** rose, teal, lavender and pink, still well clear of every item quality colour. Groups on an earlier default colour take one of the new ones; colours you picked yourself stay.
- **The Before fishing section has the fishing icon** on its heading.
- **Fixed** equipping a fishing pole briefly showing its weapons under their gear set's section before moving them to Before fishing.

## [0.2.0] - 2026-09-23

- **Sections for grouped gear in the combined bag.** With Combine Bags on, each group's gear sits together at the top of the bag under a heading in the group's colour, and the bag grows to fit. An item in several groups goes under the first. Turn it off under Gear in the settings; separate bags keep items where they are.

## [0.1.3] - 2026-09-23

- **The grouped-gear border glows** in the group's colour, the way the bags light up a new item.
- **Group colours no longer look like item quality.** The old defaults were close to Legendary orange and Rare blue; the new ones (crimson, aquamarine, chartreuse, pink and indigo) are chosen to stand apart from every quality colour. Groups still on an old default colour move to the new ones; colours you picked yourself stay.

## [0.1.2] - 2026-09-23

- **The grouped-gear border takes the place of the quality border.** It is drawn with the game's own item border in the group's colour, split side by side when an item is in several groups, instead of thin rings inside the slot.

## [0.1.1] - 2026-09-23

- **A coloured border for grouped gear.** Mark grouped gear with a ring inside the bag slot, one ring per group, as well as the strip or dots.
- **Clearer click-mode cursors:** a coin while marking junk and a cog while grouping gear.
- **Fixed** a Lua error when marking junk or changing how grouped gear is marked while the game kept an unused bag frame around.

## [0.1.0] - 2026-09-23

First release: quality-of-life automations that sit inside the game's own settings.

- **Settings in the game's own style**, under Options → AddOns with a page per section, with `/tweaks` and the minimap's addon compartment as shortcuts. Features another addon already handles are greyed out with that addon named, and this is rechecked each time the settings open.
- **Quest, gossip, summon, resurrection, battleground release and duel automations**, all off until you turn them on. Hold Shift to skip quest and gossip automation for one conversation.
- **Faster auto loot** takes everything as the loot window opens.
- **Automatic repairs**, using guild funds when the guild covers the cost, with the amount in chat.
- **Mark any item as junk** with Alt+Right-click in your bags. It gets the game's junk coin while a merchant is open, a tooltip line, and Sell All Junk sells it along with your greys.
- **Automatic junk selling**, twelve stacks per visit so the buyback tab can still undo it.
- **Unexplored areas on zone maps**, tinted blue so you can see what you haven't found yet.
- **Move and scale windows in Edit Mode.** A Windows tab on the Edit Mode panel shows the character sheet, quest log, vendors, bank, mailbox, trainers, auction house and other Blizzard windows so you can drag, snap and scale them like the rest of the UI. A window you haven't opened yet is previewed where the game will put it. Each Edit Mode layout keeps its own arrangement, and Reset puts a window back where Blizzard had it.
- **Quieter combat.** The errors a spammed macro repeats, such as not ready yet, out of range, not enough mana or no target, no longer flash red text or speak. Full bags and other errors still show.
- **Easier fishing.** With a pole equipped, double right-click the world to cast. A pole without a lure gets the best one in your bags that your skill allows, and you're warned when you log in, equip a pole or cast without one. Optionally, sound effects go to full and music and ambience go quiet while you fish, so the splash is easy to hear, and your volumes come back afterwards.
- **`/rl` reloads the interface.**
- **Gear groups.** Ctrl+Right-click a bag item to put it in a named group such as Healing or DPS, and equip a whole group from the same menu. Each group has its own colour, shown as a strip along the bottom of the bag slot and in the tooltip, for Equipment Manager sets too, and the weapons a fishing pole replaces are remembered so you can put them back on.
- **Click modes instead of modifier keys.** Pick Mark junk or Group gear from a bag's portrait menu, then click bag items to mark them or open their gear menu, the way the merchant's repair mode works. Handy when your keyboard or window manager swallows Alt or Ctrl.
