
Evidence/call contracts: [Spellbook.lua](../../Spellbook.lua); [tests/spellbook_spec.lua](../../tests/spellbook_spec.lua); [types/Namespace.lua](../../types/Namespace.lua).

### `88f7901c9b` — unproven

Source: `final-20260930-prod-ui-text.json`, item 1 (zero-based); lens `silent-fallbacks`; `Spellbook.lua:620`; carried from active ledger.

Candidate: a trainer row whose level is nil is saved as level 1 (persisted to TweaksForeverCharDB.trainer)

```text
level = level or 1,
```

Verdict: GetTrainerServiceLevel is optional in the Forever annotations, but nil's meaning for an accepted row is not established by that type. ScanTrainer's level-1 default can be wrong only if an accepted row means unknown level rather than the host trainer UI's level-1 convention. Settle with a Forever trainer trace including name/lineID/rank/level; carried item 88f7901c9b remains unresolved.

Evidence/call contracts: [Spellbook.lua](../../Spellbook.lua); [types/Forever.lua](../../types/Forever.lua); [tests/spellbook_spec.lua](../../tests/spellbook_spec.lua); [initial-ledger.json](../runs/evidence/codex-final-20260930/initial-ledger.json).

## Tooltips.lua

### `60bc1180b6` — dismissed

Source: `final-20260930-prod-ui-dup.json`, item 0 (zero-based); lens `reinvented-wheel`; `Tooltips.lua:392`.

Candidate: ColorMixin:GetRGB() spelled out as .r/.g/.b: Tooltips.lua:392, 396 (GRAY_FONT_COLOR, NORMAL_FONT_COLOR), 327 and 345 (class/faction colour), 252; the rest of the repo uses SetTextColor(X:GetRGB()) with a multi-value comment (Spellbook.lua:564, QuestDistance.lua:190, Nameplates.lua:63)

```text
			label:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
```

Verdict: The three channel reads are the minimal host API argument idiom, and some color sources here (faction/class tables) are plain r/g/b records without a guaranteed GetRGB method. The method is convenient for ColorMixin globals but is not a canonical business operation required at every site; no conversion algorithm is being reimplemented.

Evidence/call contracts: [Tooltips.lua](../../Tooltips.lua); [Nameplates.lua](../../Nameplates.lua); [Spellbook.lua](../../Spellbook.lua); [types/Forever.lua](../../types/Forever.lua).

### `773b33987b` — dismissed

Source: `final-20260930-prod-ui-dup.json`, item 1 (zero-based); lens `parallel-implementations`; `Tooltips.lua:228`.

Candidate: Read-all-four-then-SetPadding-one-side is written three times: HealthBar Fit (Tooltips.lua:227-228), HealthBar bar OnHide (266-267), and CompareHeader's local Pad (375-376). Canonical home: one file-level helper taking the side to set.

```text
				tooltip:SetPadding(right, PADDING, left, top)
```

Verdict: HealthBar Fit sets bottom padding, bar OnHide restores bottom, and CompareHeader Pad changes top while preserving right/bottom/left. Each read-modify-write retains the other subsystem's padding. These are short host tuple updates serving opposite sides/lifecycles, not independently maintained layout algorithms.

Evidence/call contracts: [Tooltips.lua](../../Tooltips.lua); [types/Forever.lua](../../types/Forever.lua).

### `0bd3766cbc` — dismissed

Source: `final-20260930-prod-ui-dup.json`, item 4 (zero-based); lens `stringly-typed`; `Tooltips.lua:28`.

Candidate: Tooltip style set {modern, retail, forever} is restated as Feature options (Tooltips.lua:30-32), the default (28), the FILES keys (43-44) and by implicit absence of 'forever' in FILES (94, 111)

```text
		default = "modern",
```

Verdict: modern/retail/forever are saved style values and are expressly Settled persisted keys. FILES deliberately contains only the styles needing custom border assets: forever uses the host artwork. That partial asset map is not an accidental third closed inventory, and the modern default has an explicit WFA-4 waiver.

Evidence/call contracts: [Tooltips.lua](../../Tooltips.lua); [.agents/skills/sift-project/SKILL.md](../../.agents/skills/sift-project/SKILL.md); [AGENTS.md](../../AGENTS.md); [tools/tooltip_border.py](../../tools/tooltip_border.py).

### `b0874f286c` — dismissed

Source: `final-20260930-prod-ui-dup.json`, item 5 (zero-based); lens `oversized-modules`; `Tooltips.lua:4`.

Candidate: Tooltips.lua (445 lines) holds four separable responsibilities: NineSlice border painting and style repaint (37-120), unit health bar art/style/watch (122-272), player-line rewriting via TooltipDataProcessor (274-358), and compare-header relocation (360-413), all sharing only KEY and the padding idiom

```text
local KEY, STYLE = "retailTooltips", "tooltipStyle"
```

Verdict: Border styling, the health bar, player line and comparison header all attach to the same tooltip lifecycle and coordinate padding/style changes under the feature key. Existing local factories isolate their state without adding TOC exports; the profile expressly settles this coherent tooltip feature and its one-caller styling helper. Size alone does not establish unrelated responsibilities.

Evidence/call contracts: [Tooltips.lua](../../Tooltips.lua); [.agents/skills/sift-project/SKILL.md](../../.agents/skills/sift-project/SKILL.md).

### `6dd788f0d8` — dismissed

Source: `final-20260930-prod-ui-text.json`, item 2 (zero-based); lens `copy-slop`; `Tooltips.lua:26`.

Candidate: vague benefit claim in player-visible copy ('keeps the text crisp over any scenery')

```text
tooltip = "Modern is a neutral charcoal that keeps the text crisp over any scenery. Retail is the retail "
```

Verdict: The sentence describes the concrete Modern charcoal fill: tooltip_border.py uses neutral (18,19,23) at 0.9 opacity, while Retail uses a translucent navy. Tooltips.lua selects that artwork under the approved headline/default waiver, so background scenery contributes only 10% behind the text. One ordinary visual adjective tied to that difference is not the lens's pattern of vague, inflated marketing claims.

