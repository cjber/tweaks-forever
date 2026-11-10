# About the app

Tweaks Forever is a World of Warcraft: Forever addon written in Lua 5.1, with Python tooling for its
checks. The game cannot run here. What verifies a refactor is the repo's own checks: `stylua --check .`,
`luacheck .`, `tools/typecheck.sh` against the pinned client annotations, every `tests/*_spec.lua` under LuaJIT
(the specs stub the client API and load the files the TOC lists, in order), and `python3 tools/repo_rules.py`,
the rules no linter covers.

Sloppatrol does not read Lua yet, so its census and survey see nothing to propose. That is expected;
the checks here are what make a proposed change verifiable anyway, and they are the same commands the
repo runs before a pull request.

## Useful refactors in this tree

- A feature file that repeats a frame, tooltip or settings-page pattern another feature already has in
  `UI/`.
- A branch that duplicates a condition already computed a few lines up.
- A table that is built at load time but only read inside one function.

## Never

- Never draw on a map outside `Map/MapDraw.lua`, hook a Blizzard object method, or write a field on a
  Blizzard table: the game refuses it.
- Never edit `Data/` (generated), `Locales/` (translations), `types/` (pinned contracts) or
  `tools/forever_tools/` (vendored byte for byte from forever-core).
- Never start the game, Battle.net, Lutris or Wine. The headless client (forever-core's `wow-forever-addon/in-game.md`) tests the build linked into the game, not this checkout, so in-game checks belong to the agent that ships a change.
- Never leave the working tree with two changes at once: one refactor, one commit.

## Live roots

- `TweaksForever.toc`: the file list and load order. `Core/Core.lua` defines `ns.Feature`/`ns.On`/`ns.Init`
  before any feature file runs; declaration order sets the settings subpage order and the order `ns.Init`
  callbacks run at login. Never reorder.
- SavedVariables `TweaksForeverDB` (feature keys, `junk`, `windowLayouts`, `savedSounds`, `lastVersion`) and
  `TweaksForeverCharDB` (`groups`, `colours`, `beforeFishing`): persisted formats; keys are data.
- Feature `key`s are persisted and also form the setting variable `"TweaksForever_" .. key`, built only by
  Core's `ns.SettingVariable`; feature files take setting changes through `ns.OnSettingChanged(key, fn)`.
- `ns.On("<EVENT>")`, `hooksecurefunc("<Function>")` and `HookScript("<Script>")` name Blizzard events, functions
  and scripts as strings.
- `UI/Errors.lua` builds `_G["LE_GAME_ERR_" .. name]`; `UI/Frames.lua` resolves `_G[record.name]` and loads the
  listed load-on-demand addons.
- Slash commands: `SLASH_TWEAKSFOREVER1`, `SLASH_TWEAKSFOREVER_RELOAD1` with `SlashCmdList` entries.
- Global frame `TweaksForeverFishingButton`: the binding clicks it by name.
- `TweaksForever.API` (Core/API.lua, typed in `types/API.lua`): the public addon-to-addon interface other addons
  (Adventure Guide Forever) call; every field is public surface. `TweaksForever_OnAddonCompartmentClick` is named
  by the TOC's `AddonCompartmentFunc`.
- `ShortestPathForever.API` (Integrations/Navigate.lua) and QuestieDB (`ns.QuestieDB`, QuestGivers/QuestProgress): other addons'
  APIs read at runtime, the TOC's `OptionalDeps`.
- `ns.HookBagButtons` and `ns.IsBagActionClick` (Core/Core.lua): the one home for bag-slot button hooks and
  the remappable-click guard, used by Bags/Junk.lua and Bags/Gear.lua. The specs never run `ns.Init`, so a change here
  needs a stubbed load of Core + the feature file (hook-registration trace) to show behaviour is unchanged.
- `ns.Gear`, `ns.Fishing`, `ns.Frames`, `ns.Exploration`, `ns.Sections`, `ns.Reagents`, `ns.Camp`,
  `ns.ZoneLevels`, `ns.Entrances`, `ns.FutureSpells`: pure `Model` tables exported for the specs, each named
  once in production. Some are also cross-file APIs: `ns.Fishing.IsPole` (Gear), `ns.Gear.MarksOf`/`ColourOf`
  (Sections) and `OnRefresh`/`Settling` (CombinedBag). `ns.CombinedBag` (Bags/CombinedBag.lua) owns the combined bag's
  layout pass, its grid constants and `Relayout`; it calls `ns.Reagents.Reserve`, `ns.Sections.Active`/`Arrange`, then
  `ns.Reagents.Placed`, in that order.
- `ns.ClickMode` (Core/Modes.lua), `ns.ForEachBagButton`, `ns.ConflictOf`, `ns.Print` (Core/Core.lua), `ns.Suggestion`
  (Integrations/Companions.lua), `ns.Navigate`/`ns.NavigateHint` (Integrations/Navigate.lua), and Spellbook's `ns.KnownSpell`, `ns.TrainerSpells`,
  `ns.LineName`, `ns.GeneralName` (also read by Core/API.lua): shared helpers.
- `ns.QuestGivers`, `ns.QuestProgress`, `ns.QuestLog`, `ns.WhatsNew`: more `Model` tables exported for the specs.
- `ns.QuestieDB`, `ns.QuestieSource` (Integrations/QuestieSource.lua): the installed QuestieDB and what is read from it
  in game: its area-to-map lookup (QuestGivers) and NPC names and places (Core/API.lua).
- `ns.CampBenefits`, `ns.ZoneRanges`, `ns.DungeonEntrances`, `ns.InstanceEntrances`, `ns.RaidInstances`,
  `ns.Overlays`, `ns.ClassSpells`, `ns.ForeverQuests`: generated `Data/` tables.
- `ns.L` (`Locales/enUS.lua`) and each translation's `Locales/<locale>.lua`, which only sets `ns.L` entries;
  `Locales/phrases.txt` is `tools/phrases.py`'s template for translators.
- `ns.DungeonMaps` (Map/DungeonMaps.lua): `Model` table exported for the specs; the feature reads Atlas's `AtlasMaps` global and the TOC's `OptionalDeps` `Atlas`, `Atlas_ClassicWoW` at runtime.
- `TweaksForeverDungeonEntrancePinMixin`: global named by `Map/DungeonEntrances.xml`'s pin template.
- `TweaksForeverCharDB.trainer` (Spellbook): persisted trainer scan.
- Conflict entries name other addons' folders and read their saved variables (`LeaPlusDB.X == "On"`,
  `LegacyForeverDB`, `LeaMapsDB`, Questie, Mapster via LibStub): external contracts.
