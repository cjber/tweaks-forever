# SIFT: every independent Codex verdict, 2026-09-30

Companion to [coverage, guard ledger and gate report](2026-09-30.md). Every original candidate and carried item is recorded; duplicate findings name their canonical producer. Quotes below are the original anchors, not instructions. Runtime/config/tool files remain untouched by this verifier. Lens exemptions and Settled claims below are scoped to their concrete call paths, not blanket clean verdicts.

## .agents/skills/sift-project/SKILL.md

### `0f3dedc79a` — confirmed

Source: `final-20260930-config-docs-text.json`, item 1 (zero-based); lens `stale-docs`; `.agents/skills/sift-project/SKILL.md:95`.

Candidate: claims refresh-data.yml runs every tools/gen_*.py

```text
- `tools/changelog.py` is run by `release.yml`; `refresh-data.yml` seds `BUILD` in and runs every
```

Verdict: refresh-data.yml lists exactly five generators; gen_foreverquests.py is a separate manual CSV workflow and is absent from that list. The profile's “every tools/gen_*.py” claim is false; tools/README.md has the related every-generator BUILD claim. This is factual model-read text, so correction is within the audit fact exception; evidence only here.

Evidence/call contracts: [.agents/skills/sift-project/SKILL.md](../../.agents/skills/sift-project/SKILL.md); [.github/workflows/refresh-data.yml](../../.github/workflows/refresh-data.yml); [tools/gen_foreverquests.py](../../tools/gen_foreverquests.py); [tools/README.md](../../tools/README.md).

### `a414d85e34` — dismissed

Source: `final-20260930-config-docs-text.json`, item 2 (zero-based); lens `stale-docs`; `.agents/skills/sift-project/SKILL.md:69`.

Candidate: lists only SLASH_TWEAKSFOREVER1 and SLASH_TWEAKSFOREVER_RELOAD1

```text
- Slash commands: `SLASH_TWEAKSFOREVER1`, `SLASH_TWEAKSFOREVER_RELOAD1` with `SlashCmdList` entries.
```

Verdict: The Live roots slash-command entry names the primary registry roots, without claiming an exhaustive alias list. Reload.lua assigns SLASH_TWEAKSFOREVER_RELOAD2 and Settings.lua assigns SLASH_TWEAKSFOREVER2 to those same SlashCmdList handlers; README and .luacheckrc already include the aliases. No live entry is falsely described as unreachable.

Evidence/call contracts: [Reload.lua](../../Reload.lua); [Settings.lua](../../Settings.lua); [README.md](../../README.md); [.luacheckrc](../../.luacheckrc); [.agents/skills/sift-project/SKILL.md](../../.agents/skills/sift-project/SKILL.md).

## .github/workflows/release.yml

### `ca88955eac` — confirmed

Source: `final-20260930-config-docs-text.json`, item 3 (zero-based); lens `comment-narration`; `.github/workflows/release.yml:20`.

Candidate: comment sits above the 'Verify full CI' step but describes the later 'Release notes' step

```text
      # The release notes are this version's CHANGELOG entry, not the whole file;
```

Verdict: The comment says a missing CHANGELOG entry fails “here”, immediately above Verify full CI; that step runs release_check.py, which checks the prior CI run. The later Release notes step runs changelog.py --version and rejects the missing version. Move or correct the comment without changing workflow order.

Evidence/call contracts: [.github/workflows/release.yml](../../.github/workflows/release.yml); [tools/release_check.py](../../tools/release_check.py); [tools/changelog.py](../../tools/changelog.py).

## .luacheckrc

### `395b890196` — confirmed

Source: `final-20260930-config-docs-reach.json`, item 0 (zero-based); lens `dead-code`; `.luacheckrc:182`.

Candidate: read_globals entry MenuUtil is named by no production Lua or XML file once the working-tree Gear.lua drops MenuUtil.CreateContextMenu

```text
	"MenuUtil",
```

Verdict: The current OpenMenu creates an addon-owned panel and never reads global MenuUtil; tests/gear_ui_spec.lua stores env.MenuUtil as a negative tripwire, which needs no global allowlist entry. Removing this entry in an isolated config leaves all 75 Lua files warning-free; all 16 available refs and open PR #97 add no current-worktree consumer. Hot file; no edit.

Evidence/call contracts: [Gear.lua](../../Gear.lua); [tests/gear_ui_spec.lua](../../tests/gear_ui_spec.lua); [followup-probes-corrected.json](../runs/evidence/codex-final-20260930/followup-probes-corrected.json); [branch-symbol-evidence.json](../runs/evidence/codex-final-20260930/branch-symbol-evidence.json).

## .sift/scripts/setting-callback-outside-core.py

### `edfcc8c7af` — confirmed

Source: `final-20260930-config-docs-text.json`, item 4 (zero-based); lens `comment-narration`; `.sift/scripts/setting-callback-outside-core.py:6`.

Candidate: docstring records history (date, ledger id, the 13 sites that moved)

```text
Written in the 2026-09-27 decisions pass (ledger ca2907f157): ten feature files each restated the
```

Verdict: The dated ledger citation and count of moved sites narrate the implementation session. The rule actually recognizes OnSettingChanged outside Core; its API.lua exclusion and central-dispatch rationale are the useful maintenance contract and can stay independently of that history.

Evidence/call contracts: [.sift/scripts/setting-callback-outside-core.py](../../.sift/scripts/setting-callback-outside-core.py); [Core.lua](../../Core.lua); [.sift/script-tests/setting-callback-outside-core](../../.sift/script-tests/setting-callback-outside-core).

## .sift/scripts/unused-luacheck-global.py

### `cd37006921` — confirmed

Source: `final-20260930-config-docs-text.json`, item 5 (zero-based); lens `comment-narration`; `.sift/scripts/unused-luacheck-global.py:6`.