Evidence/call contracts: [docs/features.md](../../docs/features.md); [tools/tooltip_border.py](../../tools/tooltip_border.py); [Tooltips.lua](../../Tooltips.lua); [AGENTS.md](../../AGENTS.md).

## Vendor.lua

### `075f955b78` — dismissed

Source: `final-20260930-prod-core-dup.json`, item 0 (zero-based); lens `parallel-implementations`; `Vendor.lua:15`.

Candidate: Leatrix Plus 'option == On' conflict restated inline (Vendor.lua:12-17, Errors.lua:13-18, Junk.lua:112 LeatrixSellsGreys) beside the Leatrix(key) helper at Automation.lua:7-14 that builds the identical { addon = 'Leatrix_Plus', when = LeaPlusDB and LeaPlusDB[key] == 'On' } entry; canonical home would be Core next to ns.Feature

```text
				return LeaPlusDB and LeaPlusDB.AutoRepairGear == "On"
```

Verdict: Vendor tests AutoRepairGear, Errors tests HideErrorMessages, and Junk's LeatrixSellsGreys chooses ownership of grey-item selling rather than disabling the whole mark feature. Automation's helper serves its local automation options. These tiny nil-safe option predicates have different option/ownership contracts; the Settled entry explicitly allows them rather than adding a broad Leatrix abstraction.

Evidence/call contracts: [Vendor.lua](../../Vendor.lua); [Errors.lua](../../Errors.lua); [Junk.lua](../../Junk.lua); [Automation.lua](../../Automation.lua); [Core.lua](../../Core.lua); [.agents/skills/sift-project/SKILL.md](../../.agents/skills/sift-project/SKILL.md).

## WhatsNew.lua

### `e2288e90df` — dismissed

Source: `final-20260930-prod-core-reach.json`, item 0 (zero-based); lens `dead-code`; `WhatsNew.lua:15`.

Candidate: ns.WHATS_NEW_VERSION is test-only: no production code reads it

```text
ns.WHATS_NEW_VERSION = "0.7.3"
```

Verdict: WHATS_NEW_VERSION is consumed by whatsnew_spec to compare the shipped WhatsNew header with the latest CHANGELOG release, preventing a real stale announcement regression. It is an executable release/data-integrity contract, not an orphaned runtime feature; public model/annotation test seams are expressly Settled live roots.

Evidence/call contracts: [WhatsNew.lua](../../WhatsNew.lua); [tests/whatsnew_spec.lua](../../tests/whatsnew_spec.lua); [CHANGELOG.md](../../CHANGELOG.md); [.agents/skills/sift-project/SKILL.md](../../.agents/skills/sift-project/SKILL.md).

## ZoneLevels.lua

### `7986b930ea` — dismissed

Source: `final-20260930-prod-core-dup.json`, item 2 (zero-based); lens `parallel-implementations`; `ZoneLevels.lua:17`.

Candidate: Leatrix Maps 'on by default, only explicit Off' conflict restated in ZoneLevels.lua:11-20 and DungeonEntrances.lua:12-19 (also Leatrix Maps 'On' variant at Exploration.lua:18-23)

```text
				return not (LeaMapsDB and LeaMapsDB.ShowZoneLevels == "Off")
```

Verdict: ZoneLevels and DungeonEntrances each respect a different Maps option whose absent value means on; Exploration instead requires ShowUnexploredAreas == On. The explicit-Off and explicit-On policies are forced by those features' external saved-option contracts, and Settled covers small predicates serving distinct options.

Evidence/call contracts: [ZoneLevels.lua](../../ZoneLevels.lua); [DungeonEntrances.lua](../../DungeonEntrances.lua); [Exploration.lua](../../Exploration.lua); [.agents/skills/sift-project/SKILL.md](../../.agents/skills/sift-project/SKILL.md).

## docs/curseforge.md

### `34c25a60dc` — dismissed

Source: `final-20260930-config-docs-text.json`, item 12 (zero-based); lens `stale-docs`; `docs/curseforge.md:50`.

Candidate: store feature list omits quest levels, Abandon quests, Forever quest highlighting, quests on minimap givers and native Questie map icons

```text
- **Quests and camps**: the quest tracker sorts nearest first. With [Questie](https://www.curseforge.com/wow/addons/questie) installed (or just its QuestieDB addon), a creature you need shows your progress in its tooltip and a quest icon by its nameplate. Camp features say what they give and whether you have it.
```

Verdict: The store list is a selected summary constrained by WFA-11's 600-word budget, not an exhaustive feature inventory. Its quest sorting, progress and camp claims correspond to QuestDistance/QuestProgress/Campsites; omitted options remain documented in README and docs/features.md, and no listed statement claims those are the only quest features.

Evidence/call contracts: [docs/curseforge.md](../../docs/curseforge.md); [README.md](../../README.md); [docs/features.md](../../docs/features.md); [QuestDistance.lua](../../QuestDistance.lua); [QuestProgress.lua](../../QuestProgress.lua); [Campsites.lua](../../Campsites.lua).

## docs/features.md

### `cf670e641d` — decide

Source: `final-20260930-config-docs-text.json`, item 6 (zero-based); lens `copy-slop`; `docs/features.md:80`.

Candidate: curly apostrophes (Questie’s, twice) in a file that uses straight quotes everywhere else

```text
**Native quest map icons** replaces Questie’s quest-marker artwork with stock pickup, turn-in and objective symbols at readable map/minimap sizes. It keeps Questie’s full marker coverage and tooltips, and leaves its saved settings untouched. Off restores its appearance. QuestieDB is read automatically when installed; the database alone does not draw these markers.
```

Verdict: The two typographic apostrophes refer to Questie in the native-icons description and have no semantic effect on QuestiePins.lua. Owner question: use straight apostrophes consistently in the player-facing feature reference, or retain the current typography? Player-facing copy changes are outside automatic cleanup.

