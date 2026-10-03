#!/usr/bin/env python3
# sift-scope: all
# sift-fix: call ns.OnSettingChanged(key, fn) instead; Core builds the TweaksForever_ variable and asserts the key
"""Settings.SetOnValueChangedCallback is called only from Core/Core.lua's ns.OnSettingChanged.

A feature file that restates the "TweaksForever_" .. key variable by hand registers a callback that never
fires when the key is misspelt. Specs and annotations are out of scope: they stub the API.
"""

import os
import re
import sys

RULE = os.environ["SIFT_RULE"]
OWNER = "Core/Core.lua"
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
                    hits.append(f"{path}:{number}: {RULE} setting callback registered outside Core/Core.lua")
    for hit in hits:
        print(hit)
    return 1 if hits else 0


sys.exit(main())
