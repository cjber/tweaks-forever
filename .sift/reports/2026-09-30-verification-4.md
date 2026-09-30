Source: `final-20260930-tools-lint-text.json`, item 0 (zero-based); lens `stale-docs`; `tools/typecheck_report.py:35`.

Candidate: success message names the multi-value lint, but this script only reports LuaLS diagnostics

```text
    print("LuaLS and multi-value lint: no diagnostics")
```

Verdict: The documented caller is tools/typecheck.sh, which uses set -e and runs lint_multivalue successfully before invoking typecheck_report on LuaLS results. Reaching this success print therefore guarantees both checks passed in that supported pipeline. The helper reports the composite gate result; its lack of a direct lint invocation does not contradict the caller's sequencing contract.

Evidence/call contracts: [tools/typecheck.sh](../../tools/typecheck.sh); [tools/typecheck_report.py](../../tools/typecheck_report.py); [tools/typecheck_report_test.py](../../tools/typecheck_report_test.py); [tools/README.md](../../tools/README.md); [check-lua-types.json](../runs/evidence/codex-final-20260930/check-lua-types.json).

## types/API.lua

### `54665596d9` — confirmed

Source: `final-20260930-config-docs-text.json`, item 0 (zero-based); lens `stale-docs`; `types/API.lua:21`.

Candidate: TFPublicAPI annotation says version 1 and lists only TrainableSpells and DungeonEntrance

```text
---@field version integer 1
```

Verdict: API.lua publishes version 2 and adds Trainers; the merged TFPublicAPI class declarations define that member, but types/API.lua still documents version 1. api_spec exercises v2 before login, so this is an outdated contract annotation, not a retained v1 interface.

Evidence/call contracts: [types/API.lua](../../types/API.lua); [API.lua](../../API.lua); [tests/api_spec.lua](../../tests/api_spec.lua).
