```text
manager.GetRegions = function()
```

Verdict: GetRegions only is the confirmed scope. The exercised manager layout/placement path never traverses manager art; its exact stub removal passes frames_runtime_spec. The broad IsSnapEnabled finding's other methods are recorded separately, preventing duplicate removals.

Evidence/call contracts: [tests/frames_runtime_spec.lua](../../tests/frames_runtime_spec.lua); [Frames.lua](../../Frames.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `a68a30a8ef` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 28 (zero-based); lens `dead-code`; `tests/frames_runtime_spec.lua:196`.

Candidate: manager.GetChildren stub never called

```text
manager.GetChildren = function() end
```

Verdict: GetChildren only is the confirmed scope. The fixture's conflict/layout path does not enumerate manager child art; its exact stub removal passes frames_runtime_spec. The broad IsSnapEnabled finding's other methods are recorded separately, preventing duplicate removals.

Evidence/call contracts: [tests/frames_runtime_spec.lua](../../tests/frames_runtime_spec.lua); [Frames.lua](../../Frames.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `fa6105c8af` — confirmed

Source: `final-20260930-tests-a-reach.json`, item 29 (zero-based); lens `dead-code`; `tests/frames_runtime_spec.lua:197`.

Candidate: methods.GetAlpha stub never called

```text
methods.GetAlpha = function()
```

Verdict: GetAlpha only is the confirmed scope. The exercised placement geometry reads scale/points, not frame alpha; its exact stub removal passes frames_runtime_spec. The broad IsSnapEnabled finding's other methods are recorded separately, preventing duplicate removals.

Evidence/call contracts: [tests/frames_runtime_spec.lua](../../tests/frames_runtime_spec.lua); [Frames.lua](../../Frames.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `ef3b9e5ba6` — dismissed

Source: `final-20260930-tests-a-reach.json`, item 30 (zero-based); lens `dead-code`; `tests/frames_runtime_spec.lua:274`.

Candidate: hooksecurefunc(ns, ...) wrapper never fires: ns.RefreshConflicts is never called, so old/fn wrapping is unexercised

```text
target[key] = function(...)
```

Verdict: hooksecurefunc is a host double that asserts the target is addon-owned ns and preserves prior-call-then-post-hook semantics. Frames registers a RefreshConflicts callback, and its ADDON_LOADED handler can later call that method; the wrapper models this real callback contract even though the current test trace does not execute it. This is supported host callback plumbing/security validation, not an invented optional feature.

Evidence/call contracts: [tests/frames_runtime_spec.lua](../../tests/frames_runtime_spec.lua); [Frames.lua](../../Frames.lua); [Core.lua](../../Core.lua); [types/Namespace.lua](../../types/Namespace.lua).

## tests/frames_spec.lua

### `3b2c08140d` — dismissed

Source: `final-20260930-tests-a-text.json`, item 4 (zero-based); lens `test-plumbing`; `tests/frames_spec.lua:18`.

Candidate: Restates the feature declaration's conflict list (addon names by index) rather than any behaviour.

```text
assert(features.moveWindows.conflicts[2].addon == "MoveAnything")
```

Verdict: Core.FindConflict consumes the declared addon list to grey/disable moveWindows. Accidentally dropping MoveAnything would run two window movers together; ordinary geometry model tests would not catch it. The indexed assertion protects the concrete coexistence/security contract, and frames_runtime separately tests conflict-driven placement.

Evidence/call contracts: [tests/frames_spec.lua](../../tests/frames_spec.lua); [Frames.lua](../../Frames.lua); [Core.lua](../../Core.lua); [tests/frames_runtime_spec.lua](../../tests/frames_runtime_spec.lua).

## tests/gear_spec.lua

### `be3f68cf45` — dismissed

Source: `final-20260930-tests-b-text.json`, item 1 (zero-based); lens `test-plumbing`; `tests/gear_spec.lua:13`.

Candidate: Restates the ns.Feature declaration's parent field (snapshot of configuration); only fails when the declaration is edited on purpose.

```text
assert(features.beforeFishing.parent == "gearGroups")
```

Verdict: beforeFishing.parent controls actual Settings greying and Core.Active dependency on gearGroups. A misspelled parent leaves a player-action feature independently enabled while the pure equip model still passes; the parent assertion is an executable public settings contract.

Evidence/call contracts: [tests/gear_spec.lua](../../tests/gear_spec.lua); [Gear.lua](../../Gear.lua); [Settings.lua](../../Settings.lua); [Core.lua](../../Core.lua).

## tests/gear_ui_spec.lua

### `9fdbc09fa9` — dismissed

Source: `final-20260930-tests-b-dup.json`, item 3 (zero-based); lens `parallel-implementations`; `tests/gear_ui_spec.lua:132`.

Candidate: gear_ui_spec.lua:132 and questgivers_spec.lua:149 each hand-write a strtrim host stub with different bodies (match vs two gsubs)

```text
	strtrim = function(text)
```

Verdict: Each strtrim fake supplies the host whitespace primitive to a standalone test. Match versus two gsubs is a tiny boundary idiom with the same exercised leading/trailing whitespace behavior; neither reimplements group creation or Questie matching. A shared trim helper has no production algorithm to centralize.

Evidence/call contracts: [tests/gear_ui_spec.lua](../../tests/gear_ui_spec.lua); [tests/questgivers_spec.lua](../../tests/questgivers_spec.lua); [Gear.lua](../../Gear.lua); [QuestGivers.lua](../../QuestGivers.lua).

### `f7e388fff0` — dismissed

Source: `final-20260930-tests-b-reach.json`, item 0 (zero-based); lens `dead-code`; `tests/gear_ui_spec.lua:63`.

Candidate: CloseButton stub on the panel template is read only by the spec's own assertion

```text
		f.CloseButton = { shown = true }
```

Verdict: Same producer as 968b54d2d8: the CloseButton field is observed by the test's own unsupported assertion, so deleting it alone fails. The canonical test-plumbing verdict targets that assertion/fixture island together and preserves the real panel visibility checks; do not count a second independent defect.

Evidence/call contracts: [tests/gear_ui_spec.lua](../../tests/gear_ui_spec.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

Canonical producer: `968b54d2d8` (its verdict remains separately recorded).

### `fe7c759984` — confirmed

Source: `final-20260930-tests-b-reach.json`, item 1 (zero-based); lens `dead-code`; `tests/gear_ui_spec.lua:17`.

Candidate: stub frame fields parent and template are stored and never read

```text
	local f = { kind = kind, parent = parent, template = template, scripts = {}, shown = true }
```

Verdict: The fake stores parent/template but production consumes its methods/kind/scripts and the spec never reads those two fields. Removing only their storage in a temporary spec preserves membership, pooling and keyboard coverage; retain the CreateFrame arguments/template contract at the call boundary.

Evidence/call contracts: [tests/gear_ui_spec.lua](../../tests/gear_ui_spec.lua); [Gear.lua](../../Gear.lua); [followup-probes-corrected.json](../runs/evidence/codex-final-20260930/followup-probes-corrected.json).

### `6770cf2f38` — confirmed

Source: `final-20260930-tests-b-reach.json`, item 2 (zero-based); lens `dead-code`; `tests/gear_ui_spec.lua:28`.

Candidate: SetPoint/ClearAllPoints/SetSize/SetHeight/SetWidth record point, width, height that no assertion reads

```text
		self.point = { ... }
```

Verdict: SetPoint/size methods are invoked but their stored point/width/height values are read by neither the fake's used methods nor assertions. The independent storage-only deletion preserves the spec; keep the callable methods needed by production. This finding is about unused recording, not proof that real panel geometry is correct.

Evidence/call contracts: [tests/gear_ui_spec.lua](../../tests/gear_ui_spec.lua); [Gear.lua](../../Gear.lua); [followup-probes-corrected.json](../runs/evidence/codex-final-20260930/followup-probes-corrected.json).

### `dc8842cf8a` — dismissed

Source: `final-20260930-tests-b-reach.json`, item 3 (zero-based); lens `dead-code`; `tests/gear_ui_spec.lua:85`.

Candidate: MenuUtil.CreateContextMenu stub is a tripwire for a collaborator Gear.lua no longer calls

```text
			error("native AcquireMenu path is forbidden")
```

Verdict: The MenuUtil double is a negative security regression tripwire for the real native AcquireMenu crash path. Reintroducing a native menu call inside OpenMenu immediately fails at the stub, with the Gear click call path in the trace. An uncalled error trap is the expected passing behavior, not dead scaffolding.

Evidence/call contracts: [tests/gear_ui_spec.lua](../../tests/gear_ui_spec.lua); [Gear.lua](../../Gear.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `968b54d2d8` — confirmed

Source: `final-20260930-tests-b-text.json`, item 0 (zero-based); lens `test-plumbing`; `tests/gear_ui_spec.lua:213`.

Candidate: CloseButton is the stub table { shown = true } the frame mock installs; nothing in the harness can ever set it false, so the second half cannot fail.

```text
assert(panel.shown and panel.CloseButton.shown, "stock close button stays available")
```

Verdict: Only panel.CloseButton.shown is unsupported: the mock assigns true and production never reads or changes that fake field. Changing fixture true to false fails with identical production, proving it tests setup rather than stock-template behavior. Preserve panel.shown and keyboard/pool assertions; actual stock close-button availability needs a host /reload check.

Evidence/call contracts: [tests/gear_ui_spec.lua](../../tests/gear_ui_spec.lua); [Gear.lua](../../Gear.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

## tests/junk_spec.lua

### `00422300f7` — dismissed

Source: `final-20260930-tests-b-text.json`, item 3 (zero-based); lens `test-plumbing`; `tests/junk_spec.lua:13`.

Candidate: Snapshot of Feature defaults plus the private shape #initializers == 1 on the next line; both restate the declaration.

```text
assert(features.markJunk.default == false and features.sellJunk.default == true)
```

Verdict: The quoted defaults protect actual policy: manual marking starts off and junk selling starts on. Pure sale-value/coin tests cannot catch a changed default. The adjacent private initializer-count weakness is a separate producer at 58c4cd7b26; preserve these public-default assertions.

Evidence/call contracts: [tests/junk_spec.lua](../../tests/junk_spec.lua); [Junk.lua](../../Junk.lua); [AGENTS.md](../../AGENTS.md).

Canonical producer: `58c4cd7b26` (its verdict remains separately recorded).

### `58c4cd7b26` — confirmed

Source: `final-20260930-tests-b-text.json`, item 4 (zero-based); lens `test-plumbing`; `tests/junk_spec.lua:14`.

Candidate: Asserts how many Init callbacks the file registers, then the spec runs initializers[1] blindly; a refactor splitting Init would break it without a defect.

```text
assert(#initializers == 1)
```

Verdict: A no-op initializer added before Junk's real callback fails only the exact count; removing that count and running all callbacks retains coin/hook behavior. Core.Init supports multiple callbacks, so the one-callback shape is private. Preserve default assertions and make the harness execute registered callbacks rather than depending on index one.

Evidence/call contracts: [tests/junk_spec.lua](../../tests/junk_spec.lua); [Junk.lua](../../Junk.lua); [Core.lua](../../Core.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

## tests/macronames_spec.lua

### `0a879e3b36` — confirmed

Source: `final-20260930-tests-b-reach.json`, item 4 (zero-based); lens `dead-code`; `tests/macronames_spec.lua:49`.

Candidate: env._G self-reference is never used

```text
env._G = env
```

Verdict: MacroNames' exercised initializer/event callbacks do not access env._G; deleting only the self-reference preserves all macro label assertions. It is separate from the needed env globals resolved through the metatable and from other specs with genuine _G lookups.

Evidence/call contracts: [tests/macronames_spec.lua](../../tests/macronames_spec.lua); [MacroNames.lua](../../MacroNames.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `c1cda24127` — confirmed

Source: `final-20260930-tests-b-text.json`, item 5 (zero-based); lens `test-plumbing`; `tests/macronames_spec.lua:52`.

Candidate: Snapshot of Feature fields (default, category) and private initializer count.

```text
assert(feature.default == false and feature.category == "Interface" and #initializers == 1)
```

Verdict: Only the initializer-count conjunct is confirmed: adding a no-op callback fails, and dropping that conjunct while retaining default/category and label behavior checks passes. Hide macro names off is an explicit waiver and Interface is player-visible settings placement; those contract checks remain.

Evidence/call contracts: [tests/macronames_spec.lua](../../tests/macronames_spec.lua); [MacroNames.lua](../../MacroNames.lua); [AGENTS.md](../../AGENTS.md); [final-probes.json](../runs/evidence/codex-final-20260930/final-probes.json).

## tests/questdistance_spec.lua

### `7b7ff76668` — dismissed

Source: `final-20260930-tests-b-dup.json`, item 4 (zero-based); lens `parallel-implementations`; `tests/questdistance_spec.lua:14`.

Candidate: same() re-implements an ordered array equality that other specs express as table.concat(x, ',') == '...' (questlog_spec.lua:91, gear_spec.lua:32, spellbook_spec.lua:36)

```text
local function same(a, b)
```

Verdict: same compares ordered array elements and length directly, whereas concat assertions serialize known simple fixtures for a readable expectation. Structural equality is needed for watch IDs/order and does not share a business operation with fixture formatting. This is a small test assertion idiom.

Evidence/call contracts: [tests/questdistance_spec.lua](../../tests/questdistance_spec.lua); [tests/questlog_spec.lua](../../tests/questlog_spec.lua); [tests/gear_spec.lua](../../tests/gear_spec.lua); [tests/spellbook_spec.lua](../../tests/spellbook_spec.lua).

## tests/questgivers_spec.lua

### `d893057730` — dismissed

Source: `final-20260930-tests-b-reach.json`, item 6 (zero-based); lens `dead-code`; `tests/questgivers_spec.lua:47`.

Candidate: values.n is set but production never reads it

```text
			local values = { n = #keys }
```

Verdict: Questie GetAll returns a packed tuple with n preserving arity through nil fields; types/Forever.lua documents that external shape. Current giver code indexes named positions without reading n, but removal would make the host double less faithful, especially for absent fields. The successful deletion probe proves current non-use, not that the external contract is invalid.

Evidence/call contracts: [tests/questgivers_spec.lua](../../tests/questgivers_spec.lua); [QuestGivers.lua](../../QuestGivers.lua); [types/Forever.lua](../../types/Forever.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `93264ad325` — confirmed

Source: `final-20260930-tests-b-text.json`, item 6 (zero-based); lens `test-plumbing`; `tests/questgivers_spec.lua:162`.

Candidate: Snapshot of the Feature default and private initializer count, restating the declaration.

```text
assert(features.giverTooltips.default == true and #initializers == 1)
```

Verdict: Only #initializers == 1 is confirmed: an extra no-op Giver callback fails it, and retaining the default assertion plus real tooltip/model tests without the count passes. The Questie dependency and default are public contracts; callback cardinality is not. Keep the real initializer execution.

Evidence/call contracts: [tests/questgivers_spec.lua](../../tests/questgivers_spec.lua); [QuestGivers.lua](../../QuestGivers.lua); [final-probes.json](../runs/evidence/codex-final-20260930/final-probes.json).

### `3f2255aa48` — dismissed

Source: `final-20260930-tests-b-text.json`, item 7 (zero-based); lens `test-plumbing`; `tests/questgivers_spec.lua:166`.

Candidate: Restates the needs.title string literal from the feature declaration.

```text
assert(needs.title == "QuestieDB")
```

Verdict: needs.title becomes Settings' user-visible missing-dependency label when QuestieDB attach fails. A wrong title still allows matching/model tests to pass but tells players the wrong prerequisite; this literal is the external dependency name/public copy contract, not private shape.

Evidence/call contracts: [tests/questgivers_spec.lua](../../tests/questgivers_spec.lua); [QuestGivers.lua](../../QuestGivers.lua); [Settings.lua](../../Settings.lua).

## tests/questlog_spec.lua

### `77a97641b8` — dismissed

Source: `final-20260930-tests-b-dup.json`, item 2 (zero-based); lens `parallel-implementations`; `tests/questlog_spec.lua:123`.

Candidate: Fake frame with SetShown/Hide/IsShown/SetScript/SetChecked stubs is rebuilt in questlog_spec.lua:103-162, questdistance_spec.lua:37-58 and gear_ui_spec.lua:16-73 (also auctionator_spec, frames_runtime_spec outside slice)

```text
function methods:SetShown(shown)
```

Verdict: QuestLog frames track selection/check state, QuestDistance frames drive visibility/hooks, and Gear frames record pooled button scripts/template panels. The same host method names have different state/event semantics and consumers. Sharing a frame emulator would introduce a test framework rather than unify a duplicated addon implementation.

Evidence/call contracts: [tests/questlog_spec.lua](../../tests/questlog_spec.lua); [tests/questdistance_spec.lua](../../tests/questdistance_spec.lua); [tests/gear_ui_spec.lua](../../tests/gear_ui_spec.lua); [QuestLog.lua](../../QuestLog.lua); [QuestDistance.lua](../../QuestDistance.lua); [Gear.lua](../../Gear.lua).

### `5140406495` — confirmed

Source: `final-20260930-tests-b-reach.json`, item 5 (zero-based); lens `dead-code`; `tests/questlog_spec.lua:52`.

Candidate: IsQuestDisabledForSession stub branch for id 105 is never exercised

```text
			return id == 105
```

Verdict: CanAbandon asks the fake disabled predicate for the fixture IDs, none of which is 105. Returning false unconditionally preserves every selection/confirmation assertion, demonstrating that the special disabled case is uncovered. Remove the unused branch or add a real disabled-quest fixture; this does not establish production's disabled guard is dead.

Evidence/call contracts: [tests/questlog_spec.lua](../../tests/questlog_spec.lua); [QuestLog.lua](../../QuestLog.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `77272243ba` — dismissed

Source: `final-20260930-tests-b-text.json`, item 12 (zero-based); lens `test-plumbing`; `tests/questlog_spec.lua:79`.

Candidate: Snapshot of three ids in the generated Data/ForeverQuests.lua; regenerating from a newer build can flip 92750/455 with no code defect, and nothing in QuestLog.lua/QuestLevels.lua is exercised by it.

```text
assert(ns.ForeverQuests[92750] and not ns.ForeverQuests[455] and not ns.ForeverQuests[9999999])
```

Verdict: These known Forever-added, classic and unknown IDs test the generated new-quest classification contract independently of QuestLog UI. gen_foreverquests consumes pinned Forever/classic CSV sets; a wrong set difference can produce valid Lua with the wrong classifications. This is data integrity, expressly exempt from test-plumbing.

Evidence/call contracts: [tests/questlog_spec.lua](../../tests/questlog_spec.lua); [tools/gen_foreverquests.py](../../tools/gen_foreverquests.py); [Data/ForeverQuests.lua](../../Data/ForeverQuests.lua); [QuestLog.lua](../../QuestLog.lua); [QuestLevels.lua](../../QuestLevels.lua).

## tests/questprogress_spec.lua

### `c4353ace8b` — dismissed

Source: `final-20260930-tests-b-dup.json`, item 0 (zero-based); lens `parallel-implementations`; `tests/questprogress_spec.lua:24`.

Candidate: questprogress_spec.lua:24-39 restates the QuestieDB entity stub (GetAll returning {n=#keys, row[key]...}) that questgivers_spec.lua:40-67 also builds

```text
local function Entity(rows)
```

Verdict: Giver Entity tracks reads and exposes giver detail/name key layouts; Progress Entity exposes objective/cache rows in a smaller host wire shape. The common packed GetAll stub implements Questie's interface, not either addon model's matching logic. Different fixture schemas and read-count assertions justify independent minimal doubles.

Evidence/call contracts: [tests/questgivers_spec.lua](../../tests/questgivers_spec.lua); [tests/questprogress_spec.lua](../../tests/questprogress_spec.lua); [QuestGivers.lua](../../QuestGivers.lua); [QuestProgress.lua](../../QuestProgress.lua); [types/Forever.lua](../../types/Forever.lua).

### `50bc404962` — dismissed

Source: `final-20260930-tests-b-dup.json`, item 1 (zero-based); lens `parallel-implementations`; `tests/questprogress_spec.lua:240`.

Candidate: questprogress_spec.lua:240-249 and questgivers_spec.lua:280-289 both build the same recording GameTooltip stub (AddLine appends to added, Show sets shown) and assign env.GameTooltip (jscpd 12-line clone)

```text
local added, shown = {}, false
```

Verdict: The shared AddLine/Show recorder is a minimal host spy. One spec asserts giver availability/reaction and the other objective totals/target rendering from actual Model/tooltip callbacks; no addon line-building algorithm is duplicated in the recorder. Standalone fixture plumbing is covered by the lens exception.

Evidence/call contracts: [tests/questgivers_spec.lua](../../tests/questgivers_spec.lua); [tests/questprogress_spec.lua](../../tests/questprogress_spec.lua); [QuestGivers.lua](../../QuestGivers.lua); [QuestProgress.lua](../../QuestProgress.lua).

### `b6a0f31b45` — dismissed

Source: `final-20260930-tests-b-reach.json`, item 7 (zero-based); lens `dead-code`; `tests/questprogress_spec.lua:32`.

Candidate: values.n is set but production never reads it

```text
			local values = { n = #keys }
```

Verdict: This is the same external packed-return contract as the giver fixture: Progress objective/end fields may be nil, so n differs from Lua's sequence length. GetAll consumers currently index fields, but a faithful Questie wire double should preserve declared tuple arity. No production feature or unnecessary algorithm is implemented by that metadata.

Evidence/call contracts: [tests/questprogress_spec.lua](../../tests/questprogress_spec.lua); [QuestProgress.lua](../../QuestProgress.lua); [types/Forever.lua](../../types/Forever.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `d8a428b004` — dismissed

Source: `final-20260930-tests-b-reach.json`, item 8 (zero-based); lens `dead-code`; `tests/questprogress_spec.lua:105`.

Candidate: second return value of GetNumQuestLogEntries is never consumed

```text
			return #log, #log - 1
```

Verdict: GetNumQuestLogEntries is a native two-return API (all entries and quest count excluding headers); this fixture models both, and its log includes a header. Current Rebuild uses only the first result, but faithfully returning the native second value is host-interface fixture plumbing, not an optional addon abstraction. The deletion probe alone cannot refute the API shape.

Evidence/call contracts: [tests/questprogress_spec.lua](../../tests/questprogress_spec.lua); [QuestProgress.lua](../../QuestProgress.lua); [types/Forever.lua](../../types/Forever.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `16b5359a43` — dismissed

Source: `final-20260930-tests-b-text.json`, item 8 (zero-based); lens `test-plumbing`; `tests/questprogress_spec.lua:158`.

Candidate: Snapshot of Feature defaults, restating the declarations; #initializers == 1 follows on the next line.

```text
assert(features.questTooltips.default == true and features.questPlates.default == true)
```

Verdict: The quoted defaults describe public tooltip/nameplate options and are consumed by Core initialization/settings. A default flip changes visible behavior without altering Model target calculations. The unquoted neighboring callback count is not this anchor; retain these meaningful defaults rather than dismissing them as duplicated declaration text.

Evidence/call contracts: [tests/questprogress_spec.lua](../../tests/questprogress_spec.lua); [QuestProgress.lua](../../QuestProgress.lua); [Core.lua](../../Core.lua); [Settings.lua](../../Settings.lua).

### `7f7a6144c7` — confirmed

Source: `final-20260930-tests-b-text.json`, item 9 (zero-based); lens `test-plumbing`; `tests/questprogress_spec.lua:176`.

Candidate: Asserts a title literal and that two features share the same needs table by identity: an implementation detail, not player-visible behaviour.

```text
assert(needs.title == "QuestieDB" and features.questPlates.needs == needs)
```

Verdict: Only features.questPlates.needs == needs is confirmed: two separate equal title/check tables preserve dependency semantics but fail this identity assertion in the temporary module. Settings consumes title/check, not identity. Retain the title assertion as the public missing-addon label contract.

Evidence/call contracts: [tests/questprogress_spec.lua](../../tests/questprogress_spec.lua); [QuestProgress.lua](../../QuestProgress.lua); [Settings.lua](../../Settings.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

## tests/reagents_spec.lua

### `a42056219f` — dismissed

Source: `final-20260930-tests-b-text.json`, item 16 (zero-based); lens `test-plumbing`; `tests/reagents_spec.lua:14`.

Candidate: Pins exact pixel coordinates (also Lift 48/90 in the same file and 164/148/106 in sections_spec) that restate the layout constants; any deliberate spacing tweak fails them.

```text
assert(at(1) == "9,46", at(1))
```

Verdict: The pixel expectations assert the public grid geometry at specific row/column/container widths, including spacing and the lifted reagent container. Transposing columns or using the wrong row-height/wrap arithmetic changes coordinates while IDs/counts remain correct. A deliberate visual spacing change is a changed public outcome requiring updated expectations, not a behavior-preserving refactor.

Evidence/call contracts: [tests/reagents_spec.lua](../../tests/reagents_spec.lua); [tests/sections_spec.lua](../../tests/sections_spec.lua); [Reagents.lua](../../Reagents.lua); [Sections.lua](../../Sections.lua); [tests/bagslayout_spec.lua](../../tests/bagslayout_spec.lua).

## tests/sections_spec.lua

### `4b6f727f07` — dismissed

Source: `final-20260930-tests-b-text.json`, item 2 (zero-based); lens `test-plumbing`; `tests/sections_spec.lua:10`.

Candidate: Restates the ns.Feature declaration's parent field; a snapshot of configuration, not behaviour.

```text
assert(features.gearSections.parent == "gearGroups")
```

Verdict: gearSections is supported only when gearGroups is enabled; Settings consumes the literal parent to gate the option. Losing/misspelling that relationship changes visible option behavior without changing section layout calculations, so this is a meaningful public dependency test.

Evidence/call contracts: [tests/sections_spec.lua](../../tests/sections_spec.lua); [Sections.lua](../../Sections.lua); [Settings.lua](../../Settings.lua); [Core.lua](../../Core.lua).

## tests/settings_spec.lua

### `51241790f4` — confirmed

Source: `final-20260930-tests-b-reach.json`, item 9 (zero-based); lens `dead-code`; `tests/settings_spec.lua:44`.

Candidate: fake category records parent but no assertion reads it

```text
		parent = parent,
```

Verdict: The fake category's parent storage is never read by Settings or assertions; category name/GetID and returned child registration remain live. Removing the field preserves settings_spec. Keep the supplied parent argument needed for Settings' registration call contract; the unused saved record is the narrow finding.

Evidence/call contracts: [tests/settings_spec.lua](../../tests/settings_spec.lua); [Settings.lua](../../Settings.lua); [followup-probes-corrected.json](../runs/evidence/codex-final-20260930/followup-probes-corrected.json).

## tests/spellbook_spec.lua

### `f61790a732` — confirmed

Source: `final-20260930-tests-b-text.json`, item 11 (zero-based); lens `test-plumbing`; `tests/spellbook_spec.lua:13`.

Candidate: Snapshot of Feature default and private initializer count; the initializer is never run in the spec.

```text
assert(features.trainableSpells.default and #initializers == 1)
```

Verdict: Only the initializer-count conjunct is confirmed: adding a no-op callback fails while default and generated/model spell behavior remain the same, and dropping the conjunct restores the spec. The host spellbook initializer is not run here; keep the feature default and meaningful selection/data tests.

Evidence/call contracts: [tests/spellbook_spec.lua](../../tests/spellbook_spec.lua); [Spellbook.lua](../../Spellbook.lua); [final-probes.json](../runs/evidence/codex-final-20260930/final-probes.json).

### `63aae5440d` — dismissed

Source: `final-20260930-tests-b-text.json`, item 13 (zero-based); lens `test-plumbing`; `tests/spellbook_spec.lua:93`.

Candidate: Pins rows of the generated Data/ClassSpells.lua (Frost Shock cost 2200, level 20, Teleport 3561 for Dwarf but not Orc, rank order 548 for Lightning Bolt); a data refresh changes them with no code defect.

```text
assert(frost.spell.level == 20 and frost.spell.cost == 2200 and frost.spell.lineID == 375)
```

Verdict: The fixtures protect actual public spell data: trainer cost overrides, minimum level/skill line, racial teleport filtering and rank choice. A generator join/filter regression can keep table shape valid while changing those values and player prices/readiness. An intentional source-build update may revise expected data but does not invalidate the integrity/API contract.

Evidence/call contracts: [tests/spellbook_spec.lua](../../tests/spellbook_spec.lua); [Spellbook.lua](../../Spellbook.lua); [tools/gen_classspells.py](../../tools/gen_classspells.py); [tools/gen_classspells_test.py](../../tools/gen_classspells_test.py); [API.lua](../../API.lua).

### `c65492c683` — dismissed

Source: `final-20260930-tests-b-text.json`, item 14 (zero-based); lens `test-plumbing`; `tests/spellbook_spec.lua:108`.

Candidate: Data-integrity sweep of the generated table with an arbitrary magic threshold (50); checks the generator's output, not Spellbook.lua.

```text
assert(#class.spells > 50, token .. " has a full list")
```

Verdict: The >50 threshold is a pinned-build completeness floor for each of the eight classes. Row-by-row required-field checks accept a valid truncated list; dropping most spells would satisfy them but fail this floor. The generator promises a full list for each supported class, so this is a meaningful integrity guard even though future source changes may revise the floor.

Evidence/call contracts: [tests/spellbook_spec.lua](../../tests/spellbook_spec.lua); [tools/gen_classspells.py](../../tools/gen_classspells.py); [Data/ClassSpells.lua](../../Data/ClassSpells.lua).

### `23e9c741d5` — confirmed

Source: `final-20260930-tests-b-text.json`, item 15 (zero-based); lens `test-plumbing`; `tests/spellbook_spec.lua:45`.

Candidate: Assertion sits inside a loop over Model.Choose's result with no check that the result is non-empty, so an empty list passes vacuously.

```text
assert(entry.spell.lineID, "every tab's, never a weapon or unlined row: " .. entry.spell.name)
```

Verdict: For the all-tabs case, the loop accepts an empty Choose result. A temporary production mutation returning {} only when lineID is nil still passes spellbook_spec. Add a nonempty/expected-members assertion before per-row validation; api_spec separately guards public all-tabs behavior but does not make this local assertion catch the defect.

Evidence/call contracts: [tests/spellbook_spec.lua](../../tests/spellbook_spec.lua); [Spellbook.lua](../../Spellbook.lua); [tests/api_spec.lua](../../tests/api_spec.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

## tests/zonelevels_spec.lua

### `4bc72c2a21` — confirmed

Source: `final-20260930-tests-b-text.json`, item 10 (zero-based); lens `test-plumbing`; `tests/zonelevels_spec.lua:25`.

Candidate: Snapshot of Feature default and private initializer count; the spec never runs initializers[1].

```text
assert(#initializers == 1 and features.zoneLevels.default == true)
```

Verdict: Only the exact initializer count is confirmed: the spec never runs the host initializer, and adding a no-op callback fails despite unchanged model output/default. Retaining the public default assertion without the count passes. This is not proof that ZoneLevels' live map UI has been exercised.

Evidence/call contracts: [tests/zonelevels_spec.lua](../../tests/zonelevels_spec.lua); [ZoneLevels.lua](../../ZoneLevels.lua); [final-probes.json](../runs/evidence/codex-final-20260930/final-probes.json).

## tools/README.md

### `7a3b816590` — dismissed

Source: `final-20260930-tools-lint-text.json`, item 3 (zero-based); lens `stale-docs`; `tools/README.md:131`.

Candidate: README documents lint_multivalue, lint_taint and phrases but never names typecheck_coverage.py or typecheck_report.py, though typecheck.sh runs both

```text
The gate runs the Python regression tests first; run them separately with
```

Verdict: tools/README documents the supported typecheck.sh entry point and says it validates TOC coverage plus LuaLS and lints. typecheck_coverage/report are internal implementation steps called there; not naming every helper does not make any documented command or gate claim false. Full helper/test reads verify missing nested XML, omitted runtime files and diagnostics fail closed.

Evidence/call contracts: [tools/README.md](../../tools/README.md); [tools/typecheck.sh](../../tools/typecheck.sh); [tools/typecheck_coverage.py](../../tools/typecheck_coverage.py); [tools/typecheck_coverage_test.py](../../tools/typecheck_coverage_test.py); [tools/typecheck_report.py](../../tools/typecheck_report.py); [tools/typecheck_report_test.py](../../tools/typecheck_report_test.py).

## tools/gen_camp.py

### `73cee16ed4` — confirmed

Source: `carried ledger`; lens `parallel-implementations`; `tools/gen_camp.py:144`; carried from active ledger.

Candidate: Two Lua string-literal encoders: gen_camp.py:141-142 lua_string and phrases.py:97-98 encode. Canonical: phrases.encode's behaviour (it escapes newlines too), in a shared tools helper.

```text
return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'
```

Verdict: Independent encoder tests show matching quote/backslash output in camp/classspells but raw-newline output there versus escaped newline in phrases. These are one Lua-literal mechanism with observed drift; retain caller formatting/import modes and centralize escaping. Current generated rows do not demonstrate a live newline failure. All files hot; prior deferred work remains unedited.

Evidence/call contracts: [tools/gen_camp.py](../../tools/gen_camp.py); [tools/gen_classspells.py](../../tools/gen_classspells.py); [tools/phrases.py](../../tools/phrases.py); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

## tools/gen_classspells.py

### `afe8258206` — confirmed

Source: `final-20260930-tools-gen-dup.json`, item 1 (zero-based); lens `parallel-implementations`; `tools/gen_classspells.py:119`.

Candidate: project() at gen_classspells.py:119 is a line-for-line copy of gen_dungeons.py:97 (world point to map position via UiMapAssignment region, rounded to 3 places). Canonical home: gen_dungeons.project (or a shared helper).

```text
def project(assignment, x, y):
```

Verdict: After stripping only docstrings, project has identical AST in classspells and dungeons; 30 nonsquare/off-center/boundary/outside points yield identical values. Trainer and instance selection differ upstream, but the world-to-UiMap affine transform, axis reversal and 3-place rounding are the same operation and can share one implementation without changing those selection contracts.

Evidence/call contracts: [tools/gen_classspells.py](../../tools/gen_classspells.py); [tools/gen_dungeons.py](../../tools/gen_dungeons.py); [tools/gen_classspells_test.py](../../tools/gen_classspells_test.py); [tools/gen_dungeons_test.py](../../tools/gen_dungeons_test.py); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `5e86d251df` — dismissed

Source: `final-20260930-tools-gen-dup.json`, item 2 (zero-based); lens `parallel-implementations`; `tools/gen_classspells.py:148`.

Candidate: lua_string at gen_classspells.py:148 is identical to gen_camp.py:143 (backslash and double-quote escaping into a Lua string literal).

```text
def lua_string(text):
```

Verdict: Same producer as 73cee16ed4: camp/classspells encoders match on backslash/quote cases and both emit an invalid raw newline where phrases.encode escapes it. Canonical confirmation covers all three writers; no current generated input with that newline was demonstrated, so this is duplicated mechanism/drift, not a proven current-data failure.

Evidence/call contracts: [tools/gen_classspells.py](../../tools/gen_classspells.py); [tools/gen_camp.py](../../tools/gen_camp.py); [tools/phrases.py](../../tools/phrases.py); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

Canonical producer: `73cee16ed4` (its verdict remains separately recorded).

## tools/gen_dungeons.py

### `ba6c83cad5` — confirmed

Source: `carried ledger`; lens `parallel-implementations`; `tools/gen_dungeons.py:78`; carried from active ledger.

Candidate: The wago.tools DB2 fetch-and-cache (pinned BUILD, CACHE path, --offline/--refresh, User-Agent, HTML-response check, cache write) is written five times: gen_dungeons.py:78-94, gen_zonelevels.py:96-112 (byte-identical to gen_dungeons), gen_classspells.py:62-78, gen_camp.py:33-54, gen_overlays.py:29-67; the pin `BUILD = "1.60.1.70009"` is restated in all five (refresh-data.yml:38 seds it into each file). Canonical home: one shared tools module holding BUILD, CACHE and the download/cache step with gen_overlays' atomic write, each generator keeping only its own row parsing.

```text
def db2(name, refresh=False, offline=False):
```

Verdict: The five generators independently perform pinned DB2 download/cache/HTML validation; camp/dungeons/zone/class write cache directly while overlays uses atomic replacement. Different timeout/build arguments, schemas and parsed return shapes belong to callers, but do not require separate transport/cache mechanics. Preserve those contracts while sharing that boundary; existing generator regression tests pass. Hot/deferred; no consolidation performed.

Evidence/call contracts: [tools/gen_dungeons.py](../../tools/gen_dungeons.py); [tools/gen_zonelevels.py](../../tools/gen_zonelevels.py); [tools/gen_camp.py](../../tools/gen_camp.py); [tools/gen_overlays.py](../../tools/gen_overlays.py); [tools/gen_classspells.py](../../tools/gen_classspells.py); [tools/README.md](../../tools/README.md); [check-python-tests.json](../runs/evidence/codex-final-20260930/check-python-tests.json).

## tools/gen_zonelevels.py

### `5cc1e8d0f9` — dismissed

Source: `final-20260930-tools-gen-dup.json`, item 0 (zero-based); lens `parallel-implementations`; `tools/gen_zonelevels.py:96`.

Candidate: The wago.tools DB2 CSV fetch/cache/validate function is restated in five generators: gen_zonelevels.py:96 and gen_dungeons.py:78 (byte-identical, both timeout=300), gen_overlays.py:39, gen_camp.py:35, gen_classspells.py:66. No shared module; canonical home would be one tools helper (e.g. tools/db2.py) taking build, key and timeout.

```text
def db2(name, refresh=False, offline=False):
```

Verdict: Same producer as ba6c83cad5: independent comparison confirms the shared DB2 transport/cache mechanism, but preserve each parser schema, timeout/build argument and return shape when consolidating. The carried canonical item remains confirmed/hot; this new copy does not represent another defect.

Evidence/call contracts: [tools/gen_zonelevels.py](../../tools/gen_zonelevels.py); [tools/gen_dungeons.py](../../tools/gen_dungeons.py); [tools/gen_camp.py](../../tools/gen_camp.py); [tools/gen_overlays.py](../../tools/gen_overlays.py); [tools/gen_classspells.py](../../tools/gen_classspells.py).

Canonical producer: `ba6c83cad5` (its verdict remains separately recorded).

## tools/lint_multivalue.py

### `d1f3afed80` — dismissed

Source: `final-20260930-tools-lint-dup.json`, item 1 (zero-based); lens `parallel-implementations`; `tools/lint_multivalue.py:337`.

Candidate: toc_paths (lint_multivalue.py:332-338, used by lint_multivalue and phrases) and runtime_files (typecheck_coverage.py:9-37, used by lint_taint and the coverage gate) are two parsers of the TOC load list.

```text
        if line.strip().endswith(".lua") and not line.startswith("#")
```

Verdict: The independent set comparison gives 38 root-TOC Lua files versus 40 shipped files: runtime_files also visits the separate LibAHTab/LibAHTab.toc, adding vendor LibAHTab.lua and LibStub.lua. The root DungeonEntrances.xml uses an existing mixin method and adds no Lua file. phrases must extract this addon's strings rather than the vendored child addon's copy; coverage/taint intentionally audit every shipped addon graph. The direct four-line root reader and recursive all-TOC/XML walker have different enforced ownership/load contracts, not two copies of one parse operation.

Evidence/call contracts: [tools/lint_multivalue.py](../../tools/lint_multivalue.py); [tools/typecheck_coverage.py](../../tools/typecheck_coverage.py); [tools/phrases.py](../../tools/phrases.py); [tools/lint_taint.py](../../tools/lint_taint.py); [TweaksForever.toc](../../TweaksForever.toc); [DungeonEntrances.xml](../../DungeonEntrances.xml); [LibAHTab/LibAHTab.toc](../../LibAHTab/LibAHTab.toc); [final-probes.json](../runs/evidence/codex-final-20260930/final-probes.json).

### `f2eae677e9` — confirmed

Source: `final-20260930-tools-lint-dup.json`, item 3 (zero-based); lens `stringly-typed`; `tools/lint_multivalue.py:14`.

Candidate: Token.kind is a closed set of four bare strings ("symbol", "name", "string", "number") compared by literal in lint_multivalue.py (e.g. :144, :171, :224), lint_taint.py (:53, :68, :78, :114, :118) and phrases.py (:104, :117, :132, :199, ...).

```text
    kind: str = "symbol"
```

Verdict: Token.kind is produced internally as exactly symbol/name/string/number and consumers branch on those tags; raw Lua lexemes remain in text and are an external language contract. An independent ty 0.0.83 probe accepts a constructor tag strng under str and rejects it under Literal. The prior reason is correct that comparison typos still pass ty; this confirmation is narrowed to constructor typing and the closed internal set, keeping token text unrestricted.

Evidence/call contracts: [tools/lint_multivalue.py](../../tools/lint_multivalue.py); [tools/lint_taint.py](../../tools/lint_taint.py); [tools/phrases.py](../../tools/phrases.py); [tools/lint_multivalue_test.py](../../tools/lint_multivalue_test.py); [tools/phrases_test.py](../../tools/phrases_test.py); [token-and-freshness-probes.json](../runs/evidence/codex-final-20260930/token-and-freshness-probes.json).

### `de4faaaeb8` — confirmed

Source: `final-20260930-tools-lint-reach.json`, item 0 (zero-based); lens `speculative-abstraction`; `tools/lint_multivalue.py:341`.

Candidate: run() has a skip hook that no caller passes: its only caller is main(), and lint_taint.py runs its own loop instead of calling run.

```text
def run(check: Callable[[str], list[tuple[int, str]]], skip: Callable[[Path], bool] = lambda path: False) -> int:
```

Verdict: run's only caller is main with one check argument; no module passes skip, and lint_taint uses its own loop. CLI docs/flags expose no skip API. Thus the default-never-true callback and branch model an unused optional extension; sharing the runner later need not retain an unrequested skip mechanism.

Evidence/call contracts: [tools/lint_multivalue.py](../../tools/lint_multivalue.py); [tools/lint_taint.py](../../tools/lint_taint.py); [tools/README.md](../../tools/README.md); [tools/lint_multivalue_test.py](../../tools/lint_multivalue_test.py).

## tools/lint_taint.py

### `d06058d6e4` — confirmed

Source: `final-20260930-tools-lint-dup.json`, item 0 (zero-based); lens `parallel-implementations`; `tools/lint_taint.py:130`.

Candidate: lint_taint.main (lint_taint.py:129-142) re-writes the path loop, read/OSError/LuaSyntaxError handling, per-finding print and exit-code logic of lint_multivalue.run (lint_multivalue.py:341-357); canonical home is run(), which lint_taint already imports from (jscpd 10-line clone).

```text
    paths = [Path(arg) for arg in sys.argv[1:]] or runtime_files(Path.cwd().resolve())
```

Verdict: lint_taint imports the multivalue module already but repeats the read/OSError/LuaSyntaxError/print/exit loop. Its recursive default file provider differs from run's root TOC provider; that difference must remain a caller parameter, while the execution/error mechanism can be shared. CLI/file error tests impose no import boundary requiring two loops.

Evidence/call contracts: [tools/lint_taint.py](../../tools/lint_taint.py); [tools/lint_multivalue.py](../../tools/lint_multivalue.py); [tools/lint_taint_test.py](../../tools/lint_taint_test.py); [tools/lint_multivalue_test.py](../../tools/lint_multivalue_test.py); [tools/typecheck.sh](../../tools/typecheck.sh).

### `61a2d52a6a` — dismissed

Source: `final-20260930-tools-lint-reach.json`, item 2 (zero-based); lens `speculative-abstraction`; `tools/lint_taint.py:17`.

Candidate: OWN exempts owner prefixes (SkillUp, WorkOrders, WOF_) that no shipped Lua uses; Legacy/ShortestPath/AdventureGuide are other addons' globals that this addon only reads.

```text
    r"(?:Tweaks|SkillUp|Legacy|ShortestPath|AdventureGuide|WorkOrders)Forever\w*|WOF_\w+|SLASH_\w+|SlashCmdList"
```

Verdict: OWN classifies known addon-owned Lua namespaces versus Blizzard secure state; host-taint rules intentionally do not treat other addons' ordinary Lua tables as native frames. The independent WorkOrders/SkillUp/AdventureGuide-versus-WorldMap probe demonstrates that policy boundary, not an unreachable feature. Questie and the other family globals are external ownership contracts; lack of a current write does not make a static ownership classifier dead.

Evidence/call contracts: [tools/lint_taint.py](../../tools/lint_taint.py); [tools/lint_taint_test.py](../../tools/lint_taint_test.py); [types/Forever.lua](../../types/Forever.lua); [QuestiePins.lua](../../QuestiePins.lua); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

## tools/phrases.py

### `f946bfe200` — dismissed

Source: `final-20260930-tools-lint-dup.json`, item 2 (zero-based); lens `parallel-implementations`; `tools/phrases.py:132`.

Candidate: The bracket-depth test (symbol token in "([{" => +1, in ")]}" => -1) is written three times: closing (phrases.py:112-123), arguments (:126-141) and declared (:144-172; jscpd 7-line clone of arguments).

```text
        if token.kind == "symbol" and token.text in "([{":
```

Verdict: closing matches the end of one bracketed expression, arguments splits commas only at nesting depth zero, and declared recognizes declaration field lists. Their shared four-line depth increment/decrement is a parser idiom, while termination/output/token policies differ. There is no duplicated whole parse operation to consolidate safely.

Evidence/call contracts: [tools/phrases.py](../../tools/phrases.py); [tools/phrases_test.py](../../tools/phrases_test.py).

## tools/screenshots.py

### `250986b4c4` — dismissed

Source: `final-20260930-tools-lint-dup.json`, item 4 (zero-based); lens `parallel-implementations`; `tools/screenshots.py:278`.

Candidate: dungeon_layers computes the Raid-or-Dungeon atlas for an entrance twice with the same expression (screenshots.py:279 in the pin loop, :290 for the hovered pin), and a per-instance variant at :294.

```text
    atlas = "Raid" if all(i in raids for i in instances) else "Dungeon"
```

Verdict: The pin loop classifies each entrance by all constituent raids, the hovered aggregate uses the chosen entrance, and tooltip rows classify individual instances. The repeated one-line expression is a small classification idiom, not an independently maintained rendering algorithm; the aggregate/per-row distinction is necessary for mixed entrances, and screenshot Lua constants are explicitly Settled.

Evidence/call contracts: [tools/screenshots.py](../../tools/screenshots.py); [DungeonEntrances.lua](../../DungeonEntrances.lua); [.agents/skills/sift-project/SKILL.md](../../.agents/skills/sift-project/SKILL.md).

## tools/tooltip_border.py

### `f91d084e7c` — dismissed

Source: `final-20260930-tools-lint-text.json`, item 2 (zero-based); lens `wall-of-text`; `tools/tooltip_border.py:1`.

Candidate: 16-line docstring of dense long sentences that the tools/README.md tooltip_border paragraph repeats almost point for point

```text
"""Draw media/TooltipBorder<Style>.tga, the whole tooltip each tooltip style draws on a tooltip's NineSlice.
```

Verdict: The module docstring records technical asset constraints: one continuous image avoids corner seams, and native dimensions/filtering/corner geometry explain the nine-slice output. The tools README gives regeneration/discovery instructions at the repository level. Those different entry contexts justify some repeated usage facts, and the long explanation is format/geometry reference rather than padded user copy.

Evidence/call contracts: [tools/tooltip_border.py](../../tools/tooltip_border.py); [tools/README.md](../../tools/README.md); [Tooltips.lua](../../Tooltips.lua).

## tools/typecheck_coverage.py

### `b5267fe9a5` — dismissed

Source: `final-20260930-tools-lint-reach.json`, item 1 (zero-based); lens `speculative-abstraction`; `tools/typecheck_coverage.py:33`.

Candidate: Orphan check walks UI/ and Transport/ folders that do not exist in this repo; carried over from a sibling addon ('in this addon family' comment).

```text
    for folder in (root, root / "Data", root / "Locales", root / "UI", root / "Transport"):
```

Verdict: This is a fail-closed coverage guard for newly introduced runtime folders, not a future runtime feature. In an isolated directory, adding UI/Forgotten.lua immediately raises “Runtime Lua is not loaded by a TOC/XML”; deleting UI/Transport would silently allow that realistic omission. Current absence is the passing condition of this preventive gate.

Evidence/call contracts: [tools/typecheck_coverage.py](../../tools/typecheck_coverage.py); [tools/typecheck_coverage_test.py](../../tools/typecheck_coverage_test.py); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

### `feac9e9ed7` — dismissed

Source: `final-20260930-tools-lint-text.json`, item 1 (zero-based); lens `defensive-noise`; `tools/typecheck_coverage.py:33`.

Candidate: orphan scan lists UI and Transport, directories this repo does not have; the comment cites 'this addon family'

```text
    for folder in (root, root / "Data", root / "Locales", root / "UI", root / "Transport"):
```

Verdict: Same producer as b5267fe9a5: the independent orphan addition proves the absent-directory scan enforces the load-graph contract when a file is introduced. Removing this preventive guard would loosen the gate; it is not a redundant runtime nil check.

Evidence/call contracts: [tools/typecheck_coverage.py](../../tools/typecheck_coverage.py); [tools/typecheck_coverage_test.py](../../tools/typecheck_coverage_test.py); [independent-probes.json](../runs/evidence/codex-final-20260930/independent-probes.json).

Canonical producer: `b5267fe9a5` (its verdict remains separately recorded).

## tools/typecheck_report.py

### `f072ed4ebf` — dismissed
