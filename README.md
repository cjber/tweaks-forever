# Tweaks Forever

Small quality-of-life automations for WoW Forever that feel like part of the default UI: settings under
**Options → AddOns → Tweaks Forever** (or `/tweaks`), one page per section with native checkboxes, and nothing
that needs its own window.

When another addon already does one of these jobs (Leatrix Plus, Questie, Legacy Here, Mapster and others),
that feature is greyed out and its tooltip names the addon, so the two never fight.

## Features

**Automation** (off until you turn them on)
- Accept and turn in quests. Hold Shift to talk normally; a quest with a choice of rewards is left to you.
- Skip gossip when an NPC offers only one thing.
- Accept summons and resurrections, but not in combat.
- Release your spirit in battlegrounds unless you can resurrect yourself.
- Decline duels.
- Faster auto loot (on by default).

**Vendors**
- Repair automatically, from guild funds when the guild allows it.
- Mark any bag item as junk with **Alt+Right-click**. Marked items show the game's own junk coin and a
  tooltip line, and the merchant's Sell All Junk button sells them too.
- Sell junk automatically: up to 12 stacks per visit, so everything sold is still in the buyback tab.

**Maps**
- Reveal unexplored areas on zone maps, tinted so explored ground still stands out.

**Fishing**
- Double right-click the world with a fishing pole equipped to cast Fishing. Not in combat or while mounted.
- If the pole has no lure, that double-click puts on the best lure in your bags your fishing skill allows.
- A warning when you equip a pole, or cast, without a lure.
- Louder splashes (off by default): full sound effects, no music or ambience while a pole is equipped.
  Your volumes come back when you unequip it.

**Interface**
- Move and scale Blizzard windows in **Edit Mode**. A Windows tab on the Edit Mode panel previews
  the character sheet, quest log, merchant, bank, mailbox, trainer, auction house and more, so you can drag
  them into place like any other part of the UI. Positions are saved per Edit Mode layout.
- Quiet the errors a spammed macro repeats (on by default): no red text or spoken "not ready yet", out of
  range, not enough mana, rage or energy, no target or wrong facing. Full bags and other errors still show.
- `/rl` reloads the interface.

## Install

Copy the `TweaksForever` folder into `_classic_beta_/Interface/AddOns`, or install from CurseForge or Wago.

## Development

```sh
luacheck . && stylua --check .
for spec in tests/*_spec.lua; do luajit "$spec"; done
python tools/gen_overlays.py   # regenerate Data/Overlays.lua from wago.tools
```