Evidence/call contracts: [docs/features.md](../../docs/features.md); [QuestiePins.lua](../../QuestiePins.lua).

### `d071e27b56` — dismissed

Source: `final-20260930-config-docs-text.json`, item 8 (zero-based); lens `wall-of-text`; `docs/features.md:36`.

Candidate: one bullet of about 170 words with nine sentences covering travel, hints, filters, suppression, Legacy Forever and missing instances

```text
- Mark every dungeon and raid entrance on zone and continent maps with retail's icons; point at one for its name, and left-click it to travel there: Shortest Path Forever plans the journey when it is installed, and otherwise the map's own waypoint marks the entrance. Without Shortest Path Forever, a grey line in the tooltip says where to get it (or to switch it on, when it is installed but off). Instances sharing a way in, such as Blackrock Mountain, share one pin that lists them. The map's own **Show instance entrances** filter turns them off, and an entrance steps aside where a flight master or Shortest Path Forever portal or dock already marks the spot; Legacy Forever draws the same portal with its shield on the corner where a Legacy step is left there. Forever's new instances (Dalaran, the Ruins of Lordaeron, the Hall of Thanes and the Wetlands excavation) have no entrance in the game's data yet, so they have no pin.
```

Verdict: This reference bullet covers distinct shipped behavior: map pins and click travel, navigation hints, name filtering, minimap/world-map suppression, Legacy conflict, and missing-entrance handling. DungeonEntrances.lua Model.Describe, pin mouse handlers and feature predicates implement those branches; compressing them loses user choices rather than removing repeated claims. It is the detailed feature reference, not the WFA-10 README budget.

Evidence/call contracts: [docs/features.md](../../docs/features.md); [DungeonEntrances.lua](../../DungeonEntrances.lua); [Navigate.lua](../../Navigate.lua).

### `6d35bbd6a9` — dismissed

Source: `final-20260930-config-docs-text.json`, item 9 (zero-based); lens `wall-of-text`; `docs/features.md:54`.

Candidate: bullet of about 150 words describing border, colours, player line, health bar and comparison label in one run

```text
- Modern tooltips: a thin grey border with rounded corners in place of the beige one, over a neutral charcoal that keeps the text crisp over any scenery. Tooltip style switches to the retail game's navy, or keeps the game's own border. A player's name is in their class colour, with the guild in brackets, race and class on one line and the faction in its colour. A unit's health bar sits inside its tooltip in the retail game's own bar and frame, in class or reaction colour, with health as numbers for players and a percentage for others, and a comparison tooltip's Equipped label moves inside it in grey. On by default.
```

Verdict: The tooltip reference names separate controls for border style, class-colour names, player-line details, health bar and comparison text; Tooltips.lua registers and implements each. The one-feature bullet is detailed documentation with concrete option effects, not repeated selling points, and the project explicitly settles this tooltip feature as coherent.

Evidence/call contracts: [docs/features.md](../../docs/features.md); [Tooltips.lua](../../Tooltips.lua); [.agents/skills/sift-project/SKILL.md](../../.agents/skills/sift-project/SKILL.md).

### `d2ac8e73ad` — dismissed

Source: `final-20260930-config-docs-text.json`, item 10 (zero-based); lens `wall-of-text`; `docs/features.md:51`.

Candidate: bullet of about 190 words mixing camp features, buff numbers, campfire listing and two buffs

```text
- Explain campsite benefits. Hovering a camp feature (a Camp Tent, Mana Well, Anvil and the rest) shows what sitting nearby gives you, such as "Stamina increased for 1 Hr", and whether you have it now, with the time left. A benefit you have carries your buff's own numbers ("Stamina increased by 8"); the game sets them when you gain it, so one you don't have shows none. Hovering a campfire lists every benefit a camp can give: the ones you have in green with their time left, the rest in grey. Your Campfire Nearby buff adds the benefits you have and which way the campfire is, once you have lit it or sat by it; your Camp Benefits buff adds the ones you haven't gained yet.
```

Verdict: Campsites.lua separates feature descriptions, observed aura status and benefit listing; the prose distinguishes sitting nearby from having the timed buff, maximum values from level scaling, and campfire from tent behavior. These qualifications constrain the displayed numbers and avoid promising unconditional buffs. Removing them because of the word count would discard factual uncertainty and context.

Evidence/call contracts: [docs/features.md](../../docs/features.md); [Campsites.lua](../../Campsites.lua); [types/Namespace.lua](../../types/Namespace.lua).

## tests/api_spec.lua

### `75fa68d1fb` — dismissed

Source: `final-20260930-tests-a-text.json`, item 2 (zero-based); lens `test-plumbing`; `tests/api_spec.lua:65`.

Candidate: Asserts literal coordinates, trainer names and positions (also Siln Skychaser, Murak Winterborn, bolt cost 900) copied from generated Data tables.

```text
assert(entrance.map == 1427 and entrance.x == 0.271 and entrance.y == 0.725, "first curated zone, before login")
```

Verdict: API.DungeonEntrance must select the first curated zone and work before login; returning a continent/cluster point instead yields different coordinates despite valid rows. Trainer names/positions and fees likewise test the public baked API/data contract, independent of runtime feature selection. These fixtures can fail realistic generator/API selection defects and are lens-exempt executable API documentation.

Evidence/call contracts: [tests/api_spec.lua](../../tests/api_spec.lua); [API.lua](../../API.lua); [tools/gen_dungeons.py](../../tools/gen_dungeons.py); [tools/gen_classspells.py](../../tools/gen_classspells.py).

## tests/automation_spec.lua

### `c035f45b37` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 19 (zero-based); lens `session-residue`; `tests/automation_spec.lua:54`.

Candidate: env._G = env is unused

```text
env._G = env
```

Verdict: Automation's exercised callbacks never read this spec's env._G self-reference; the root's newly added fast-loot checks also use env fields directly. Removing that assignment in a temporary spec keeps all automation assertions passing; no cross-spec environment is shared.