Candidate: docstring records history (audit date, the two globals found, PR #66)

```text
Written in the 2026-09-27 audit against `StaticPopupDialogs` and `tInvert`, left behind when #66 moved
```

Verdict: The audit date, old globals and PR number explain a past cleanup rather than the detector. Retain the translator-template/GetLocale exception: main explicitly adds Locales/phrases.txt to its Lua-like corpus. The historical whole-tree hit count does not establish current coverage.

Evidence/call contracts: [.sift/scripts/unused-luacheck-global.py](../../.sift/scripts/unused-luacheck-global.py); [Locales/phrases.txt](../../Locales/phrases.txt); [.sift/script-tests/unused-luacheck-global](../../.sift/script-tests/unused-luacheck-global).

## AGENTS.md

### `f0cb3415e5` — decide

Source: `final-20260930-config-docs-text.json`, item 7 (zero-based); lens `copy-slop`; `AGENTS.md:25`.

Candidate: em dashes used as separators throughout the file (lines 25-29, 80)

```text
- `Core.lua` — `ns.Feature`/`ns.On`/`ns.Init`; every feature file registers through it, and TOC
```

Verdict: The em dashes separate file names from factual descriptions in AGENTS.md; the project waives README middle dots and Options arrows, not AGENTS punctuation. Owner question: replace these separators with colons in model-read instructions, or explicitly retain this document style? This is instruction-form text rather than a stale factual assertion.

Evidence/call contracts: [AGENTS.md](../../AGENTS.md); [.agents/skills/sift-project/SKILL.md](../../.agents/skills/sift-project/SKILL.md).

## API.lua

### `b7a86a6fdb` — confirmed

Source: `final-20260930-prod-core-text.json`, item 0 (zero-based); lens `defensive-noise`; `API.lua:49`.

Candidate: `baked.trainers or {}` guards a field every ClassSpells entry has

```text
	for _, row in ipairs(baked.trainers or {}) do
```

Verdict: Trainers receives a baked TFClassSpells entry selected from generated Data/ClassSpells.lua; every class has a nonoptional trainers table, while missing classes are handled before iteration. The temporary fallback removal passes api_spec including before-login access and unknown-class handling. This guard is not the public API attach boundary or optional host metadata.

Evidence/call contracts: [API.lua](../../API.lua); [Data/ClassSpells.lua](../../Data/ClassSpells.lua); [types/Namespace.lua](../../types/Namespace.lua); [tests/api_spec.lua](../../tests/api_spec.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `251a1d1547` — dismissed

Source: `final-20260930-prod-core-text.json`, item 1 (zero-based); lens `comment-narration`; `API.lua:10`.

Candidate: version-history paragraph in the header comment ("v2 adds", "v1's members keep their behavior"), restating the Trainers() comment at line 38

```text
-- v2 adds Trainers(), the class trainers to visit and where they stand, which is baked so it answers before login
```

Verdict: The API header documents compatibility: v2 adds Trainers without changing v1 members and answers from baked data before login/combat. api_spec tests the separate availability and live-data contracts; the function comment alone does not communicate version negotiation to external consumers. This is public API documentation, not an implementation-session history.

Evidence/call contracts: [API.lua](../../API.lua); [types/API.lua](../../types/API.lua); [tests/api_spec.lua](../../tests/api_spec.lua).

## Campsites.lua

### `51e4d1ed8f` — dismissed

Source: `final-20260930-prod-quest-dup.json`, item 7 (zero-based); lens `stringly-typed`; `Campsites.lua:134`.

Candidate: ns.CampBenefits rows and the FEATURES rows are positional tuples read by magic index: benefit[1] aura, [2] name, [3] effect, [4] seconds, [5] bases (Campsites.lua:134, 208, 262, 174, 175) and unpack(feature) at 352; the TENT special case is compared by aura ID in AddRow, AddStatus and Announcement.

```text
	local effect, bases = benefit[3], benefit[5]
```

Verdict: CampBenefits is a generated serialized TFCampBenefit tuple with a central annotated field order, while FEATURES binds existing host object/aura identifiers. TENT is already a named constant and is compared because that aura has distinct sitting/mana behavior. The indexing is a persisted/generated boundary contract, not duplicated internal dispatch inventories.

Evidence/call contracts: [Campsites.lua](../../Campsites.lua); [types/Namespace.lua](../../types/Namespace.lua); [tools/gen_camp.py](../../tools/gen_camp.py); [tests/campsites_spec.lua](../../tests/campsites_spec.lua).

## Core.lua

### `8cd2f102f3` — decide

Source: `final-20260930-standards-std.json`, item 0 (zero-based); lens `standards`; `Core.lua:26`.

Candidate: WFA-4: chat prefix uses Blizzard gold |cffffd200, not the family mint |cff33ff99

```text
	print("|cffffd200Tweaks Forever:|r " .. message)
```

Verdict: Core.Print emits the gold prefix; WFA-4 requires family mint, and the only color waiver covers the Modern tooltip default. core_spec pinning gold is evidence of behavior, not an owner waiver. Owner question: adopt the mint chat prefix or explicitly approve gold as a WFA-4 exception?

Evidence/call contracts: [Core.lua](../../Core.lua); [tests/core_spec.lua](../../tests/core_spec.lua); [AGENTS.md](../../AGENTS.md).

## DungeonEntrances.lua

### `ffe2a577ca` — dismissed

Source: `final-20260930-prod-quest-dup.json`, item 2 (zero-based); lens `parallel-implementations`; `DungeonEntrances.lua:69`.

Candidate: Raid-vs-dungeon classification of an instance is restated: Model.Atlas (DungeonEntrances.lua:44-51) decides Raid/Dungeon for an entry by looping instances against ns.RaidInstances, and Model.Describe (line 69) repeats the per-instance rule ns.RaidInstances[instance] and 'Raid' or 'Dungeon'.

```text
			local atlas = ns.RaidInstances[instance] and "Raid" or "Dungeon"
```

Verdict: Model.Atlas selects Raid only when every instance at an entrance is a raid, while Describe chooses each row's own raid/dungeon icon. A mixed entrance must show an aggregate Dungeon pin and different individual icons. These two classifications consume different cardinalities and are not interchangeable copies.

Evidence/call contracts: [DungeonEntrances.lua](../../DungeonEntrances.lua); [tests/dungeonentrances_spec.lua](../../tests/dungeonentrances_spec.lua); [tools/screenshots.py](../../tools/screenshots.py).

## Errors.lua

### `a20e29c68b` — dismissed

Source: `final-20260930-prod-core-dup.json`, item 1 (zero-based); lens `parallel-implementations`; `Errors.lua:16`.

Candidate: Second inline copy of the Leatrix Plus 'On' conflict entry (see Vendor.lua finding); canonical Automation.lua:7 Leatrix(key)

```text
				return LeaPlusDB and LeaPlusDB.HideErrorMessages == "On"
```

Verdict: Same producer as 075f955b78: HideErrorMessages is this feature's separate Leatrix predicate, while Junk and repair predicates control different behavior and defaults. The Settled small nil-safe external option reads cover this three-line construction.

Evidence/call contracts: [Errors.lua](../../Errors.lua); [Vendor.lua](../../Vendor.lua); [Automation.lua](../../Automation.lua); [.agents/skills/sift-project/SKILL.md](../../.agents/skills/sift-project/SKILL.md).

Canonical producer: `075f955b78` (its verdict remains separately recorded).

## Exploration.lua

### `92b6dcd06e` — dismissed

Source: `final-20260930-prod-core-text.json`, item 2 (zero-based); lens `comment-narration`; `Exploration.lua:217`.

Candidate: vague comment that does not say what the code below does

```text
	-- The base provider redraws on every map change as well; a zoom can change the art layer.
```

Verdict: The provider must invalidate overlays on canvas-scale changes even when the map ID stays the same: zoom changes the host art layer. RefreshAllData and OnCanvasScaleChanged implement that distinction. The comment explains the otherwise nonobvious extra invalidation trigger, rather than paraphrasing the next statement.

Evidence/call contracts: [Exploration.lua](../../Exploration.lua); [tests/exploration_spec.lua](../../tests/exploration_spec.lua).

## Frames.lua

### `c71ed8923d` — dismissed

Source: `final-20260930-prod-bags-dup.json`, item 7 (zero-based); lens `stringly-typed`; `Frames.lua:641`.

Candidate: Window identity by frame-name literal: "AdventureGuideForeverWindow" at Frames.lua:40, 351, 641, 876 and addon literal "AdventureGuideForever" at :40 and :778; "CharacterFrame" (:335) and "WorldMapFrame" (:302, 340) special cases likewise, while windows entries are positional tuples read as window[1], [2], [3].

```text
		if record.name == "AdventureGuideForeverWindow" then
```

Verdict: Install translates the external window tuples into TFWindowRecord objects; record.name resolves _G and distinguishes externally named AdventureGuide/Character/WorldMap host frames. Those names are external frame identity and load-order contracts, not an internal closed enum, and the account/preset/GUID layout keys are expressly Settled persisted data.

Evidence/call contracts: [Frames.lua](../../Frames.lua); [types/Frames.lua](../../types/Frames.lua); [tests/frames_runtime_spec.lua](../../tests/frames_runtime_spec.lua); [.agents/skills/sift-project/SKILL.md](../../.agents/skills/sift-project/SKILL.md).

### `f7e29cd4cb` — dismissed

Source: `final-20260930-prod-bags-dup.json`, item 9 (zero-based); lens `oversized-modules`; `Frames.lua:658`.

Candidate: Frames.lua (905 lines) mixes: window model and queue (43-187), placement/apply (189-321), preview geometry (323-377), Windows-tab editor UI (392-753, BuildEditor alone 96 lines at 658-753), and Edit Mode lifecycle/install (755-905); RefreshPreview (:324-377) branches per window name.

```text
local function BuildEditor()
```

Verdict: The placement queue, per-window preview and Windows editor share TFWindowRecord geometry and the same saved layout/combat scheduling lifecycle. BuildEditor creates one editor for that lifecycle; RefreshPreview's named-frame special cases implement external window geometry. The file length does not establish two unrelated subsystems, and splitting it would introduce exports/TOC ordering without a demonstrated contract benefit.

Evidence/call contracts: [Frames.lua](../../Frames.lua); [types/Frames.lua](../../types/Frames.lua); [tests/frames_runtime_spec.lua](../../tests/frames_runtime_spec.lua); [tests/frames_spec.lua](../../tests/frames_spec.lua).

### `57bd492290` — dismissed

Source: `final-20260930-prod-bags-text.json`, item 0 (zero-based); lens `defensive-noise`; `Frames.lua:446`.

Candidate: `not manager` guard in SyncLayouts

```text
	if not manager or not manager.layoutInfo then
```

Verdict: Init can register ADDON_LOADED before EditModeManagerFrame exists; Install then returns, but Schedule -> RefreshAll -> SyncLayouts still runs. A fresh production-module absence probe passes with this guard and errors at Frames.lua:446 when not manager is deleted. The subsequent layoutInfo check does not cover missing manager.

Evidence/call contracts: [Frames.lua](../../Frames.lua); [tests/frames_runtime_spec.lua](../../tests/frames_runtime_spec.lua); [followup-probes-corrected.json](../runs/evidence/codex-final-20260930/followup-probes-corrected.json).

### `1bfe71b336` — dismissed

Source: `final-20260930-prod-bags-text.json`, item 3 (zero-based); lens `comment-narration`; `Frames.lua:15`.

Candidate: version-pinned claim about another addon plus shouted 'NOT' on the next line

```text
-- Leatrix Plus 1.60.04-forever has no window-moving option (its old FrmEnabled setting is absent).
```

Verdict: The comment explains why Leatrix Plus is deliberately absent from moveWindows conflicts even though other addons are listed, and why the feature must not hook Blizzard placement methods. Install/Place use engine geometry calls and secure event ordering; this upstream-version compatibility rationale is not a narration of an implementation session.

Evidence/call contracts: [Frames.lua](../../Frames.lua); [tests/frames_runtime_spec.lua](../../tests/frames_runtime_spec.lua); [AGENTS.md](../../AGENTS.md).

## Gear.lua

### `19bace02a8` — unproven

Source: `carried ledger`; lens `silent-fallbacks`; `Gear.lua:236`; carried from active ledger.

Candidate: An item whose inventory type is not in SLOTS (e.g. INVTYPE_BAG, INVTYPE_AMMO, INVTYPE_QUIVER) is silently left out of the equip plan

```text
for _, slot in ipairs(SLOTS[loc] or {}) do
```

Verdict: OpenItemMenu admits any nonempty equipLoc, while Model.Plan ignores kinds absent from SLOTS. Stubbed bag/ammo/quiver rows show the gap, but the actual Forever bag item equipLoc and intended grouping support remain unestablished. Settle with those host item values and a group/equip trace before restricting admission or changing slot planning.

Evidence/call contracts: [Gear.lua](../../Gear.lua); [tests/gear_spec.lua](../../tests/gear_spec.lua); [types/Forever.lua](../../types/Forever.lua).

### `4d200de465` — unproven

Source: `final-20260930-prod-bags-dup.json`, item 1 (zero-based); lens `reinvented-wheel`; `Gear.lua:382`; carried from active ledger.

Candidate: Coloured() hand-formats a |cffRRGGBB escape from 0-1 floats; the client provides CreateColor(r, g, b):WrapTextInColorCode(text) (Settings.lua:23 already uses RED_FONT_COLOR:WrapTextInColorCode) and ConvertRGBtoColorString.

```text
		"|cff%02x%02x%02x%s|r",
```

Verdict: Coloured floors each float*255 before formatting; ColorMixin delegates the byte conversion to native C_ColorUtil. The model/specs establish current escapes, not the host's rounding and clipping. Settle with a Forever native-vs-current output comparison for fractional and boundary channels; this is the same carried item 4d200de465.

Evidence/call contracts: [Gear.lua](../../Gear.lua); [tests/gear_spec.lua](../../tests/gear_spec.lua); [initial-ledger.json](../runs/evidence/codex-final-20260930/initial-ledger.json).

### `abd358325f` — confirmed

Source: `final-20260930-prod-bags-dup.json`, item 3 (zero-based); lens `parallel-implementations`; `Gear.lua:348`.

Candidate: The closed set of list kinds group/set/fishing is restated in KINDS (Gear.lua:88), EQUIP (:348), Lists() (:350-352), Colour()'s set special case (:357) and Coloured({ kind = "group" }) (:644); each is a separate table or branch keyed by the same literals.

```text
local EQUIP = { group = EquipGroup, set = EquipSet, fishing = EquipBeforeFishing }
```

Verdict: Lists creates group/set/fishing providers while KINDS drives enumeration and EQUIP independently dispatches those same kinds. Persisted kind spellings must remain stable (Settled), but persistence does not require these three operational inventories to be maintained separately: a missing provider or dispatcher can diverge from KINDS. A canonical descriptor can retain the wire keys and their different equip functions. Hot file; report only.

Evidence/call contracts: [Gear.lua](../../Gear.lua); [types/Namespace.lua](../../types/Namespace.lua); [tests/gear_spec.lua](../../tests/gear_spec.lua); [.agents/skills/sift-project/SKILL.md](../../.agents/skills/sift-project/SKILL.md).

### `0bdda8e4b6` — dismissed

Source: `final-20260930-prod-bags-dup.json`, item 4 (zero-based); lens `parallel-implementations`; `Gear.lua:330`.

Candidate: EquipBeforeFishing (:329-338) re-sorts its plan by slot with the same comparator as the tail of Model.Plan (:248-250).

```text
	local plan = {}

```

Verdict: Model.Plan builds an item-location-to-equipment assignment with duplicate/two-handed-slot rules; EquipBeforeFishing converts the saved equipment-slot restoration map to a list. The common three-line sort establishes numeric slot order, while plan construction and ownership differ. This is a small idiom, not a second assignment algorithm.

Evidence/call contracts: [Gear.lua](../../Gear.lua); [tests/gear_spec.lua](../../tests/gear_spec.lua).

### `9da376fe4f` — decide

Source: `final-20260930-prod-bags-dup.json`, item 8 (zero-based); lens `oversized-modules`; `Gear.lua:589`.

Candidate: OpenMenu (Gear.lua:589-671, 83 lines) creates the panel frame and scroll child (:590-612), pools rows (:617-637 with the nested Add closure), then builds the group, new-group, equip and colour rows (:638-667). It also recurses through its own callbacks (:646, :652).

```text
local function OpenMenu(button, itemID)
```

Verdict: OpenMenu allocates the persistent panel only once, then reuses GearRow pools while rebuilding current-item rows. The allocation and per-open content phases are concrete distinct lifecycles, although their callbacks intentionally close over the current item. Owner question: extract the one-time panel factory while retaining the pooled row/content flow? An architectural split in this hot file is outside automatic audit cleanup.

Evidence/call contracts: [Gear.lua](../../Gear.lua); [tests/gear_ui_spec.lua](../../tests/gear_ui_spec.lua).

### `a8bb99620f` — confirmed

Source: `final-20260930-prod-bags-reach.json`, item 0 (zero-based); lens `session-residue`; `Gear.lua:568`.

Candidate: gearItem is a module upvalue that duplicates OpenMenu's itemID parameter (left over from the MenuUtil-to-panel rewrite)

```text
local gearPanel, gearScroll, gearContent, gearRows, gearItem, gearTitle
```

Verdict: Every pooled row receives a new OnClick closure on each OpenMenu; those closures can capture that invocation's itemID rather than the module gearItem written at the start. The isolated replacement preserves membership, creation and reopened-menu tests. NewGroup's saved popup callback already captures itemID, so it does not justify this duplicate mutable upvalue. Hot file; no edit.

Evidence/call contracts: [Gear.lua](../../Gear.lua); [tests/gear_ui_spec.lua](../../tests/gear_ui_spec.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `fc29bb5d63` — confirmed

Source: `final-20260930-prod-bags-reach.json`, item 1 (zero-based); lens `speculative-abstraction`; `Gear.lua:552`.

Candidate: onCreated is an optional callback (unannotated, nil-guarded) but NewGroup has one caller, which always passes it

```text
local function NewGroup(itemID, onCreated)
```

Verdict: NewGroup is local and has one caller: the New group row always supplies its reopen closure. Removing only the nil guard in a temporary module preserves creation/reopen tests; no manifest or available branch exports a callback-optional contract. The optional case is unsupported scaffolding, not a public API. Hot file.

Evidence/call contracts: [Gear.lua](../../Gear.lua); [tests/gear_ui_spec.lua](../../tests/gear_ui_spec.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json); [branch-symbol-evidence.json](../runs/evidence/codex-final-20260930/branch-symbol-evidence.json).

### `3083c10497` — confirmed

Source: `final-20260930-prod-bags-text.json`, item 2 (zero-based); lens `defensive-noise`; `Gear.lua:152`.

Candidate: `lists[kind] or {}` in GroupsOf

```text
			for name, items in pairs(lists[kind] or {}) do
```

Verdict: Lists always returns all three kind maps and GroupsOf is called with that producer; each map is nonoptional in the addon-owned path. Removing or {} in a temporary module preserves gear_spec. This is not the settled nil-safe saved-root access: persistence is normalized by Lists before iteration. Hot file.

Evidence/call contracts: [Gear.lua](../../Gear.lua); [types/Namespace.lua](../../types/Namespace.lua); [tests/gear_spec.lua](../../tests/gear_spec.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

## Junk.lua

### `9bace02611` — dismissed

Source: `carried ledger`; lens `reinvented-wheel`; `Junk.lua:old anchor absent`; carried from active ledger.

Candidate: The gold tooltip colour is written as the literal 1, 0.82, 0 here, at Junk.lua:376 and at Gear.lua:649. That is NORMAL_FONT_COLOR, which every other tooltip and label colour in the addon takes from the named global (Nameplates.lua:63, Tooltips.lua:388, QuestProgress.lua:233, Campsites.lua via *_FONT_COLOR:GetRGB())

```text
tooltip:AddLine(L["Marked as junk – Alt+Right-click to unmark"], 1, 0.82, 0, true)
```

Verdict: Same producer as acfb94b73a: the old quote no longer matches after punctuation changed, but Junk's RGB tuple still exists. This is not fixed; the canonical gold-helper substitution remains unproven pending Forever's actual NORMAL_FONT_COLOR green channel.

Evidence/call contracts: [Junk.lua](../../Junk.lua); [Gear.lua](../../Gear.lua); [initial-ledger.json](../runs/evidence/codex-final-20260930/initial-ledger.json).

Canonical producer: `acfb94b73a` (its verdict remains separately recorded).

### `acfb94b73a` — unproven

Source: `final-20260930-prod-bags-dup.json`, item 0 (zero-based); lens `reinvented-wheel`; `Junk.lua:366`.

Candidate: Gold wrapped tooltip line spelled as AddLine(text, 1, 0.82, 0, true) at Junk.lua:366 and :376 and Gear.lua:715; the client's GameTooltip_AddNormalLine(tooltip, text, wrap) (already whitelisted in .luacheckrc and used by Modes.lua:124) or NORMAL_FONT_COLOR does this.

```text
			tooltip:AddLine(L["Marked as junk. Alt+Right-click to unmark."], 1, 0.82, 0, true)
```

Verdict: Junk and Gear use green 0.82 in these wrapped gold lines, whereas the pinned NORMAL_FONT_COLOR annotation says 0.824. GameTooltip_AddNormalLine preserves wrapping but delegates color to that host global. Settle with Forever's actual RGB and emitted tooltip color before claiming the replacement preserves behavior; the old 9bace02611 quote changed punctuation but the color producer remains.

Evidence/call contracts: [Junk.lua](../../Junk.lua); [Gear.lua](../../Gear.lua); [Modes.lua](../../Modes.lua); [.types/vscode-wow-api/Annotations/Core/Type/GlobalColors.lua](../../.types/vscode-wow-api/Annotations/Core/Type/GlobalColors.lua); [initial-ledger.json](../runs/evidence/codex-final-20260930/initial-ledger.json).

### `e3338b6705` — unproven

Source: `final-20260930-prod-bags-dup.json`, item 2 (zero-based); lens `reinvented-wheel`; `Junk.lua:384`.

Candidate: Walks StaticPopup1..N by probing _G names until one is nil; the client's STATICPOPUP_NUMDIALOGS gives the dialog count (for index = 1, STATICPOPUP_NUMDIALOGS) and StaticPopup_ForEachShownDialog exists for shown ones.

```text
	while _G["StaticPopup" .. index] do
```

Verdict: These hooks must attach to pre-created hidden StaticPopup frames before the later delete confirmation appears; ForEachShownDialog would omit them. A count loop is equivalent only if Forever's STATICPOPUP_NUMDIALOGS matches a contiguous initialized StaticPopup1..N population. Neither the allowlist nor headless tests proves that host initialization contract; capture it in the client before replacing the discovery loop.

Evidence/call contracts: [Junk.lua](../../Junk.lua); [tests/junk_spec.lua](../../tests/junk_spec.lua); [types/Forever.lua](../../types/Forever.lua).

### `f0429fa44f` — dismissed

Source: `final-20260930-prod-bags-dup.json`, item 5 (zero-based); lens `parallel-implementations`; `Junk.lua:212`.

Candidate: Scan pre-filters on hasNoValue and isLocked, which Model.SaleValue (Junk.lua:83-84) checks again a few lines later; UpdateIcon (:149) repeats hasNoValue for the grey coin.

```text
			if info and Model.IsJunk(info, marks, includeGreys) and not info.hasNoValue and not info.isLocked then
```

Verdict: Scan must exclude locked and hasNoValue items before querying sell price and deciding whether missing prices set pending; Step/SaleValue re-check eligibility before acting on a changed bag. Removing Scan's filter would turn worthless/locked items into pending price retries; UpdateIcon uses hasNoValue to indicate no sale value, independently of automation. These are different temporal and UI contracts, explicitly Settled for Junk safety.

Evidence/call contracts: [Junk.lua](../../Junk.lua); [tests/junk_spec.lua](../../tests/junk_spec.lua); [.agents/skills/sift-project/SKILL.md](../../.agents/skills/sift-project/SKILL.md).

### `70cae2b7cf` — dismissed

Source: `final-20260930-prod-bags-dup.json`, item 6 (zero-based); lens `parallel-implementations`; `Junk.lua:122`.

Candidate: Button to (bag, slot) to item lookup restated: Junk.Info (:122), Gear.UpdateMarks (Gear.lua:491), Core.lua:197, Modes.lua:26/31/51, Sections.lua:91 each pair button:GetBagID(), button:GetID() by hand.

```text
	return C_Container.GetContainerItemInfo(button:GetBagID(), button:GetID())
```

Verdict: Info obtains a full mutable item record for Junk eligibility, while Gear/Sections/Modes obtain the ID for membership or click selection. Core.BagItems is an iterator over an existing container, not a button lookup. The repeated two-host-call idiom has no independent business implementation to consolidate, and the project settles Gear/Junk guards as different contracts.

Evidence/call contracts: [Core.lua](../../Core.lua); [Junk.lua](../../Junk.lua); [Gear.lua](../../Gear.lua); [Sections.lua](../../Sections.lua); [Modes.lua](../../Modes.lua); [.agents/skills/sift-project/SKILL.md](../../.agents/skills/sift-project/SKILL.md).

### `dea98d1eb2` — dismissed

Source: `final-20260930-prod-bags-text.json`, item 1 (zero-based); lens `defensive-noise`; `Junk.lua:212`.

Candidate: `not info.hasNoValue and not info.isLocked` repeated before SaleValue

```text
				if info and Model.IsJunk(info, marks, includeGreys) and not info.hasNoValue and not info.isLocked then
```

Verdict: Same producer as f0429fa44f: Scan filters before price/pending discovery; SaleValue revalidates immediately before selling. Deleting this early predicate changes retry scheduling for locked/no-value items, rather than merely removing a redundant validation.

Evidence/call contracts: [Junk.lua](../../Junk.lua); [tests/junk_spec.lua](../../tests/junk_spec.lua).

Canonical producer: `f0429fa44f` (its verdict remains separately recorded).

### `bc3c792ac1` — dismissed

Source: `final-20260930-prod-bags-text.json`, item 4 (zero-based); lens `comment-narration`; `Junk.lua:382`.

Candidate: history of a rejected alternative inside a why-comment

```text
-- confirmation Blizzard shows. Enter does not accept this dialog, so the button is the only way.
```

Verdict: Junk attaches only to the delete confirmation's accept button and uses the captured pending item callback; the comment explains why Enter and a generic native-popup accept hook do not supply that safe event path. The rejected alternative documents a secure UI constraint still imposed by the code, not just historical work.

Evidence/call contracts: [Junk.lua](../../Junk.lua); [tests/junk_spec.lua](../../tests/junk_spec.lua); [AGENTS.md](../../AGENTS.md).

## QuestDistance.lua

### `499b617fb1` — unproven

Source: `carried ledger`; lens `defensive-noise`; `QuestDistance.lua:289`; carried from active ledger.

Candidate: BUG: the position is used without the canaccessvalue check Campsites needs for the same call

```text
local y, x = UnitPosition("player")
```

Verdict: The QuestDistance ticker does arithmetic on UnitPosition returns; Campsites treats secret values as a possibility, but pinned annotations do not establish that Forever returns secrets here. No host was driven. Settle with a /reload/movement trace in a restricted instance, including canaccessvalue results and the ticker behavior.

Evidence/call contracts: [QuestDistance.lua](../../QuestDistance.lua); [Campsites.lua](../../Campsites.lua); [types/Forever.lua](../../types/Forever.lua); [tests/questdistance_spec.lua](../../tests/questdistance_spec.lua).

### `a0fa41077b` — dismissed

Source: `carried ledger`; lens `defensive-noise`; `QuestDistance.lua:86`; carried from active ledger.

Candidate: existence guard on C_SuperTrack, which this client always has

```text
local super = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID()
```

Verdict: The claimed later unguarded C_SuperTrack calls are inside if super and ..., so the initial namespace guard also gates those calls. questdistance_spec omits C_SuperTrack and successfully initializes/ticks the production feature; a separate Navigate caller does not establish namespace availability in this lifecycle. This concrete short-circuit path disproves redundancy.

Evidence/call contracts: [QuestDistance.lua](../../QuestDistance.lua); [tests/questdistance_spec.lua](../../tests/questdistance_spec.lua); [Navigate.lua](../../Navigate.lua).

### `ebc740c99b` — dismissed

Source: `final-20260930-prod-quest-dup.json`, item 3 (zero-based); lens `parallel-implementations`; `QuestDistance.lua:74`.

Candidate: Iteration over watched quest IDs (GetNumQuestWatches + GetQuestIDForQuestWatchIndex + nil check) is written in CreateAreaProbe.CheckAreas (QuestDistance.lua:120-122) and in SortNearest (74-76).

```text
		for i = 1, C_QuestLog.GetNumQuestWatches() do
```

Verdict: SortNearest computes distances and removes/re-adds watches to change ordering; CheckAreas probes quest map areas and schedules a redraw when the player enters one. The common GetNumQuestWatches loop is only host enumeration, with different effects and callback lifetimes.

Evidence/call contracts: [QuestDistance.lua](../../QuestDistance.lua); [tests/questdistance_spec.lua](../../tests/questdistance_spec.lua).

### `6b57abd1c7` — dismissed

Source: `final-20260930-prod-quest-text.json`, item 2 (zero-based); lens `comment-narration`; `QuestDistance.lua:68`.

Candidate: four-line comment that is hard to parse ('as a manual watch, all Forever's AddQuestWatch makes')

```text
-- The client's SortQuestWatches leaves manual watches where they are, and every watch here is manual, so the order is
```

Verdict: The comment explains why native SortQuestWatches cannot produce this order and why manual watches must be removed and re-added in reverse proximity order while restoring supertracking. SortNearest and the watch-order tests implement those nonobvious host side effects; awkward grammar does not turn this still-relevant why-comment into narration.

Evidence/call contracts: [QuestDistance.lua](../../QuestDistance.lua); [tests/questdistance_spec.lua](../../tests/questdistance_spec.lua).

## QuestGivers.lua

### `b8e177d815` — dismissed

Source: `final-20260930-prod-quest-dup.json`, item 4 (zero-based); lens `parallel-implementations`; `QuestGivers.lua:367`.

Candidate: Three player-position readers: QuestGivers Here() (world x,y via GetBestMapForUnit/GetPlayerMapPosition/GetWorldPosFromMapPos, QuestGivers.lua:367), Campsites Here() (UnitPosition with canaccessvalue guards, Campsites.lua:277), and QuestDistance's inline UnitPosition (QuestDistance.lua:289) plus its own C_Map position read (111).

```text
local function Here()
```

Verdict: Giver Here converts a normalized C_Map point to world yards/map; camp Here uses guarded UnitPosition for aura proximity; the distance ticker uses instance-position movement plus a separate map-area probe. Coordinate spaces, return order and secret handling differ, so a shared reader would change contracts. The potentially secret ticker values remain separately unproven as 499b617fb1.

Evidence/call contracts: [QuestGivers.lua](../../QuestGivers.lua); [Campsites.lua](../../Campsites.lua); [QuestDistance.lua](../../QuestDistance.lua); [initial-ledger.json](../runs/evidence/codex-final-20260930/initial-ledger.json).

## QuestLog.lua

### `8fca8db2e6` — dismissed

Source: `final-20260930-prod-quest-text.json`, item 0 (zero-based); lens `defensive-noise`; `QuestLog.lua:101`.

Candidate: QuestScrollFrame and its titleFramePool are guarded here but used unguarded in the same Init

```text
		if QuestScrollFrame and QuestScrollFrame.titleFramePool then
```

Verdict: QuestScrollFrame can exist while titleFramePool has not been initialized; the rest of Init uses the scroll frame's geometry, not the pool. questlog_spec runs with a frame mock lacking titleFramePool and exercises selection/confirmation. Guarding that optional host member is a load-order trust boundary; unguarded frame methods do not prove the pool exists.

Evidence/call contracts: [QuestLog.lua](../../QuestLog.lua); [tests/questlog_spec.lua](../../tests/questlog_spec.lua); [types/Forever.lua](../../types/Forever.lua).

## QuestProgress.lua

### `5f598c7987` — dismissed

Source: `final-20260930-prod-quest-dup.json`, item 0 (zero-based); lens `parallel-implementations`; `QuestProgress.lua:184`.

Candidate: Model.Rebuild walks the quest log and filters headers and hidden entries (QuestProgress.lua:184-186), the same walk as QuestLog.lua Model.Entries (QuestLog.lua:26-35, the jscpd clone). Canonical home: QuestLog Model.Entries (loaded after QuestProgress in the TOC, so it would need to move earlier or into Core).

```text
	for index = 1, C_QuestLog.GetNumQuestLogEntries() do
```

Verdict: QuestLog.Entries produces selectable quest rows and excludes disabled/abandon-ineligible entries downstream; QuestProgress.Rebuild collects objective metadata and Questie target state for all usable log entries. Their shared header/hidden iteration is a small host API idiom, while substituting the selectable rows would change progress coverage and TOC ownership. No second objective-rebuild algorithm exists.

Evidence/call contracts: [QuestLog.lua](../../QuestLog.lua); [QuestProgress.lua](../../QuestProgress.lua); [TweaksForever.toc](../../TweaksForever.toc); [tests/questlog_spec.lua](../../tests/questlog_spec.lua); [tests/questprogress_spec.lua](../../tests/questprogress_spec.lua).

### `fba8914d40` — dismissed

Source: `final-20260930-prod-quest-dup.json`, item 1 (zero-based); lens `parallel-implementations`; `QuestProgress.lua:375`.

Candidate: The tooltip-post-call tail 'for each {text,r,g,b} line AddLine; if #lines > 0 then tooltip:Show()' is written twice: QuestProgress.lua:374-379 and QuestGivers.lua:448-453. Both features also build the same {text,r,g,b} line tuples (Model.Lines in each, plus the same GetQuestDifficultyColor/GRAY/HIGHLIGHT colour unpacking).

```text
			tooltip:AddLine(line[1], line[2], line[3], line[4])
```

Verdict: The repeated four-line AddLine/Show tail only adapts each model's line tuples to the host tooltip. Giver availability/details and active objective progress have different data builders and suppression contracts; sharing this tiny host idiom would not consolidate their business algorithms.

Evidence/call contracts: [QuestProgress.lua](../../QuestProgress.lua); [QuestGivers.lua](../../QuestGivers.lua); [tests/questprogress_spec.lua](../../tests/questprogress_spec.lua); [tests/questgivers_spec.lua](../../tests/questgivers_spec.lua).

### `6065c3d194` — dismissed

Source: `final-20260930-prod-quest-dup.json`, item 5 (zero-based); lens `stringly-typed`; `QuestProgress.lua:133`.

Candidate: Npcs() branches on the numeric group.slot (1 monster, 3 item) while GROUPS also carries a symbolic kind and a credit flag; kind strings 'monster','object','item','reputation','spell','event' are compared as literals (GROUPS, Targets' 'event', Matches against objective.type).

```text
		elseif group.slot == 1 then
```

Verdict: group.slot is the external Questie objective tuple position (monster 1, drops 3, event credit 5), and kind matches external objective.type. Npcs must distinguish direct monster IDs, item-drop lookup and credited monster rows; GROUPS carries that boundary mapping centrally. Renaming raw wire keys into an internal enum does not remove the forced numeric tuple contract.

Evidence/call contracts: [QuestProgress.lua](../../QuestProgress.lua); [types/Forever.lua](../../types/Forever.lua); [tests/questprogress_spec.lua](../../tests/questprogress_spec.lua).

### `d7b64e4336` — dismissed

Source: `final-20260930-prod-quest-text.json`, item 1 (zero-based); lens `defensive-noise`; `QuestProgress.lua:186`.

Candidate: info.questID nil-check and ~= 0 on a QuestInfo entry read by a valid log index

```text
		if info and not info.isHeader and not info.isHidden and info.questID and info.questID ~= 0 then
```

Verdict: GetInfo is a host boundary: header/hidden rows and rows without a valid quest ID are allowed. Rebuild uses the ID as the Questie cache key and objective lookup; rejecting nil/0 narrows the optional QuestInfo field before those operations. A valid log index guarantees a row position, not a positive quest identity.

Evidence/call contracts: [QuestProgress.lua](../../QuestProgress.lua); [types/Forever.lua](../../types/Forever.lua); [tests/questprogress_spec.lua](../../tests/questprogress_spec.lua).

## QuestiePins.lua

### `fe61e24e41` — dismissed

Source: `final-20260930-prod-quest-dup.json`, item 6 (zero-based); lens `stringly-typed`; `QuestiePins.lua:66`.

Candidate: Questie pin types are bare numbers: ATLASES keys 1-17 and the magic 7 here (the greyed 'available but locked' type, shared with atlas 'questnormal' with 6 and 15).

```text
		local shade = kind == 7 and 0.55 or 1
```

Verdict: ATLASES translates Questie's external pin type protocol into addon artwork; 7 is the source protocol's unavailable quest marker and receives grey tint even though its atlas is shared with other types. The numbered keys are external wire IDs, not an internal closed set invented by this feature.

Evidence/call contracts: [QuestiePins.lua](../../QuestiePins.lua); [types/Forever.lua](../../types/Forever.lua); [tests/questiepins_spec.lua](../../tests/questiepins_spec.lua).

## README.md

### `c09bb628e1` — decide

Source: `final-20260930-config-docs-text.json`, item 11 (zero-based); lens `stale-docs`; `README.md:125`.

Candidate: 'Works alongside' table says a feature steps aside while one of these is loaded, but omits Highlight new Forever quests

```text
| Fishing | FishingBuddy, FishingAce |
```

Verdict: QuestLog.lua declares ForeverQuestTint and ForeverQuestTracker conflicts for highlightForever; README's Works alongside table does not name either although it presents the addons this feature steps aside for. Owner question: add a Highlight new Forever quests row naming both conflicts? This is player-facing factual coverage under WFA-1.

Evidence/call contracts: [README.md](../../README.md); [QuestLog.lua](../../QuestLog.lua).

### `abe71595a9` — unproven

Source: `final-20260930-standards-std.json`, item 1 (zero-based); lens `standards`; `README.md:27`.

Candidate: WFA-10: README is over the 1,200-word budget (about 1,290 words of prose with markup and link targets stripped, 1,479 raw)

```text
## Features
```

Verdict: The independent prose count is 1187 after removing fenced commands, HTML tags and link targets, contradicting the reviewer's approximately 1290 prose claim. Including visible command/code material gives 1236; WFA-10 gives no counting convention. Settle the pack's treatment of code/tables before reporting a budget violation or shortening player-facing copy.

Evidence/call contracts: [README.md](../../README.md); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json); [token-and-freshness-probes.json](../runs/evidence/codex-final-20260930/token-and-freshness-probes.json); [standards reviewer notes](../runs/final-20260930-standards-std.json).

### `6767e4e38b` — decide

Source: `final-20260930-standards-std.json`, item 2 (zero-based); lens `standards`; `README.md:31`.

Candidate: WFA-25: quests.png has no line under it saying what to look at

```text
<img src="https://raw.githubusercontent.com/cjber/tweaks-forever/main/docs/screenshots/quests.png" width="442" alt="Abandon quests checklist with three quests selected and a confirmation warning">
```

Verdict: The text directly below quests.png states general abandon/checklist behavior but does not direct attention to the pictured selected quests and confirmation warning; the preceding introduction is above the image. Owner question: add a plain caption naming the selected checklist and confirmation shown, as WFA-25 requires?

Evidence/call contracts: [README.md](../../README.md); [QuestLog.lua](../../QuestLog.lua); [tests/questlog_spec.lua](../../tests/questlog_spec.lua).

### `33ae03faad` — decide

Source: `final-20260930-standards-std.json`, item 3 (zero-based); lens `standards`; `README.md:40`.

Candidate: WFA-9: README omits gear.png and zonelevels.png, which docs/curseforge.md shows (and curseforge.md omits quests.png)

```text
- **Gear groups.** **Ctrl+Right-click** a bag item to put it in a named, coloured group, then equip the whole group in one click. With Combine Bags on, grouped gear sits together at the top.
```

Verdict: The two local published-copy sources use different screenshot sets: README lacks gear.png/zonelevels.png and store copy lacks quests.png. WFA-9 requires the README/store/gallery set to agree; proving the local mismatch does not require accessing the gallery. Owner question: choose one shared set and make both documents use it, then check the external gallery?

Evidence/call contracts: [README.md](../../README.md); [docs/curseforge.md](../../docs/curseforge.md); [docs/screenshots](../../docs/screenshots).

## Reload.lua

### `9080074ad6` — dismissed

Source: `final-20260930-prod-core-dup.json`, item 3 (zero-based); lens `stringly-typed`; `Reload.lua:6`.

Candidate: Feature category is a bare string repeated in every ns.Feature (Interface x21, Automation x7, Vendors x5, Fishing x4, Gear x4, Maps x3 across files) and grouped by literal in Settings.lua:76-82 and translated via L[section]

```text
	category = "Interface",
```

Verdict: TFFeature.category is an open registration string; Settings groups whatever categories ns.Feature supplies and translates L[section]. The current six category names are UI copy, not a closed operational state machine; test registrations can supply additional groups. An enum would narrow the supported registration contract.

Evidence/call contracts: [Core.lua](../../Core.lua); [Settings.lua](../../Settings.lua); [Reload.lua](../../Reload.lua); [types/Namespace.lua](../../types/Namespace.lua); [tests/settings_spec.lua](../../tests/settings_spec.lua).

## Sections.lua

### `abb7ffab5b` — dismissed

Source: `final-20260930-prod-ui-dup.json`, item 2 (zero-based); lens `parallel-implementations`; `Sections.lua:91`.

Candidate: 'item ID held by a bag button' is restated at Sections.lua:91, Gear.lua:491 and Modes.lua:26 (button:GetBagID(), button:GetID() into GetContainerItemID). Core's ns.BagItems is the shared bag-button home (Core.lua:54).

```text
			local itemID = C_Container.GetContainerItemID(button:GetBagID(), button:GetID())
```

Verdict: Same producer as 70cae2b7cf: two bag-button accessors feed a host ID lookup, whereas ns.BagItems iterates container contents. Sections then groups membership independently; sharing the two-call idiom would not consolidate that behavior.

Evidence/call contracts: [Sections.lua](../../Sections.lua); [Gear.lua](../../Gear.lua); [Modes.lua](../../Modes.lua); [Core.lua](../../Core.lua).

Canonical producer: `70cae2b7cf` (its verdict remains separately recorded).

## Spellbook.lua

### `ad19b7bccd` — dismissed

Source: `final-20260930-prod-ui-dup.json`, item 3 (zero-based); lens `parallel-implementations`; `Spellbook.lua:619`.

Candidate: Empty-rank-to-nil normalisation appears in Describe (Spellbook.lua:241) and ScanTrainer (619) for the same TFTrainerSpell.rank field

```text
					rank = rank ~= "" and rank or nil,
```

Verdict: Describe normalizes the spell API's empty subtext and ScanTrainer normalizes trainer service rank before constructing the shared row shape. Each must normalize its own optional host result, and the single expression is an API boundary idiom rather than a second ranking implementation.

Evidence/call contracts: [Spellbook.lua](../../Spellbook.lua); [types/Forever.lua](../../types/Forever.lua); [tests/spellbook_spec.lua](../../tests/spellbook_spec.lua).

### `231471b9cd` — confirmed

Source: `final-20260930-prod-ui-reach.json`, item 0 (zero-based); lens `speculative-abstraction`; `Spellbook.lua:290`.

Candidate: ns.OnGeneral is a one-caller wrapper (ScanTrainer) around Model.OnGeneral(ClassData().lines, lineID), exported on ns and typed in types/Namespace.lua with no reader in any other file, spec or branch

```text
function ns.OnGeneral(lineID)
```

Verdict: ns.OnGeneral is defined in Spellbook and called only once by its ScanTrainer path, forwarding unchanged arguments to Model.OnGeneral. Namespace annotations are not external consumers, and the published API exposes TrainableSpells/Trainers rather than this internal ns member. Full-ref search found no additional call site; Model.OnGeneral remains live in spellbook_spec.

Evidence/call contracts: [Spellbook.lua](../../Spellbook.lua); [types/Namespace.lua](../../types/Namespace.lua); [types/API.lua](../../types/API.lua); [tests/spellbook_spec.lua](../../tests/spellbook_spec.lua); [branch-symbol-evidence.json](../runs/evidence/codex-final-20260930/branch-symbol-evidence.json).

### `743f999135` — dismissed

Source: `final-20260930-prod-ui-text.json`, item 0 (zero-based); lens `comment-narration`; `Spellbook.lua:140`.

Candidate: history framing: describes old save format ('from before lines were kept by ID') rather than what the function does now

```text
-- Saves from before lines were kept by ID hold only the trainer's name for one: give each row its ID, and drop the
```

Verdict: The old localized-name saved rows are still accepted inputs to Model.Migrate and must be mapped to IDs in the current locale; unresolvable rows are discarded. The comment identifies the historical schema this migration consumes, not an obsolete coding session, and tests exercise the locale/weapon rejection contract.
