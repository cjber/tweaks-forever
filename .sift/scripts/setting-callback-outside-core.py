#!/usr/bin/env python3
# sift-scope: all
# sift-fix: call ns.OnSettingChanged(key, fn) instead; Core builds the TweaksForever_ variable and asserts the key
"""Settings.SetOnValueChangedCallback is called only from Core.lua's ns.OnSettingChanged.

Written in the 2026-09-27 decisions pass (ledger ca2907f157): ten feature files each restated the
"TweaksForever_" .. key variable by hand, so a misspelt key registered a callback that never fired. Specs and
annotations are out of scope: they stub the API. Whole-tree run at writing: the 13 sites that moved, no
false positives.
"""

import os
import re
import sys

RULE = os.environ["SIFT_RULE"]
OWNER = "Core.lua"
CALL = re.compile(r"SetOnValueChangedCallback\s*\(")
SKIP = ("tests/", "types/", ".sift/")


def main():
    with open(os.environ["SIFT_FILES"], encoding="utf-8") as listing:
        paths = [p for p in listing.read().splitlines() if p]
    hits = []
    for path in paths:
        if not path.endswith(".lua") or path == OWNER or path.startswith(SKIP):
            continue
        with open(path, encoding="utf-8", errors="replace") as source:
            for number, line in enumerate(source, 1):
                if CALL.search(line):
                    hits.append(f"{path}:{number}: {RULE} setting callback registered outside Core.lua")
    for hit in hits:
        print(hit)
    return 1 if hits else 0


sys.exit(main())