Evidence/call contracts: [tests/automation_spec.lua](../../tests/automation_spec.lua); [Automation.lua](../../Automation.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json); [token-and-freshness-probes.json](../runs/evidence/codex-final-20260930/token-and-freshness-probes.json).

## tests/bagslayout_spec.lua

### `6e5eaf1600` — dismissed

Source: `final-20260930-tests-a-dup.json`, item 0 (zero-based); lens `parallel-implementations`; `tests/bagslayout_spec.lua:139`.

Candidate: The ns stub re-implements Core.lua ns.BagItems (Core.lua:54, index/size iterator over container.Items) and ns.BagSize (Core.lua:47) instead of loading Core.lua.

```text
	BagItems = function(c)
```

Verdict: BagItems/BagSize here are a minimal injected host seam: this fixture supplies c.size directly and its fake containers differ from Core's live layout/bag-size acquisition. Sections/Reagents are exercised against that seam, while core_spec tests the real iterator. The settled standalone ns preambles and thin headless tests do not require importing Core's unrelated client initialization.

Evidence/call contracts: [tests/bagslayout_spec.lua](../../tests/bagslayout_spec.lua); [Core.lua](../../Core.lua); [Sections.lua](../../Sections.lua); [Reagents.lua](../../Reagents.lua); [tests/core_spec.lua](../../tests/core_spec.lua); [.agents/skills/sift-project/SKILL.md](../../.agents/skills/sift-project/SKILL.md).

### `545aa9bb86` — dismissed

Source: `final-20260930-tests-a-dup.json`, item 4 (zero-based); lens `parallel-implementations`; `tests/bagslayout_spec.lua:10`.

Candidate: Region() in bagslayout_spec.lua:4-77 and methods.* in frames_runtime_spec.lua:22-144 are two hand-written frame fakes (SetPoint/GetPoint/ClearAllPoints, Show/Hide/IsShown, SetScale/GetScale, SetHeight/GetHeight, SetFrameLevel, SetText, CreateFontString).

```text
function r:GetPoint()
```

Verdict: Bag Region keeps multiple points and layout/scale state, while the Frames fake drives scripts, combat/load order and movable-window geometry. The matching method names are the client frame interface; their data/state semantics differ. Sharing a general frame framework would couple standalone tests without consolidating an addon algorithm.

Evidence/call contracts: [tests/bagslayout_spec.lua](../../tests/bagslayout_spec.lua); [tests/frames_runtime_spec.lua](../../tests/frames_runtime_spec.lua); [Frames.lua](../../Frames.lua); [Sections.lua](../../Sections.lua); [Reagents.lua](../../Reagents.lua).

### `24d3b548a0` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 21 (zero-based); lens `dead-code`; `tests/bagslayout_spec.lua:38`.

Candidate: Region SetAlpha/GetAlpha (and the alpha field) are never called by the run

```text
function r:SetAlpha(a)
```

Verdict: The bag Region's alpha getter/setter/storage is unreachable in this fixture: the native skin traversal sees empty fake regions/children, and tests inspect points/scale rather than alpha. Exact SetAlpha-body removal passes the layout spec, and full-file dispatch/read review finds no GetAlpha or alpha observer; keep the geometry methods that are actually asserted.