- `tools/changelog.py` is run by `release.yml`; `refresh-data.yml` seds `BUILD` in and runs every
  `tools/gen_*.py`, so a new generator must be added there and in both READMEs.
- `.pkgmeta` `ignore:`: every non-dot file not listed ships in the addon zip. New tool configs at the root
  (like `ruff.toml`) must be added there. The pinned packager prunes every dot-path itself (release.sh:1828 at
  v2.6.1), so dot-files are never listed.

## Settled

Shapes that look like defects here but are not. Read this before raising a finding.

- stringly-typed on `UI/Frames.lua` `Model.LayoutKey`/`Model.Prune` (`"account"`, `"preset"`, character GUID):
  these strings are the persisted `windowLayouts` key format; changing them changes saved data.
- stringly-typed on the `gearMark` values (`Bags/Gear.lua`): the three-member set already fails loudly on an
  unknown value (`error("unknown gear mark …")`).
- Model fields named once in production (`ns.Gear`, `ns.Camp`, …) and `types/` classes referenced once
  (`NamePlateFrame`, `SpellBookFrameTemplate_PagedSpellsFrame`, `SpellBookSingleSkillLineCategoryMixin`,
  `TFEntrancePin`): spec exports and annotations of external or XML-made objects, not dead code.
- `Bags/Sections.lua` `Arrange`/`Bags/Reagents.lua` `Reserve`: they share only the fits-at-`MIN_SCALE` check and two resize calls,
  and `MIN_SCALE` is already one constant; each owns its own state.
- `tools/screenshots.py` restates Lua layout constants on purpose: it draws without the game.
- Gear's colour kinds `"group"`/`"set"`/`"fishing"`: persisted keys in `TweaksForeverCharDB.colours`.
- Campsites' `if x and y and map` after `Here()` (which returns nothing where the position is secret).
- Gear's `Char()` short alias, Frames' repeated `if Active() then Schedule() end`, and Tooltips'
  single-caller `HealthBarStyle` (kept under the function-length limit).
- Small nil-safe reads of a saved variable or a Questie profile option (`Features/Automation.lua`, `Quests/QuestDistance.lua`):
  each site reads a different option for a different predicate, not one implementation.
- Junk's and Gear's click and mark guards: Gear needs `gearGroups` and Ctrl, Junk `markJunk` and Alt; Junk's icons
  show saved marks while selling blocks unknown quality for Leatrix, as `junk_spec` asserts.
- `Core/API.lua`'s `TweaksForever = TweaksForever or {}`: the shared global is a trust boundary; attach, never replace.
- The Sections/Reagents quotient-and-remainder grid placement: a small idiom over different contracts.
- `UI/Spellbook.lua`'s size: one Future Spells feature whose scan, selection and drawing share ClassData and Tabs.
- The README middle-dot footer and the `Options → …` arrow paths: the owner's house style across the docs.

## Anti-patterns

Shapes this codebase has produced more than once and a reviewer confirmed. Check new code against them.

- A spec that asserts how many `ns.Init` callbacks a file registers (`#initializers == 1`): the count is private.
  Assert the feature's default and run the initializers.
- A spec stub for a client global or `ns` helper that the paths the spec drives never call. Stub what the spec
  reaches; a stub that raises when called shows whether one is needed.
