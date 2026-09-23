# Changelog

What changed in each release, in the terms a player would notice. Dates are UTC.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). The entries are prose rather than bare
Added/Fixed lists. Each version's entry is also its release notes on GitHub, CurseForge and Wago.

## [Unreleased]

- **The reagent bag joins the combined bag.** With Combine Bags on, its slots sit at the bottom of the bag, tinted green under a thin rule, instead of in a small window beside it, and the backpack key opens and closes both. Clicking it on the bag bar still opens it on its own. Turn it off under Interface.
- **Resurrections from outside your group wait for you.** The addon can only tell whether a group member is in combat, so a resurrection from anyone else is no longer auto-accepted, and a battle resurrection from a stranger is yours to time.
- **Retail-style tooltips.** The beige border gives way to a thin grey one like retail's, on unit, item and comparison tooltips alike, and a unit's health bar sits inside the bottom of its tooltip in the unit's class or reaction colour, with its health as numbers. Turn it off under Interface.
- **Grey items always show the junk coin.** The game's gold coin marks greys in your bags all the time, not only while a merchant is open. Turn it off under Vendors.
- **Nearest quests first.** The quest tracker re-sorts as you move and shows how far away each quest is in small grey text. The quest whose area you're standing in reads "here" with a soft gold highlight. It stays out of the way while Questie's own tracker is on. Turn it off under Interface.

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