Evidence/call contracts: [tests/bagslayout_spec.lua](../../tests/bagslayout_spec.lua); [Sections.lua](../../Sections.lua); [Reagents.lua](../../Reagents.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `c95b621279` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 22 (zero-based); lens `dead-code`; `tests/bagslayout_spec.lua:100`.

Candidate: button GetSlotAndBagID stub never called

```text
b.GetSlotAndBagID = function() end
```

Verdict: No current layout path calls this fake button GetSlotAndBagID: fake container child/region discovery does not drive native Chrome, while grouping uses GetBagID/GetID. Removing the method passes bagslayout_spec. Its existence in the host API or other mocks does not make this instance reachable.

Evidence/call contracts: [tests/bagslayout_spec.lua](../../tests/bagslayout_spec.lua); [Sections.lua](../../Sections.lua); [Reagents.lua](../../Reagents.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `92f4fb4a61` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 23 (zero-based); lens `dead-code`; `tests/bagslayout_spec.lua:206`.

Candidate: SetOverrideBinding stub never called

```text
SetOverrideBinding = function() end,
```

Verdict: This harness's GetBindingKey returns nil, so Layout calls ClearOverrideBindings but never sets an override. Removing SetOverrideBinding passes the spec; key-binding behavior is outside this fixture's exercised layout contract.

Evidence/call contracts: [tests/bagslayout_spec.lua](../../tests/bagslayout_spec.lua); [Sections.lua](../../Sections.lua); [Reagents.lua](../../Reagents.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `d675fc109a` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 24 (zero-based); lens `dead-code`; `tests/bagslayout_spec.lua:200`.

Candidate: C_Timer.After stub (calling fn at once) is never called

```text
After = function(_, fn)
```

Verdict: The bag layout fixture directly drives layout and uses empty native skin regions, so no deferred C_Timer.After path is entered. Deleting After preserves geometry/scale tests. Other specs' deferred callback needs do not provide a consumer in this standalone environment.

Evidence/call contracts: [tests/bagslayout_spec.lua](../../tests/bagslayout_spec.lua); [Sections.lua](../../Sections.lua); [Reagents.lua](../../Reagents.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `aa1ee45f2c` — confirmed

Source: `verify-20260930-codex-weak-pass.json`, item 0 (zero-based); lens `test-plumbing`; `tests/bagslayout_spec.lua:257`.

Candidate: The bag-fit assertion does not enforce the promised minimum scale; an unreadably small fitting bag passes

```text
assert(fits or bag:GetScale() == 0.75, "fits on screen: " .. bag:GetHeight() .. " x " .. bag:GetScale())
```

Verdict: The stated contract is fit subject to a native 0.75 lower bound, but fits or scale == 0.75 accepts fitting at 0.1. The initial mutation failed on a missing fake anchor, which is not a refutation; after supplying a realistic anchor, original production passes and broken want=0.1 also passes all three bag/section/reagent specs. The current harness does not meaningfully verify the minimum: keep fit checks, supply a shrink-capable fixture, and assert scale >= 0.75.

Evidence/call contracts: [tests/bagslayout_spec.lua](../../tests/bagslayout_spec.lua); [Sections.lua](../../Sections.lua); [Reagents.lua](../../Reagents.lua); [weak-bag-probe.json](../runs/evidence/codex-final-20260930/weak-bag-probe.json); [weak-bag-probe-corrected.json](../runs/evidence/codex-final-20260930/weak-bag-probe-corrected.json).

## tests/campsites_spec.lua

### `973ee04f85` — dismissed

Source: `final-20260930-tests-a-dup.json`, item 1 (zero-based); lens `parallel-implementations`; `tests/campsites_spec.lua:75`.

Candidate: The spec rebuilds the aura-to-benefit index (campsites_spec.lua:75-78) that Campsites.lua builds as its own local byAura (Campsites.lua:252-255) from ns.CampBenefits.

```text
local byAura = {}
```

Verdict: The fixture builds an aura lookup to return the chosen host aura record from CampBenefits; Campsites builds its own lookup to interpret that record into feature text. The short indexing loop is test setup versus real consumer behavior, and assertions still exercise actual Model listing/status calculations rather than a second model implementation.

Evidence/call contracts: [tests/campsites_spec.lua](../../tests/campsites_spec.lua); [Campsites.lua](../../Campsites.lua).

### `767f157bc6` — dismissed

Source: `final-20260930-tests-a-text.json`, item 3 (zero-based); lens `test-plumbing`; `tests/campsites_spec.lua:64`.

Candidate: Asserts first/last rows equal specific entries of the generated CampBenefits order (TENT first, BANNER last, #rows == #ns.CampBenefits).

```text
assert(rows[#rows].benefit[1] == BANNER)
```

Verdict: Model.Listing must retain every CampBenefits row in the defined order, with Tent first and Banner last. Truncating the final row or reversing presentation order breaks this while individual status/description tests can pass. This is public listing order and generated-data integrity, not private function shape.

Evidence/call contracts: [tests/campsites_spec.lua](../../tests/campsites_spec.lua); [Campsites.lua](../../Campsites.lua); [Data/CampBenefits.lua](../../Data/CampBenefits.lua).

## tests/core_spec.lua

### `49dbd6443b` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 20 (zero-based); lens `dead-code`; `tests/core_spec.lua:11`.

Candidate: C_AddOns.IsAddOnLoaded stub is never called

```text
C_AddOns = { IsAddOnLoaded = function() end },
```

Verdict: core_spec registers synthetic features without addon conflicts, so FindConflict never enters C_AddOns.IsAddOnLoaded. Deleting the injected C_AddOns namespace preserves this standalone spec; real conflict behavior is exercised by other feature/Frames tests, not this fake.

Evidence/call contracts: [tests/core_spec.lua](../../tests/core_spec.lua); [Core.lua](../../Core.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

## tests/dungeonentrances_combat_spec.lua

### `99e1d13b3d` — dismissed

Source: `final-20260930-tests-a-dup.json`, item 3 (zero-based); lens `parallel-implementations`; `tests/dungeonentrances_combat_spec.lua:107`.

Candidate: dungeonentrances_combat_spec.lua:117-127 and dungeonentrances_spec.lua:11-20 both stub GetRealZoneText, C_Map.GetAreaInfo and CreateAtlasMarkup and load Data/DungeonEntrances.lua plus DungeonEntrances.lua with the same ns shape.

```text
	GetRealZoneText = function(instance)
```

Verdict: The model spec returns atlas markup to inspect descriptions; the combat spec returns minimal labels and bare acquired pin tables to exercise protected refresh scheduling. Those different fake fidelity levels serve different host contracts. Unused individual combat stubs are separately assessed under reach; their existence does not make the whole test a second production implementation.

Evidence/call contracts: [tests/dungeonentrances_spec.lua](../../tests/dungeonentrances_spec.lua); [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [DungeonEntrances.lua](../../DungeonEntrances.lua).

### `e97edb82a3` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 0 (zero-based); lens `dead-code`; `tests/dungeonentrances_combat_spec.lua:13`.

Candidate: map.GetCanvas (with the GetWidth/GetHeight canvas it returns) and GetScaleForMinZoom are never called by the spec

```text
GetCanvas = function()
```

Verdict: GetCanvas and the nested width/height fake is the confirmed scope. Provider RefreshAllData only uses GetMapID and AcquirePin; acquired pins are bare tables, so pin positioning never reaches GetCanvas. Deleting this exact stub in a temporary copy leaves the protected refresh/regen regression spec passing; preserve the live provider/event fixture.

Evidence/call contracts: [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [DungeonEntrances.lua](../../DungeonEntrances.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `a5a765184c` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 1 (zero-based); lens `dead-code`; `tests/dungeonentrances_combat_spec.lua:23`.

Candidate: map.GetScaleForMinZoom stub never called (see GetCanvas finding)

```text
GetScaleForMinZoom = function()
```

Verdict: GetScaleForMinZoom is the confirmed scope. RefreshAllData never calls scale methods; only real pin OnAcquired would, and the fake AcquirePin does not dispatch it. Deleting this exact stub in a temporary copy leaves the protected refresh/regen regression spec passing; preserve the live provider/event fixture.

Evidence/call contracts: [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [DungeonEntrances.lua](../../DungeonEntrances.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `64eb048d4c` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 2 (zero-based); lens `dead-code`; `tests/dungeonentrances_combat_spec.lua:63`.

Candidate: ns.NavigateHint, ns.Suggestion and ns.Navigate stubs are never called

```text
NavigateHint = function()
```

Verdict: NavigateHint only is the confirmed scope. No acquired fake pin runs OnAcquired/OnMouseEnter, so this namespace helper is unreachable; Suggestion and Navigate are separate findings. Deleting this exact stub in a temporary copy leaves the protected refresh/regen regression spec passing; preserve the live provider/event fixture.

Evidence/call contracts: [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [DungeonEntrances.lua](../../DungeonEntrances.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `46b716c29d` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 3 (zero-based); lens `dead-code`; `tests/dungeonentrances_combat_spec.lua:66`.

Candidate: ns.Suggestion stub never called

```text
Suggestion = function() end,
```

Verdict: Suggestion is the confirmed scope. The bare pin fixture never invokes mouse-enter navigation text, and no provider refresh path reads Suggestion. Deleting this exact stub in a temporary copy leaves the protected refresh/regen regression spec passing; preserve the live provider/event fixture.

Evidence/call contracts: [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [DungeonEntrances.lua](../../DungeonEntrances.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `f1fe578860` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 4 (zero-based); lens `dead-code`; `tests/dungeonentrances_combat_spec.lua:67`.

Candidate: ns.Navigate stub never called

```text
Navigate = function() end,
```

Verdict: Navigate is the confirmed scope. The fixture never invokes a pin click handler, and RefreshAllData does not navigate. Deleting this exact stub in a temporary copy leaves the protected refresh/regen regression spec passing; preserve the live provider/event fixture.

Evidence/call contracts: [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [DungeonEntrances.lua](../../DungeonEntrances.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `ca0eea7a62` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 5 (zero-based); lens `dead-code`; `tests/dungeonentrances_combat_spec.lua:73`.

Candidate: eventFrame.UnregisterEvent is never called, and the `registered = false` branch it implies does not exist in production

```text
UnregisterEvent = function(self)
```

Verdict: UnregisterEvent is the confirmed scope. The deferred provider registers PLAYER_REGEN_ENABLED on the frame but never calls this unregister method; the registered=false fake transition is not reached. Deleting this exact stub in a temporary copy leaves the protected refresh/regen regression spec passing; preserve the live provider/event fixture.

Evidence/call contracts: [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [DungeonEntrances.lua](../../DungeonEntrances.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `e0b8775a11` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 6 (zero-based); lens `dead-code`; `tests/dungeonentrances_combat_spec.lua:101`.

Candidate: BaseMapPoiPinMixin.OnAcquired and OnMouseEnter stubs are never called

```text
OnAcquired = function() end,
```

Verdict: BaseMapPoiPinMixin.OnAcquired only is the confirmed scope. The fake map AcquirePin increments a counter and returns {}, so the base pin initialization callback is never dispatched; OnMouseEnter is assessed separately. Deleting this exact stub in a temporary copy leaves the protected refresh/regen regression spec passing; preserve the live provider/event fixture.

Evidence/call contracts: [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [DungeonEntrances.lua](../../DungeonEntrances.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `4cb5550170` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 7 (zero-based); lens `dead-code`; `tests/dungeonentrances_combat_spec.lua:102`.

Candidate: BaseMapPoiPinMixin.OnMouseEnter stub never called

```text
OnMouseEnter = function() end,
```

Verdict: BaseMapPoiPinMixin.OnMouseEnter is the confirmed scope. The combat test drives provider refresh/regen and never sends pin mouse events. Deleting this exact stub in a temporary copy leaves the protected refresh/regen regression spec passing; preserve the live provider/event fixture.

Evidence/call contracts: [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [DungeonEntrances.lua](../../DungeonEntrances.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `fce17c9822` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 8 (zero-based); lens `dead-code`; `tests/dungeonentrances_combat_spec.lua:104`.

Candidate: CreateVector2D stub never called

```text
CreateVector2D = function(x, y)
```

Verdict: CreateVector2D is the confirmed scope. Only real pin acquisition positions pins with vectors; this fake AcquirePin returns bare tables and never invokes that branch. Deleting this exact stub in a temporary copy leaves the protected refresh/regen regression spec passing; preserve the live provider/event fixture.

Evidence/call contracts: [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [DungeonEntrances.lua](../../DungeonEntrances.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `63e523f956` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 9 (zero-based); lens `dead-code`; `tests/dungeonentrances_combat_spec.lua:107`.

Candidate: GetRealZoneText, C_Map.GetAreaInfo and CreateAtlasMarkup stubs never called

```text
GetRealZoneText = function(instance)
```

Verdict: GetRealZoneText only is the confirmed scope. No pin mouse-enter tooltip is exercised, so instance-name description is unreachable; C_Map.GetAreaInfo/CreateAtlasMarkup have their own items. Deleting this exact stub in a temporary copy leaves the protected refresh/regen regression spec passing; preserve the live provider/event fixture.

Evidence/call contracts: [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [DungeonEntrances.lua](../../DungeonEntrances.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `17985437ef` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 10 (zero-based); lens `dead-code`; `tests/dungeonentrances_combat_spec.lua:111`.

Candidate: C_Map.GetAreaInfo stub never called

```text
GetAreaInfo = function(area)
```

Verdict: C_Map.GetAreaInfo is the confirmed scope. RefreshAllData iterates loaded map entries without asking for area names; the unused tooltip path would consume this fake. Deleting this exact stub in a temporary copy leaves the protected refresh/regen regression spec passing; preserve the live provider/event fixture.

Evidence/call contracts: [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [DungeonEntrances.lua](../../DungeonEntrances.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `9d8d8de27b` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 11 (zero-based); lens `dead-code`; `tests/dungeonentrances_combat_spec.lua:115`.

Candidate: CreateAtlasMarkup stub never called

```text
CreateAtlasMarkup = function(atlas)
```

Verdict: CreateAtlasMarkup is the confirmed scope. Model.Describe is not invoked by the combat refresh harness; the map-only spec separately tests actual description markup. Deleting this exact stub in a temporary copy leaves the protected refresh/regen regression spec passing; preserve the live provider/event fixture.

Evidence/call contracts: [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [DungeonEntrances.lua](../../DungeonEntrances.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `b1d2f67079` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 12 (zero-based); lens `dead-code`; `tests/dungeonentrances_combat_spec.lua:118`.

Candidate: GameTooltip_AddDisabledLine and GetAppropriateTooltip stubs never called

```text
GameTooltip_AddDisabledLine = function() end,
```

Verdict: GameTooltip_AddDisabledLine only is the confirmed scope. The combat harness never invokes mouse-enter/tooltips; GetAppropriateTooltip is the next distinct item. Deleting this exact stub in a temporary copy leaves the protected refresh/regen regression spec passing; preserve the live provider/event fixture.

Evidence/call contracts: [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [DungeonEntrances.lua](../../DungeonEntrances.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `8de16b81bb` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 13 (zero-based); lens `dead-code`; `tests/dungeonentrances_combat_spec.lua:119`.

Candidate: GetAppropriateTooltip stub never called

```text
GetAppropriateTooltip = function()
```

Verdict: GetAppropriateTooltip is the confirmed scope. Bare acquired pins have no dispatched mouse handlers, leaving the whole tooltip lookup unreachable. Deleting this exact stub in a temporary copy leaves the protected refresh/regen regression spec passing; preserve the live provider/event fixture.

Evidence/call contracts: [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [DungeonEntrances.lua](../../DungeonEntrances.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `b63891b8e2` — dismissed

Source: `final-20260930-tests-a-reach.json`, item 14 (zero-based); lens `dead-code`; `tests/dungeonentrances_combat_spec.lua:57`.

Candidate: `L = {}` appears twice (ns at line 57 and env at line 122); the env one is dead: the file reads ns.L, never a global L

```text
L = {},
```

Verdict: Same producer as c77df7eea2: this one-line quote matches both ns.L (required) and env.L (unused). Only the separately re-anchored env field is removable; DungeonEntrances captures ns.L, so do not act on the ledger's first match.

Evidence/call contracts: [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [DungeonEntrances.lua](../../DungeonEntrances.lua); [final-probes.json](../runs/evidence/codex-final-20260930/final-probes.json).

Canonical producer: `c77df7eea2` (its verdict remains separately recorded).

### `7cfb38703e` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 15 (zero-based); lens `dead-code`; `tests/dungeonentrances_combat_spec.lua:58`.

Candidate: ns.RaidInstances initial value is overwritten by the Data load

```text
RaidInstances = {},
```

Verdict: Data/DungeonEntrances.lua assigns ns.RaidInstances before the feature is loaded, unconditionally replacing this empty fixture. The independent removal probe passes the combat spec; no callback runs between the initial namespace construction and Data load.

Evidence/call contracts: [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [Data/DungeonEntrances.lua](../../Data/DungeonEntrances.lua); [final-probes.json](../runs/evidence/codex-final-20260930/final-probes.json).

### `ba246f928d` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 16 (zero-based); lens `dead-code`; `tests/dungeonentrances_combat_spec.lua:59`.

Candidate: ns.DungeonEntrances literal is overwritten by Data/DungeonEntrances.lua

```text
DungeonEntrances = { [1427] = {} },
```

Verdict: The Data load unconditionally replaces ns.DungeonEntrances before provider installation; the [1427] empty table is never observed. Removing just that fixture in an isolated spec preserves actual map refresh and regen counts.

Evidence/call contracts: [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [Data/DungeonEntrances.lua](../../Data/DungeonEntrances.lua); [final-probes.json](../runs/evidence/codex-final-20260930/final-probes.json).

### `3d1a3ad2f0` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 17 (zero-based); lens `session-residue`; `tests/dungeonentrances_combat_spec.lua:51`.

Candidate: Test-only global __dungeonCombatMap exists just so AddDataProvider can hand it back through provider.GetMap

```text
_G.__dungeonCombatMap = map
```

Verdict: AddDataProvider already receives the map as self and can capture that receiver for provider.GetMap; a temporary self-capture replacement passes. The test-only _G export has no other reader. Capturing a raw local map from its own initializer would be incorrectly scoped in Lua, so the reviewer's suggested rewrite is narrowed to receiver capture.

Evidence/call contracts: [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `4441b040d3` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 18 (zero-based); lens `dead-code`; `tests/dungeonentrances_combat_spec.lua:5`.

Candidate: `pins` is never populated, so the template-indexed lookup in EnumeratePinsByTemplate is vestigial

```text
local pins = {}
```

Verdict: pins is initialized empty and has no assignment/insertion; AcquirePin only increments acquired and returns {}. EnumeratePinsByTemplate therefore always terminates immediately. The live contract is the refresh/acquisition/regen count, so an iterator returning nil can express it without a nonexistent pin store; this does not claim real pin layout is tested.

Evidence/call contracts: [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [DungeonEntrances.lua](../../DungeonEntrances.lua).

### `c77df7eea2` — confirmed

Source: `verify-20260930-codex-reanchor.json`, item 0 (zero-based); lens `dead-code`; `tests/dungeonentrances_combat_spec.lua:122`.

Candidate: Only env.L in the combat fixture is unread; required ns.L is a different field

```text
	L = {},
}, { __index = _G })
```

Verdict: DungeonEntrances captures local L = ns.L and never reads env.L. The precise two-line anchor identifies only the environment field; deleting it in a temporary spec preserves combat/regen behavior while required ns.L remains. This supersedes ambiguous b63891b8e2.

Evidence/call contracts: [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [DungeonEntrances.lua](../../DungeonEntrances.lua); [final-probes.json](../runs/evidence/codex-final-20260930/final-probes.json).

## tests/dungeonentrances_spec.lua

### `e69781ab2a` — dismissed

Source: `final-20260930-tests-a-text.json`, item 1 (zero-based); lens `test-plumbing`; `tests/dungeonentrances_spec.lua:44`.

Candidate: Hard-coded instance ID list asserted against the generated DungeonEntrances data: a snapshot of data, not of Model behaviour.

```text
for _, instance in ipairs({ 33, 36, 43, 189, 229, 249, 309, 389, 409, 469, 509, 531 }) do
```

Verdict: The curated instance list protects required classic entrances against incomplete upstream extraction or mistaken generator filtering. Model.Atlas/Describe can still pass with an entrance omitted, so those behavioral tests do not replace the pinned dataset presence contract. gen_dungeons_test additionally verifies projection/selection rules.

Evidence/call contracts: [tests/dungeonentrances_spec.lua](../../tests/dungeonentrances_spec.lua); [tools/gen_dungeons.py](../../tools/gen_dungeons.py); [tools/gen_dungeons_test.py](../../tools/gen_dungeons_test.py); [Data/DungeonEntrances.lua](../../Data/DungeonEntrances.lua).

### `c62c54a915` — confirmed

Source: `final-20260930-tests-a-text.json`, item 5 (zero-based); lens `test-plumbing`; `tests/dungeonentrances_spec.lua:26`.

Candidate: Asserts how many Init callbacks the file registers (also errors, exploration, frames, core specs), a private registration detail.

```text
assert(#initializers == 1 and features.dungeonEntrances.default == true)
```

Verdict: Only #initializers == 1 is confirmed; the true default remains a public contract. Adding an extra no-op DungeonEntrances Init callback fails this assertion, and retaining the same default assertion while dropping the private count restores all spec checks. Provider behavior stays covered by the combat spec; do not delete the default check.

Evidence/call contracts: [tests/dungeonentrances_spec.lua](../../tests/dungeonentrances_spec.lua); [DungeonEntrances.lua](../../DungeonEntrances.lua); [tests/dungeonentrances_combat_spec.lua](../../tests/dungeonentrances_combat_spec.lua); [final-probes.json](../runs/evidence/codex-final-20260930/final-probes.json).

## tests/exploration_spec.lua

### `1aa89efcda` — dismissed

Source: `final-20260930-tests-a-text.json`, item 0 (zero-based); lens `test-plumbing`; `tests/exploration_spec.lua:91`.

Candidate: Pins exact counts of the generated Overlays table; it fails on every legitimate data refresh and catches no logic defect.

```text
assert(arts == 84 and areas == 1073 and files == 1739, "pinned build coverage changed")
```

Verdict: This is the pinned-build overlay completeness contract: the generator promises the full build's maps/areas/files, and per-row schema checks alone accept a valid but truncated dataset. A source omission would reduce one count while leaving all remaining rows well formed. A legitimate build update deliberately revises the integrity expectation; that does not make the test constant-equals-itself.

Evidence/call contracts: [tests/exploration_spec.lua](../../tests/exploration_spec.lua); [tools/gen_overlays.py](../../tools/gen_overlays.py); [Data/Overlays.lua](../../Data/Overlays.lua).

## tests/fishing_spec.lua

### `06ff45c067` — dismissed

Source: `final-20260930-tests-a-dup.json`, item 2 (zero-based); lens `parallel-implementations`; `tests/fishing_spec.lua:60`.

Candidate: fishing_spec.lua and campsites_spec.lua each stub UIErrorsFrame.AddMessage into a messages list plus YELLOW_FONT_COLOR.GetRGB returning 1,1,0, character for character.

```text
	YELLOW_FONT_COLOR = {
```

Verdict: UIErrorsFrame and YELLOW_FONT_COLOR are tiny host doubles recording messages in two standalone specs. Fishing tests casting/lure notification while Campsites tests aura transitions/volume; the identical recorder/color constant is intentional fixture plumbing, not independently maintained notification logic.

Evidence/call contracts: [tests/fishing_spec.lua](../../tests/fishing_spec.lua); [tests/campsites_spec.lua](../../tests/campsites_spec.lua); [Fishing.lua](../../Fishing.lua); [Campsites.lua](../../Campsites.lua).

### `948997b00b` — dismissed

Source: `final-20260930-tests-a-text.json`, item 6 (zero-based); lens `test-plumbing`; `tests/fishing_spec.lua:68`.

Candidate: Restates the ns.Feature declaration literals of Fishing.lua.

```text
assert(features.applyLure.parent == "easyCast" and features.fishingSounds.default == false)
```

Verdict: The applyLure parent controls Settings' dependency predicate and ns.Active; fishingSounds off is the project's player-action/default policy. A mistyped parent or enabled sound default changes actual user behavior while casting model tests can still pass. The assertion is a public option/dependency contract, including the documented default-off rule.

Evidence/call contracts: [tests/fishing_spec.lua](../../tests/fishing_spec.lua); [Fishing.lua](../../Fishing.lua); [Settings.lua](../../Settings.lua); [Core.lua](../../Core.lua); [AGENTS.md](../../AGENTS.md).

## tests/frames_runtime_spec.lua

### `9779ec1618` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 25 (zero-based); lens `dead-code`; `tests/frames_runtime_spec.lua:21`.

Candidate: RegisterForDrag no-op method is unused

```text
"RegisterForDrag",
```

Verdict: The runtime fixture exercises move/place, layout selection, combat and reset; it never constructs the drag editor path that would register dragging. Removing this single no-op method-list entry preserves all frames_runtime checks.

Evidence/call contracts: [tests/frames_runtime_spec.lua](../../tests/frames_runtime_spec.lua); [Frames.lua](../../Frames.lua); [followup-probes-corrected.json](../runs/evidence/codex-final-20260930/followup-probes-corrected.json).

### `b94a703979` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 26 (zero-based); lens `dead-code`; `tests/frames_runtime_spec.lua:190`.

Candidate: manager.IsSnapEnabled, GetRegions, GetChildren and methods.GetAlpha stubs are never called

```text
manager.IsSnapEnabled = function()
```

Verdict: IsSnapEnabled only is the confirmed scope. The fake never opens the Windows drag editor or enters snap-preview calculations; its exact stub removal passes frames_runtime_spec. The broad IsSnapEnabled finding's other methods are recorded separately, preventing duplicate removals.

Evidence/call contracts: [tests/frames_runtime_spec.lua](../../tests/frames_runtime_spec.lua); [Frames.lua](../../Frames.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `08e97b8c29` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 27 (zero-based); lens `dead-code`; `tests/frames_runtime_spec.lua:193`.

Candidate: manager.GetRegions stub never called
