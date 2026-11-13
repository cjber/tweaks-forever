# Changelog

What changed in each release, in the terms a player would notice. Dates are UTC.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). The entries are prose rather than bare
Added/Fixed lists.

Each version's entry is also its release notes on GitHub, CurseForge and Wago. Older entries are kept
verbatim rather than rewritten as the addon moves. API changes other addons' authors need go under an
optional `### For addon authors` subsection after a version's player bullets.

## [Unreleased]

- **Chat options, all off until you turn them on.** Short channel names ([2. Trade - City] reads [Trade], [Guild] reads [G]), class colours with the level beside the name when the game knows it, item icons before item links, identical repeats folded into a grey x2 or x3, a chat icon and your name in gold when someone mentions you, and clickable web links that open a copy box. Each is its own switch under Chat, so you can take one without the others.
- **Your chat survives a reload.** The last 200 lines of each docked chat window come back above a Before your /reload line, saved for that character only and never for a line the game keeps secret. The Chat page also opens the game's own Chat Timestamps setting.
- **Whisper tabs and a player card.** Each person who whispers you gets the game's own docked tab, with a count of whispers you have not read yet and a grey line saying when you last grouped with them. Hovering a player's name in chat shows what the game states exactly: level, race and class when it knows them, guild and zone from your own lists, your last group together and your whisper count. Nothing is sent to other players, and every switch is off until you turn it on.
- **Link an item from your bags while you type.** Typing [ and a few letters in any chat box lists the items in your bags whose name contains those letters, up to eight, each with its icon and quality colour. Up and Down or Tab choose one, Enter puts in the item's real link and sends the line, a click puts it in so you can keep typing. The list is built when your bags change, not on every keystroke.

## [2.6.12] - 2026-11-12

<!-- forever-core-sync -->

- Ships with the same shared code as your other Forever addons, so they keep working together.

## [2.6.11] - 2026-11-12

<!-- forever-core-sync -->

- Ships with the same shared code as your other Forever addons, so they keep working together.

## [2.6.10] - 2026-11-12

<!-- forever-core-sync -->

- Ships with the same shared code as your other Forever addons, so they keep working together.

## [2.6.9] - 2026-11-12

<!-- forever-core-sync -->

- Ships with the same shared code as your other Forever addons, so they keep working together.

## [2.6.8] - 2026-11-11

<!-- forever-core-sync -->

- Ships with the same shared code as your other Forever addons, so they keep working together.

## [2.6.7] - 2026-11-11

- **The players who helped are on the Thanks page.** Settings, Forever addons, Thanks lists everyone whose report or idea shipped in Tweaks Forever, ranked by how much they gave. (#498)

## [2.6.6] - 2026-11-11

<!-- forever-core-sync -->

- Ships with the same shared code as your other Forever addons, so they keep working together.

## [2.6.5] - 2026-11-11

- **A window you moved opens in its place.** Windows moved with the Windows tab in Edit Mode could appear for a frame where the game would have put them, then jump to your spot. They are now in the right place from the first frame (#507).

## [2.6.4] - 2026-11-11

- **Tells you which addon to update.** If another Forever addon you have installed is older than this one and stops it starting, the message now names that addon, so you know exactly what to update.

## [2.6.3] - 2026-11-11

- **Works again after updating.** Updating to the last version could leave the addon switched off in the game's AddOns list with "ForeverCore: missing", because the update did not bring Forever Core with it. Forever Core now comes inside this addon's download again, from CurseForge, Wago or GitHub alike, so updating is all it takes (cjber/shortest-path-forever#731).

### For addon authors

- **`TweaksForever.API` is listed by `ForeverCore.APIKit.Addons()`.** On ForeverCore 1.3.2 or later the addon publishes its API table at load, so a suite-wide reader finds it and can subscribe through it. The API's own `version` and `minor` do not change (#490).

## [2.6.2] - 2026-11-11

- **Forever Core now installs alongside it.** Forever Core is on CurseForge, so the CurseForge app installs and updates it with this addon instead of the addon carrying its own copy. On Wago, install Forever Core from its own page.

## [2.6.1] - 2026-11-11

- **Game data now matches Forever build 1.60.1.70888.** The map overlays, zone level ranges, dungeon and raid entrances, class trainer spells, camp benefit texts and the quests Forever added are regenerated from the newer client build. Every row is the same as the previous build's, so nothing a player sees changes and only the build stamp in each file moves.

## [2.6.0] - 2026-11-11

<!-- discord-image: docs/screenshots/menu.png -->

- **Logging in with QuestieDB installed no longer stalls for a frame.** The quest-giver name index was built in one pass over every NPC as the world appeared, which could freeze the game for over 100 ms on a slower machine. It is now built a little at a time just after login, so the first moments in the world stay smooth (#411).

### For addon authors

- **`TweaksForever.API` is minor 2: it now hears changes and answers more of what it knows.** `Subscribe(callback)` hears `trainable`, `junk`, `rare` and `explored` on the frame after a change, once per burst. New reads answer the player's junk marks (`IsJunk`, `JunkMarks`), the best-selling quest reward (`BestReward`), a zone's level range (`ZoneLevels`), XP per hour and time to level (`XPRate`), the last rare alert (`LastRare`) and a zone's unexplored areas (`Unexplored`). Every read that answers with a table returns a fresh one, and each not-ready reason is in `docs/api.md`; version stays 3 (#425).

## [2.5.1] - 2026-11-10

- **Forever Core now comes in the same download.** This addon needs Forever Core, and until Forever Core has its own CurseForge page every Forever addon's download carries a copy of it, so the addon loads with nothing else to install.

### For addon authors

- **`TweaksForever.API` is minor 1: each read that has nothing to answer returns `nil, reason`.** `TrainableSpells()` answers `nil, "loading"` before login and in combat, and `DungeonEntrance(instanceID)` answers `nil, "none"` for an instance with no entrance. `nil` alone still means the same to existing callers. `docs/api.md` lists every published function, each read's reasons and the minor history; there is no `Subscribe()` yet (#425).

## [2.5.0] - 2026-11-10

- **Needs Forever Core.** The shared tracker column, bug report and leaderboards now come from one Forever Core addon that installs with it, so every Forever addon's tracker scale, lock and position stay in step. Your tracker settings carry over.
- **With the gamepad interface on, closing the options after browsing Tweaks Forever's page no longer makes the game refuse the next controller action and blame Tweaks Forever.** Tweaks' own rows are now handed to the game the way its own rows are, so backing out leaves nothing behind that blocks a button press (#446).
- **Nameplates no longer fade.** Plates other than your target now darken their bar slightly, as Blizzard's own nameplates do, instead of turning see-through, so far-off enemies and enemies behind terrain no longer become hard to see.
- **Quests no longer go missing for Forever's new Skyborne races.** QuestieDB puts races 95 and 96 in bits 32 and 33 of a quest's race mask, past what the client's 32-bit bit library holds, so an item's "Starts a quest" line and a minimap giver's quests were shown or hidden for the wrong race (cjber/tweaks-forever#443).
- **Skip single-option gossip works again.** Most NPCs open their chat window on purpose, and those were left for you to click even with only one thing to say. The lone option is taken now, and a flight master still opens its flight map (#448).

<!-- discord-image: docs/screenshots/nameplates.png -->

## [2.4.4] - 2026-11-10

- **Opening Tweaks Forever's options no longer shows a blocked action error naming this addon.** The Open buttons on the settings index, `/tweaks` and the addon compartment entry now ask the game to open its options instead of opening them themselves, so the client does not refuse the request and blame Tweaks Forever (cjber/forever-core#333).
- **With the gamepad interface on, backing out of Tweaks Forever's options no longer makes the game refuse a gamepad action and blame Tweaks Forever.** The choice rows still name their options, Modern, Retail and the rest, in their tooltip (#433).

## [2.4.3] - 2026-11-09

- **The Teach with Beast Training button works when clicked.** At a pet trainer, clicking it now opens Beast Training; before, it looked ready but did nothing (cjber/tweaks-forever#407).

## [2.4.2] - 2026-11-08

- **The Forever addons settings page works with a gamepad.** With the gamepad interface on, the page can be entered from the Options list, where the cursor used to stop at its entry (cjber/tweaks-forever#382).

## [2.4.1] - 2026-11-08

- **Choice settings become sliders with the gamepad interface on.** Tooltip style, Mark grouped gear with and Invite keyword are stepped with the D-pad instead of opening a menu, so opening one no longer blocks targeting with "Interface action failed because of an AddOn" (cjber/tweaks-forever#168).

## [2.4.0] - 2026-11-08

- **The report keeps errors from earlier sessions.** An error Tweaks caught before the last `/reload`, a blocked action or a Lua warning was forgotten when the client reloaded, so it could not be copied into a report once it was gone. The report now lists them under their own heading, with when each was first and last seen and the version, build and locale it happened on, and keeps the 50 most recent. It also carries Tweaks' recent log lines, the steps that led up to a bug, and `/forever debug` turns on detailed lines for the session (cjber/forever-core#204, cjber/forever-core#206).

## [2.3.3] - 2026-11-08

- **The Forever addons settings page no longer leaves a stray name behind for other addons to trip over.** Its check box came from a Blizzard template under an unnamed page, so the label landed on a global another addon or the game could read as its own. The page is named now (cjber/forever-core#208).
- **The coordinates bar steps aside for the game's own world map coordinates.** With either Player or Cursor coordinates on in the game's own settings, the bar hides so the map shows one set, and it returns when both are off. (cjber/tweaks-forever#371)

## [2.3.2] - 2026-11-07
- **Beast Training marks the ranks your pet already knows.** A rank your pet knows, or one it has replaced with a higher rank, is dimmed and says it is already known instead of showing a training point cost, so Growl Rank 1 no longer looks learnable above the rank your pet has. It is on by default under Interface, and the other trainers are untouched.

## [2.3.1] - 2026-11-07
- **Game data now matches Forever build 1.60.1.70862.** The map overlays, zone level ranges, dungeon and raid entrances, class trainer spells, camp benefit texts and the quests Forever added are regenerated from the new client build, so the levels, the entrances and the spells the windows show are the ones this build has.

## [2.3.0] - 2026-11-06
- **A pet trainer says what your pet hasn't learned.** At a pet trainer, a short note names the abilities you know that your current pet lacks, with a **Teach with Beast Training** button that opens Beast Training. It also says when the trainer's filter hides the ranks you already know, which can leave the list looking empty. Nothing changes in Beast Training itself, and the button waits until combat ends.
- **Daily and repeatable quest markers come from the game's map.** Questie's daily quests and repeatable hand-ins on the map and minimap now use the client's own recurring quest symbols, so they read like every other quest marker there.
- **The grouped-gear border no longer glows.** A group border still splits the quality border into the group colours, without the bags' new-item glow behind it, so a grouped item no longer looks like one you just picked up.

## [2.2.2] - 2026-11-06
- **The tooltip health and power bars draw the game's cooldown bar at its own height.** They no longer squash a taller progress bar into the tooltip, so the bar is the shape the game draws it at, only as wide as the tooltip makes it.

## [2.2.1] - 2026-11-06
- **The tooltip health bar and the reagent slots use the game's current art.** The bar under a unit's tooltip now comes from the same atlas as the game's own progress bars, and the green reagent slots in the combined bag use the client's bag slot art, so neither draws the pre-Legion chrome the client still ships.

## [2.2.0] - 2026-11-06
- **Quest XP shows on the experience bar.** Turn it on under Interface to see what your quest log is worth: quests ready to hand in from where your bar is now, and the rest of the log fainter after them. Point at the bar and its tooltip adds both totals and the level they would reach. Off by default.
- **Pet abilities you haven't learned show before a trainer visit.** The spellbook's Pet tab now lists the abilities your current pet's family can learn, greyed out after the ones it knows, with each rank's level and training point cost in its tooltip from your first login. Visiting a pet trainer still brings the server's own list and prices up to date.
- **The unspent talent glow shows your points again.** The reminder reads them the way the game's own talent window does, so the talents button glows as soon as a point waits to be spent instead of staying dark.

## [2.1.1] - 2026-11-06
- **The unspent talent reminder is a glow only.** The reminder no longer writes a line in chat at login and after each level-up, where it was lost among login spam. The soft glow over the talents button still shows while talent or pet training points wait to be spent, and clears as they are spent. Nothing in combat.

## [2.1.0] - 2026-11-06
- **Pet abilities you haven't learned show on the spellbook's Pet tab.** After a visit to a pet trainer, the abilities it can teach appear greyed out after the ones your pet knows, ready ones first, with each row's level and training point cost in its tooltip.
- **A reminder when talent or pet training points are unspent.** One chat line at login and after each level-up, and a soft glow over the talents button until they are spent. Nothing in combat. It is on by default under Interface.

## [2.0.2] - 2026-11-05
- **The reagent bag's slots keep their green background.** With Combine Bags on, opening all bags no longer logs a Lua error about a missing slot background template, and the reagent slots at the bottom of the combined bag keep the green tint that sets them apart.

## [2.0.1] - 2026-11-05
- **Suite tooling stays in step with Forever Core.** The vendored shared-file check knows about the new tracker header menu spec. Nothing a player sees changes.
- **The Abandon quests button has a place of its own.** The quest list now makes room for it below the last row, so it no longer covers the bottom quest's objective text and every quest in the log stays readable.

## [2.0.0] - 2026-11-05

- **The Forever addons settings page ends with a Ko-fi link.** If the addons help you, its Copy link button shows the address, ready to paste into your browser. Nothing is locked behind it, and it shows nowhere else.
- **Spell reach under nameplates is gone.** The range icons on enemy nameplates, their spell picker and their settings are removed. A saved choice from an earlier version is simply ignored, and the other nameplate options are unchanged.

## [1.0.18] - 2026-11-05

- **The release packager moves to its newest action.** The workflow that packages each release uses the newest version of the packager action, so the zip that ships to CurseForge, Wago and GitHub is built by the current tool. Nothing a player sees changes.

## [1.0.17] - 2026-11-05

- **Suite tooling stays in step with Forever Core.** The vendored menu-scroll check and the workflow that runs it pick up Forever Core's newest rules, and the unused dropdown helper is gone from the shared settings page. Nothing a player sees changes.

## [1.0.16] - 2026-11-05

- **The settings page opens without an error.** Its title asked the game for a font Forever does not have, which logged a Lua error each time the page was built; it now uses the font the game's own settings pages title with.
- **The retired merge bot's workflow is gone.** The MergeLoop workflow, its config and its agent skill were removed from the repo, so nothing here waits on a bot that no longer runs. Nothing a player sees changes.

## [1.0.15] - 2026-11-05

- **The unit tooltip's health bar keeps its width.** A creature with a short name, such as a deer, no longer squeezes the tooltip down until the health bar and its percentage barely fit: the tooltip stays as wide as the game makes any tooltip with a bar.

## [1.0.14] - 2026-11-05

- **Melee icons under nameplates turn red out of reach.** Raptor Strike, Heroic Strike, Maul and the other melee attacks in Spell reach under nameplates now go red, faded or hidden when the enemy is beyond melee reach, in and out of combat. The game's own range check for these attacks never says they are out of reach, so a short distance check decides instead.

## [1.0.13] - 2026-11-04

- **Game data now names the 1.60.1.70790 build.** Camp benefits, class spells, dungeon entrances, Forever quests, map overlays and zone levels are regenerated from the new Forever client build. The regenerated values match the previous build, so nothing a player sees changes.

## [1.0.12] - 2026-11-04

- **Moving through Tweaks Forever's settings with a gamepad no longer runs Tweaks code.** A row that can never show a "already does this" or "needs" note now carries its tooltip as plain text, so the controller's cursor landing on a dropdown or slider row no longer runs our code just before the game sets up that row's button prompts. That was one way for the game to block its target selection afterwards, which players reported as a crash after backing out of the settings with a gamepad. Mouse and keyboard tooltips read the same as before.

## [1.0.11] - 2026-11-04

- **A waypoint to the rare in one click.** With Rare alerts on, the rare's name in the alert line is a link: click it to set the game's waypoint on the rare's map marker, or a Shortest Path Forever journey when that addon is loaded. A key you bind under Key Bindings > AddOns, which a gamepad button can take too, does the same for the last rare found. A rare with no map marker is pinned where you stood when its nameplate appeared, which is close by.

## [1.0.10] - 2026-11-04

- **A warning before you pull aggro.** In a group, a chat line tells you when your threat on your target has passed the tank's, so you can stop before the mob turns on you. It warns once, then again only after you drop back below the tank or change target. Turn it off under Interface in Tweaks' settings; nameplates coloured by threat are the game's own Nameplates option.

## [1.0.9] - 2026-11-04

- **Bug reports keep distinct errors apart.** The report groups caught errors on their full text rather than the shortened text it shows, so two errors that differ only past the display limit are listed separately. The BugGrabber section's heading now appears only when it has an error to add, so a report with nothing from BugGrabber no longer carries an empty heading.

## [1.0.8] - 2026-11-04

- **The data now names the 1.60.1.70755 build.** Zone level ranges, camp benefits, dungeon and raid entrances, class trainer spells, world map overlays and Forever's added quests are regenerated from the new client build. The regenerated values match the previous build, so nothing a player sees moves and only the build stamp in each file changes.

## [1.0.7] - 2026-11-04

- **Repeated errors stay distinct in reports.** Tweaks now keeps the full error text when grouping caught errors, so messages that only differ after the display limit are not merged, and BugGrabber entries already captured by Tweaks are omitted from the report.

## [1.0.6] - 2026-11-04

- **Screenshot art keeps its reviewed build.** The renderer records its UI-art pin independently of shared tooling updates, and changing it requires fresh screenshots.

## [1.0.5] - 2026-11-03

- **Buttons and dialogs keep the Forever look.** The shared asset checker now rejects legacy dialog templates and backdrop globals in runtime UI and in the screenshot renderers, not only direct texture references, so the old chrome cannot creep back in through a helper. Adopted from Forever Core.

## [1.0.4] - 2026-11-03

- **Controls use the Forever asset set.** Buttons use the native gold-bordered family, and CI rejects legacy loose chrome in runtime UI and screenshot renderers.

## [1.0.3] - 2026-11-03

- **Tweaks step aside for addons already doing the same job.** Repair, guild repair, grey selling, rare alerts, bag-button marks and tooltip restyling now switch themselves off when Scrap, Titan Panel, RareScanner, SilverDragon, Leatrix Plus, Dominos or a bag replacement is loaded with its own option on, so the same job never runs twice.

## [1.0.2] - 2026-11-03

- **Distance labels use the units the game measures.** Quest and campfire distances no longer label yards as metres or kilometres in German, Spanish, French, Portuguese, Korean or Russian.
- **Dungeon floor titles follow your client language.** The floor picker uses the client's dungeon names and translated wing labels, with the generated English titles as a fallback.

## [1.0.1] - 2026-11-03

- **The class trainer lists match the 1.60.1.70753 build.** Six spells this build no longer teaches are gone from the trainer lists, one trainer entry now names the spell it needs first, and the camp, dungeon, quest and zone-level data carry the new build's stamp. Nothing you already have changes.

## [1.0.0] - 2026-11-02

- **The first stable release, ready for the WoW: Forever launch.** Tweaks Forever 1.0 works as 0.17.2 did: every
  tweak and its default are unchanged. The version number now marks the addon as ready for everyday play, and the
  chat line after the update says so in every shipped language.

## [0.17.2] - 2026-11-02

- **Dire Maul's floors are named apart.** The floor picker, heading and map tooltip printed three identical
  "Capital Gardens" buttons and two "Warpwood Quarter" ones; a repeated floor name is now numbered in floor
  order, so the six buttons read distinctly.
- **Translations for the newest lines.** The `/tw issue` bug report and feature request lines now read in all nine
  languages instead of falling back to English.

## [0.17.1] - 2026-11-02

- **Entrance tooltips say what a click will do.** In combat a dungeon entrance no longer promises its map, since the click
  travels there instead, and on an entrance with no map the Shortest Path Forever tip says a plain click plans the way.
- **Translation fixes.** The German, Spanish, French and Portuguese descriptions of the entrance setting read as one
  sentence again.

## [0.17.0] - 2026-11-01

- **Click a dungeon entrance to see its map.** A left click on a dungeon or raid entrance now opens the client's painted parchment map, with every floor behind that entrance, and Back to map returns to the zone. Shift-click travels there, as a plain click used to.
- **Raids have painted maps too.** Molten Core, Onyxia's Lair, Blackwing Lair, Zul'Gurub and both Ahn'Qiraj raids now open on their parchment map when you are inside, the same as dungeons.
- Features that Naowh Forever's QoL module also does step aside while its matching switch is on: quest and gossip automation, faster auto loot, loot confirmations, repairs, quiet errors, the XP rate, unexplored areas and zone levels. With its junk selling on, only your marked non-grey items are sold here.

## [0.16.4] - 2026-10-30

- **Game data re-pinned to client build 1.60.1.70707.** Camp, class-spell, dungeon, overlay, quest and zone-level tables are read against the newer Forever build; regenerating against it produces no player-visible change.

## [0.16.3] - 2026-10-28

- **Game data re-pinned to client build 1.60.1.70685.** Camp, class-spell, dungeon, overlay, quest and zone-level tables are read against the newer Forever build; regenerating against it produces no player-visible change.

## [0.16.2] - 2026-10-28

- **Camp, class-spell, dungeon, overlay, zone-level and Forever-quest data re-pinned to client build 1.60.1.70658.** The generators now read and record the newer Forever build from wago.tools. Regenerating against this build produces no change to the bundled rows, so nothing a player sees changes.

## [0.16.1] - 2026-10-27

- **Camp, class-spell, dungeon, overlay, zone-level and Forever-quest data regenerated for client build 1.60.1.70630.** The generators now read the newest Forever build from wago.tools' `wowf` product as well as `wow_classic_beta`. wago lists 1.60.1.70630 only under `wowf`, so the daily refresh had been reporting itself already current and never regenerated; the bundled data had been on the previous build since 2026-10-21.

## [0.16.0] - 2026-10-26

- **Dungeon maps use the client's own painted floors.** The world map now draws the native four-by-three tiles with built-in area and boss labels, with no Atlas dependency or separate legend.

## [0.15.8] - 2026-10-26

- **The addon now ships the suite's shared settings-page code.** Forever Core's settings-page chrome (`UI/SettingsPage.lua`) and its spec are vendored byte for byte so the suite's shared-code drift gate covers this addon; Tweaks keeps drawing its own settings page, so nothing changes in game.

## [0.15.7] - 2026-10-24

- The report keeps the same error details, now captured by Forever Core alongside the other shared report code.

## [0.15.6] - 2026-10-24

- **Report and issue text selects when focused.** Ctrl+C now copies the full report or issue link from either text box.

## [0.15.5] - 2026-10-23

- **The Forever addons link box selects its address without a Lua error.** Focusing the read-only box handed the client's own `isUserInput` flag to `HighlightText` as its start argument, so it raised *bad argument #2 to '?' (outside of expected range -2147483648 to 2147483647)* and left the address unselected. It now selects the whole address the way the game asks, from the shared link box the Forever addons all carry (#269).

## [0.15.4] - 2026-10-23

- **Report a bug or request a feature from the game.** `/tw issue` (also `/tw bug` and `/tw feature`) opens a composer: write what went wrong, pick Bug or Feature request, and the window hands you a ready-made GitHub issue link, selected so Ctrl+C and a paste opens the new issue with your words and the addon's system report already filled in. Copy report still puts the same text in your hands for Discord.

## [0.15.3] - 2026-10-23

- **Data checked against Forever 1.60.1.70532.** The bundled map overlays, camp benefits, zone levels, dungeon entrances, class trainer spells and Forever quests are unchanged apart from their build pin.

## [0.15.2] - 2026-10-21

- **Camp benefit names and effects are now in your language.** On a translated client the camp tooltip and the "camp benefit gained" line used to read English, because they came only from a table with nothing but English in it. Names now come from the game's own spell names, and effects from the client's spell text where it has any; the bundled per-language table fills in the auras the client leaves empty, and English keeps the wording it had. Where the client is missing an API the lines fall back to the bundled text rather than going blank. ([#210](https://github.com/cjber/tweaks-forever/issues/210))

## [0.15.1] - 2026-10-19

- **Questie's icon size sliders now move the native quest map icons too.** With Questie's native quest map icons on, changing its icon size sliders left Tweaks' pins at their own size. They now follow the sliders, so the map reads as one set of icons. Thanks to Mouchoir for the fix.

## [0.15.0] - 2026-10-18

- **Gamepad interface: the maps are only read.** Instance entrances, the unexplored-area tint, the dungeon interior and the coordinates bar are now drawn on frames of Tweaks' own over the world map and the zone map, so the game's maps no longer hold any of the addon's pins or data. With the gamepad interface on, the map walks its own pins from secure code every frame, and an addon's pins in that walk are a likely cause of the crash some controller players reported. Entrances work as before: their tooltip, a mouse click to travel there, right-click to zoom out, and stepping aside for a flight master or another Forever addon's marker. Under the gamepad interface, an entrance under the map cursor shows its tooltip; travelling there still takes a mouse click. Thanks to the CurseForge player who reported it, and to Polestar for the idea.

### For addon authors

- **`ForeverMapMarkers`.** The entrance pins aren't the map's own any more, so `WorldMapFrame:EnumeratePinsByTemplate` no longer finds them. `ForeverMapMarkers.TweaksForever(WorldMapFrame)` returns the shown entrances as `{x, y, kind = "entrance"}` map fractions on the map being viewed, and Tweaks reads the other Forever addons' markers the same way.

## [0.14.1] - 2026-10-17

- **Data checked against Forever 1.60.1.70450.** Two more quests are known as added in Forever. Camp benefits, class trainer spells, dungeon entrances, map overlays and zone levels are unchanged.

## [0.14.0] - 2026-10-16

- **In your language.** Tweaks Forever is now in German, French, Spanish (Spain and Latin America), Korean, Brazilian Portuguese, Russian, and Simplified and Traditional Chinese, using the game's own words for settings such as Auto Loot, Combine Bags and Max Camera Distance. These are machine translated; corrections are welcome through the [translation issue form](https://github.com/cjber/tweaks-forever/issues/new?template=translation.yml). There's no Italian, because the WoW: Forever client has none.
- **Buttons fit their labels.** Train all, the Abandon quests buttons and the dungeon map's Back to map and Dungeon map buttons widen when a translated label is longer than the English.
- **Camp benefits are still in English.** Their names and effects come from a table that only has English so far, so on a translated client a camp line mixes the two ([#210](https://github.com/cjber/tweaks-forever/issues/210)).

## [0.13.1] - 2026-10-16

- **No more Lua error at login.** A map marker update can arrive before Tweaks has read your settings, and Rare alerts then failed with "attempt to index field 'db'", even with Rare alerts off. Every feature now stays off until the settings are read, and Rare alerts then looks once for a rare already nearby. Thanks to Mouchoir for the report and fix.

## [0.13.0] - 2026-10-16

- **Map extras step aside for OpenMap.** With [OpenMap](https://www.curseforge.com/wow/addons/openmap) loaded, its coordinates, zone level ranges, unexplored areas and dungeon icons take over from Tweaks' own, each only while its matching option is on there. Change one of those options in OpenMap and Tweaks follows the next time you open its settings, or after a /reload. With OpenMap's unexplored areas set to Hide, Tweaks' blue tint can still run.
- **A Forever addons page in the settings.** Under Tweaks Forever, a new page lists my five Forever addons with what each does, whether you have it, and a Copy link button for its CurseForge page. *Suggest my other Forever addons* lives there now, replacing Suggest companion addons. If you had that off, it stays off.
- **A plainer dungeon entrance hint.** Without Shortest Path Forever, an entrance's tooltip now ends "With Shortest Path Forever, click to plan the way there." while *Suggest my other Forever addons* is on.
- **Credits.** The README now thanks the players who reported bugs, Forever Loot Sparkles, and Polestar, which inspired some features (no code was copied). THIRD_PARTY.md has the full list.

## [0.12.1] - 2026-10-16

- **The auction house item level column is gone.** It worked by writing into the game's own auction category list, which the auction house reads when it lays out search results. That can get buying blocked and blamed on Tweaks, so it isn't worth the risk. The game still shows each item's level after its name; you just can't sort by it.
- **Tweaks keeps out of the gamepad UI's way.** Backing out of the AddOns settings with a gamepad has been reported to break the game's interact button. With the gamepad UI on, Move and scale windows now stands down (windows open where the game puts them and Edit Mode has no Windows tab), and opening the settings no longer re-checks your other addons, so a change to one of them shows in Tweaks' settings after a /reload. If it still happens with only Tweaks enabled, say so on [issue #168](https://github.com/cjber/tweaks-forever/issues/168).
- **Data checked against Forever 1.60.1.70425.** Four more quests are known as added in Forever. Camp benefits, class trainer spells, dungeon entrances, map overlays and zone levels are unchanged.

## [0.12.0] - 2026-10-15

- **Coordinates on the world map.** Your position and the cursor's show along the bottom of the world map. Turn it off under Maps; it steps aside for Leatrix Maps, Mapster, Coordinates and Polestar when they show their own.
- **XP per hour on the experience bar.** Pointing at the experience bar adds your XP per hour over the last 15 minutes, the time to your next level at that pace, and about how many kills or quests that is.
- **The reward that sells for most is marked.** When a quest lets you choose a reward, a gold coin sits on the choice a merchant pays most for, stacks counted. Nothing is picked for you, and a tie marks none. Turn it off under Interface.
- **Quest progress on item and object tooltips.** With QuestieDB, a quest item shows the quest it counts for and your progress on its tooltip, as creatures already did, and so do objects you use or loot for a quest. An item that starts a quest you haven't done says "Starts a quest:" and names it.
- **Quest levels in quest dialogs.** With Show quest levels on, the quest greeting list and a quest's detail and reward titles show its level, such as [12], where the game knows it.
- **Keys for the nearest quest item and quest target.** Under Key Bindings > AddOns > Tweaks Forever you can bind one key to use your nearest quest's item, and another to target a creature your nearest unfinished quest still needs, a different one each press (needs QuestieDB).
- **Unexplored areas show on the zone map too.** With Reveal unexplored areas on, the small zone map (Shift+M) gets the same blue tint as the world map, and an area you discover loses its tint at once.
- **Rare alerts.** A new option, off until you turn it on, puts a chat line up and plays a map marker chime from the game's own sounds when a rare creature's nameplate or map marker appears near you, once per rare for ten minutes and never in combat.
- **Party invites by who sends them, and duels from friends.** New options, all off until you turn them on: accept party invites from your friends, Battle.net friends and guild (not while you are queued for a battleground), decline invites from anyone else, and let friends and guild still challenge you when duels are declined.
- **`/tweaks report` gives you something to paste into a bug report.** It opens a small window with the text already selected: your addon and game versions, your character, the settings you changed, which features are standing down for another addon, your other addons, and any errors Tweaks caught this session. Press Ctrl+C and paste it.
- **Hold Shift to skip repairs and junk selling at one merchant.** Holding Shift while a merchant opens skips Tweaks' repair (chat says what it would have cost) and its junk selling for that visit; the Sell All Junk button still works.
- **Junk sales pay for the repair.** If you arrive at a merchant without enough money to repair, the repair happens as soon as what you sell there, such as your junk, brings in enough.
- **Summons and resurrections are accepted more carefully.** A summon isn't accepted where the game won't let you teleport out, and one that arrives in a fight is accepted when it ends. A resurrection waits out the delay after dying again soon, and Shift leaves either one, or a battleground release, to you. Their popups now close only once the game has taken the answer, so one it refuses stays up.
- **Quest automation leaves the costly ones to you.** A quest that would flag you for PvP is no longer accepted for you, and a hand-in that costs gold is no longer paid without asking. A quest the game has already accepted for you is acknowledged instead of accepted again.
- **Polestar is respected like the other addons.** With Polestar loaded, auto repair, quest and gossip automation, summons, resurrections, battleground release, duel declines, faster auto loot, quiet errors, revealed maps, zone level ranges, and quest tooltips and nameplate icons (once its quest database has loaded) each stand down, named in the settings, while Polestar's own matching option is on, and follow that option as soon as you change it. While Polestar sells your greys, only your marked non-grey junk is sold here.
- **Faster auto loot asks for each item once.** When the game repeats its loot-ready signal for the same window, only items it hadn't asked for yet are taken.
- **Data checked against Forever 1.60.1.70374 and Classic Era 1.15.9.70003.** The bundled game data is unchanged.

## [0.11.5] - 2026-10-15

- **Data checked against Forever 1.60.1.70374.** The bundled game data is unchanged.

## [0.11.4] - 2026-10-13

- **Movement keys keep working in combat.** The Gear groups panel, the Spells to track list and the dungeon map's floor list pass every key except Escape to the game, in and out of combat, so leaving one open no longer stops you moving in a fight.

- **Spell reach icons after a reload.** Enemy nameplates already on screen when you reload get their icons straight away, not only plates that appear afterwards.

- **Instance entrances follow the setting at once.** Turning Instance entrances off or on updates an open world map straight away.

- **Guild names in player tooltips.** A guild whose name holds a race, such as Night Elf Lovers, stays in brackets as the guild, and the class joins the real level line, which is now found by the player's level as well as their race.

## [0.11.3] - 2026-10-13

- **Data checked against Forever 1.60.1.70338.** The bundled game data is unchanged.

## [0.11.2] - 2026-10-09

- **Data checked against Forever 1.60.1.70291.** One new Forever quest is included.

- **How the Forever addons work together.** The README and store page list each of the other Forever addons and what it adds when installed alongside this one.

## [0.11.1] - 2026-10-08

- **Shorter addon descriptions.** The README and store pages explain the options directly and keep the author and licence credits.

## [0.11.0] - 2026-10-07

- **Quest item sparkles.** An option keeps the game's own sparkle effect on lootable quest objects, using the same graphics settings as Forever Loot Sparkles. Off by default. It turns normal and raid outlines off while enabled, keeps sparkles through graphics preset changes, and restores your earlier settings when switched off. Removing the sparkles needs a full game restart. It steps aside when Forever Loot Sparkles is loaded.

## [0.10.1] - 2026-10-07

- **Data checked against Forever 1.60.1.70245.** The bundled game data is unchanged.

## [0.10.0] - 2026-10-06

- **Dungeon interior maps.** Inside a dungeon, the world map opens on the dungeon's own floor map and legend, with a button to pick the floor and a Back to map button to get the stock map back. It needs Atlas and its Classic WoW maps, and the setting says so while they are missing. On by default.

## [0.9.1] - 2026-10-05

- **Range icons wear the Classic button frame.** A small bevel and space between spells keep them clear beside nameplates.

- **Native quest map icons.** Turning the option off brings back Questie's whole icons, not a corner of each one, and a marker Questie reuses for a townsfolk icon draws it whole.

## [0.9.0] - 2026-10-05

- **Maximum camera zoom.** The camera pulls back further than the game's own Max Camera Distance setting allows. Off by default, and the value you had before comes back when you switch it off.

- **No screen glow.** Turns off the full screen glow effect. Off by default, and the value you had before comes back when you switch it off.

- **Train all button.** A button beside the class trainer's Train button buys every spell the trainer is offering that your gold covers, in one click. It buys nothing on its own, and its tooltip says why when nothing is available or you cannot pay for it all. Off by default.

- **Invite from whispers.** A whisper that is exactly the keyword you pick, **inv**, **invite** or **group**, invites its sender to your group when you can invite. Off by default.

- **Skip loot confirmations.** The game's warning when you roll Need or Disenchant on loot, and when you loot a Bind on Pickup item, is confirmed for you. Only the warnings your own clicks raise. Off by default.

- **Item level column in the auction house.** Weapons and armour on the Browse tab get a sortable iLvl column between Name and Available, with the item level no longer repeated after the name. On by default.

- **Spell reach under nameplates.** A small icon for each attack you track sits on every enemy nameplate, in full colour when that spell can reach the enemy and a solid red when it cannot, melee included, so you can see what reaches a mob before you pull it. It starts with your class's own attacks, one for each reach: a shaman sees a shock and Lightning Bolt, a hunter Raptor Strike and Auto Shot. A **Spells to track** list under the setting shows your known spells by icon and name and remembers your choices per character, specialisation and stance or form. The icon sits to the right of the health bar by default, clear of the level, and the setting chooses where it sits, its size, whether out of range icons are red, faded or hidden, and whether they show on every enemy or only your target. Off by default.
- **Grey junk uses the game's own Sell All Junk.** Automatic selling delegates grey items to the native bulk sale instead of stepping through bag slots. Manually marked non-grey items retain their 12-stack limit per merchant visit.

- **Tooltips can follow the cursor.** The game's own tooltips sit under the mouse instead of in the corner of the screen. Off by default, and a window that places its own tooltip, such as a bag item's, is left alone.

- **The Abandon quests button goes with the quest list.** It hides while a single quest's details are open on the world map, instead of showing over them.

## [0.8.0] - 2026-10-03

- **Class trainers are placed by Questie.** Addons that ask Tweaks Forever where your class trainers stand, such as Adventure Guide Forever, now get each trainer's name and place from your installed Questie, or its QuestieDB addon on its own, in your game's language. Without it they are told what to install, and everything else works as before.

- **Nearest quests first sorts as soon as distances are known.** Just after logging in, or after tracking a new quest, a farther quest could sit above a nearer one until you had walked 25 yards. The list now sorts again the moment a quest's distance appears or the tracked quests change.

## [0.7.8] - 2026-10-03

- **The gear menu opens on gear only.** Right-clicking cloth, food or any other item that cannot be worn opened the gear group menu. It now opens only for items that go in an equipment slot.

- **Nearest quests first copes with a hidden position.** Where the game withholds your position, the quest tracker sort could raise an error every second. It now waits until the position can be read.

- **New group no longer removes an item.** Typing the name of a gear group the item was already in took the item out of that group, and deleted the group when it was the last item. The item now stays in the group.

## [0.7.7] - 2026-10-03

- **New Forever quests are highlighted.** Quests added in the latest Forever update get the gold highlight in your quest log.

## [0.7.6] - 2026-10-02

- **Stop the blocked-action warning when opening the map in combat.** Dungeon and raid entrances no longer listen for the map toggle through the world map itself, which made the game blame Tweaks Forever and drop quest markers in combat.
- **Shorter setting names.** Setting names that were cut off with an ellipsis in the settings panel are shortened to fit, and each tooltip still gives the full detail.

## [0.7.5] - 2026-09-30

- **Show what's new after release updates.** Keep the development-version marker out of the packager's substitutions so release builds announce changes and remember the version once.

## [0.7.4] - 2026-09-30

- **Organise the source.** Group runtime modules by responsibility and update the manifest, tests and developer tools without changing client load order or behaviour.

## [0.7.3] - 2026-09-30

- **Development disclosure.** This release was developed with AI assistance. Changes were reviewed and checked with automated tests, linting and type checks; live verification remains ongoing.

- **Open gear groups without the client menu crash.** Ctrl+Right-click opens a stock panel owned by Tweaks, keeping group checks, equipment actions and colours outside the native menu path that asserted in Forever. Long lists scroll, and the panel reuses its controls.

## [0.7.2] - 2026-09-29

- **Other addons can ask where your class trainer is.** `TweaksForever.API` is now version 2: alongside the trainer spells you can learn and each dungeon's own entrance, `Trainers()` returns your class's trainers as `{npc, name, map, x, y}` — the NPC to visit and where it stands on the world map. It is baked from the game's own data, so it answers before login and in combat. Version 1's calls keep working for addons that check the version.

## [0.7.1] - 2026-09-28

- **Dungeon entrance pins wait for combat to end.** Map refreshes and overlap settling now avoid the protected pin manager during combat, then rebuild once combat ends.

## [0.7.0] - 2026-09-28

- **Move Adventure Guide in Edit Mode.** The Windows tab can preview, move, scale and reset Adventure Guide, including before you first open it. Placement follows your current layout and waits until combat ends. The guide keeps its normal-window or floating behavior.

## [0.6.6] - 2026-09-28

- **Auctionator compatibility survives updates.** The bundled Auction House tab library uses native panel visibility events instead of hooking Blizzard’s display-mode method. Auctionator loads it before its embedded copy.
- **Native tracker registration fails CI.** The shared taint check rejects the integration that exposed addon callbacks to Edit Mode layout.

## [0.6.5] - 2026-09-28

- **The Abandon quests button responds to clicks.** It now sits above the quest list's scroll area, which previously intercepted clicks before they reached the selection window.

## [0.6.4] - 2026-09-27

- **Stronger release checks.** Releases require the complete checks to pass on the exact published commit, including native UI hook and Lua coverage checks.

- **Questie markers match the game.** Map and minimap pins use stock quest symbols at readable sizes, preserving all locations, objectives and tooltips. Turn off Native quest map icons to restore Questie’s appearance.

- **Quest levels stay visible.** Native map quest tooltips and the tracker show levels, as do quest progress tooltips. Minimap giver tooltips include later quests with their required level.
- **Forever quests have a soft gold background.** Quests added since Classic Era are marked in the quest log and quest text.
- **Abandon several quests at once.** The quest log has a selection window with Select all, individual checkboxes and one confirmation for the batch.

## [0.6.3] - 2026-09-27

- **The tooltip health bar uses the game's own art.** Under Modern tooltips, the bar inside a unit's tooltip now has the retail game's bar texture on a darker track of the same colour, framed by Blizzard's own tooltip bar border, in place of the flat bar and thin grey outline.
- **The Before fishing setting says how to get your weapons back.** Its tooltip now says to Ctrl+Right-click one of them and pick Equip Before fishing, since the click only opens the group menu.
- **Nearest quests first does no work while it is off.** With the setting off, or the quest tracker hidden, it stops checking the tracker every frame.

## [0.6.2] - 2026-09-27

- **Quests on minimap givers stay off when QuestieDB's map data can't be read.** If QuestieDB's zone tables fail to load, the option is greyed out as if QuestieDB were missing, instead of placing givers from partial data, where one on a map QuestieDB leaves out could be picked.
- **The chat line after an update names this version's changes.** After updating to 0.6.1 it still gave 0.6.0's news.

## [0.6.1] - 2026-09-26

- **Nearest quests first sorts again.** The tracker now really lists your quests nearest first as you move. The game's own sort leaves quests you tracked yourself where they are, so it never moved them; quests on another continent stay below the rest.

- **Quest features name Questie.** The quest giver and quest progress settings now say they need Questie, or its QuestieDB addon on its own, since most players get QuestieDB with Questie.

- **The combined bag is the right height again.** With gear sections and the reagent bag both in it, the bag could open a section's height too tall, leaving an empty band above the first heading.

## [0.6.0] - 2026-09-25

- **Ready for translation.** Every setting, tooltip line and chat message can be translated, and anything not translated yet stays in English. Translations are welcome on GitHub.
- **What's new after an update.** The first time you log in after Tweaks Forever updates, one line in chat says what changed, such as "Tweaks Forever: updated to 0.6.0." and the headline. Nothing on a first install. Turn it off under Interface.
- **Dungeon entrances point you to Shortest Path Forever.** Without it, an entrance's tooltip ends with a grey line saying to install it for walked routes and boat times, or to enable it when it is installed but switched off. Turn these hints off with Suggest companion addons under Interface.

## [0.5.0] - 2026-09-25

- **`/tweaksforever` opens the settings too.** It does the same as `/tweaks`, for when you can't remember which short name an addon uses.
- **Other addons can ask where a dungeon entrance is.** The version 1 public API returns each instance's own entrance, even when the map combines several into one pin or entrance pins are off.
- **Hide macro names.** Macros on your action bars can show just their icon, without the name across the bottom. The game has no option for it. Off by default; turn it on under Interface, and it applies straight away.
- **Quest progress on tooltips.** Pointing at a creature you need for a quest, to kill or for an item it drops, adds the quest and your progress under its tooltip, as the retail game does, such as " - Mangy Wolf slain: 3/10", white until that objective is done and grey after. It needs [QuestieDB](https://github.com/Questie/QuestieDB), which works on its own: you don't need Questie itself. It stays out of the way while Questie's own tooltips are on. Turn it off under Interface.
- **Quest icons on nameplates.** A small gold quest icon sits beside the nameplate of each creature you still need for a quest, and goes once you have enough. It needs QuestieDB too, and stays out of the way while Questie's own nameplate icons are on. Turn it off under Interface.
- **No more "blocked from an action" warnings.** Opening the bank, searching the settings (for Discord, say) and a few other places could make the game say Tweaks Forever had been blocked from an action only available to the Blizzard UI, or throw a Lua error from the map or a tooltip. Tweaks Forever no longer hooks into or rewrites any of the game's own interface code, only its own frames and the game's events, so those are gone.
- **Quest options say when QuestieDB is missing.** Without QuestieDB, quest progress, quest icons on nameplates and quests on minimap givers are greyed out in the settings, and their tooltip says so.

## [0.4.1] - 2026-09-25

- **Updated for Forever build 1.60.1.70009.** The build changes none of the map overlays, dungeon entrances, camp benefits, zone levels or trainer spells the addon carries, so nothing looks different.

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

- **Campsites explain themselves.** Hovering a camp feature, such as a Camp Tent, Mana Well or Anvil, shows what sitting nearby gives you and whether you have it, with the time left; hovering a campfire shows how long your camp benefits last. Upgrades such as the Master Forge name the benefit of the feature they replace. Turn it off under Interface.

## [0.2.1] - 2026-09-23

- **Gear groups have a softer palette.** The defaults are now rose, teal, lavender and pink, still well clear of every item quality colour. Groups on an earlier default colour take one of the new ones; colours you picked yourself stay.
- **The Before fishing section has the fishing icon on its heading.**
- **Weapons go straight to Before fishing when you equip a pole.** They used to show briefly under their gear set's section before moving.

## [0.2.0] - 2026-09-23

- **Sections for grouped gear in the combined bag.** With Combine Bags on, each group's gear sits together at the top of the bag under a heading in the group's colour, and the bag grows to fit. An item in several groups goes under the first. Turn it off under Gear in the settings; separate bags keep items where they are.

## [0.1.3] - 2026-09-23

- **The grouped-gear border glows.** It lights up in the group's colour, the way the bags light up a new item.
- **Group colours no longer look like item quality.** The old defaults were close to Legendary orange and Rare blue; the new ones (crimson, aquamarine, chartreuse, pink and indigo) are chosen to stand apart from every quality colour. Groups still on an old default colour move to the new ones; colours you picked yourself stay.

## [0.1.2] - 2026-09-23

- **The grouped-gear border takes the place of the quality border.** It is drawn with the game's own item border in the group's colour, split side by side when an item is in several groups, instead of thin rings inside the slot.

## [0.1.1] - 2026-09-23

- **Grouped gear can have a coloured border.** Mark grouped gear with a ring inside the bag slot, one ring per group, as well as the strip or dots.
- **Click modes have clearer cursors.** A coin while marking junk and a cog while grouping gear.
- **Marking junk no longer throws a Lua error.** It happened when marking junk, or changing how grouped gear is marked, while the game kept an unused bag frame around.

## [0.1.0] - 2026-09-23

First release: quality-of-life automations that sit inside the game's own settings.

- **Settings live in the game's own Options.** They sit under Options → AddOns with a page per section, with `/tweaks` and the minimap's addon compartment as shortcuts. Features another addon already handles are greyed out with that addon named, and this is rechecked each time the settings open.
- **Quests, gossip, summons, resurrections, battleground release and duels can be automated.** Each is off until you turn it on. Hold Shift to skip quest and gossip automation for one conversation.
- **Auto loot is faster.** It takes everything as the loot window opens.
- **Gear repairs itself at a merchant.** It uses guild funds when the guild covers the cost, and says the amount in chat.
- **Any item can be marked as junk.** Alt+Right-click it in your bags. It gets the game's junk coin while a merchant is open, a tooltip line, and Sell All Junk sells it along with your greys.
- **Junk sells itself at a merchant.** Twelve stacks per visit, so the buyback tab can still undo it.
- **Zone maps show unexplored areas.** They are tinted blue so you can see what you haven't found yet.
- **Windows move and scale in Edit Mode.** A Windows tab on the Edit Mode panel shows the character sheet, quest log, vendors, bank, mailbox, trainers, auction house and other Blizzard windows so you can drag, snap and scale them like the rest of the UI. A window you haven't opened yet is previewed where the game will put it. Each Edit Mode layout keeps its own arrangement, and Reset puts a window back where Blizzard had it.
- **Combat is quieter.** The errors a spammed macro repeats, such as not ready yet, out of range, not enough mana or no target, no longer flash red text or speak. Full bags and other errors still show.
- **Fishing is easier.** With a pole equipped, double right-click the world to cast. A pole without a lure gets the best one in your bags that your skill allows, and you're warned when you log in, equip a pole or cast without one. Optionally, sound effects go to full and music and ambience go quiet while you fish, so the splash is easy to hear, and your volumes come back afterwards.
- **`/rl` reloads the interface.** One word instead of `/reload`.
- **Gear can be grouped.** Ctrl+Right-click a bag item to put it in a named group such as Healing or DPS, and equip a whole group from the same menu. Each group has its own colour, shown as a strip along the bottom of the bag slot and in the tooltip, for Equipment Manager sets too, and the weapons a fishing pole replaces are remembered so you can put them back on.
- **Bags have click modes as well as modifier keys.** Pick Mark junk or Group gear from a bag's portrait menu, then click bag items to mark them or open their gear menu, the way the merchant's repair mode works. Handy when your keyboard or window manager swallows Alt or Ctrl.
