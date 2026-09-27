#!/usr/bin/env python3
# sift-scope: all
# sift-fix: delete the entry from .luacheckrc; luacheck never reports an allowed global that nothing reads
"""Every `globals`/`read_globals` entry in .luacheckrc is named by some Lua or XML file.

Written in the 2026-09-27 audit against `StaticPopupDialogs` and `tInvert`, left behind when #66 moved
Junk.lua off them. Locales/phrases.txt counts as Lua: translators copy it into Locales/<locale>.lua, so its
`GetLocale()` line needs the entry. Whole-tree run at writing: those two hits, no false positives.
"""

import os
import re
import sys

RULE = os.environ["SIFT_RULE"]
CONFIG = ".luacheckrc"
LUA_LIKE = re.compile(r"\.(lua|xml)$")
TEMPLATES = {"Locales/phrases.txt"}


def entries(text):
    """(name, line) for each quoted name inside a top-level `globals` or `read_globals` table."""
    found = []
    inside = False
    for number, line in enumerate(text.splitlines(), 1):
        if re.match(r"\s*(read_)?globals\s*=\s*\{", line):
            inside = True
        if inside:
            for name in re.findall(r'"([A-Za-z_][A-Za-z0-9_]*)"', line):
                found.append((name, number))
            if "}" in line:
                inside = False
    return found


def main():
    with open(os.environ["SIFT_FILES"], encoding="utf-8") as listing:
        paths = [p for p in listing.read().splitlines() if p]
    if CONFIG not in paths:
        return 0
    with open(CONFIG, encoding="utf-8") as config:
        allowed = entries(config.read())
    corpus = []
    for path in paths:
        if path != CONFIG and (LUA_LIKE.search(path) or path in TEMPLATES):
            with open(path, encoding="utf-8", errors="replace") as source:
                corpus.append(source.read())
    text = "\n".join(corpus)
    hits = [
        f"{CONFIG}:{line}: {RULE} allowed global `{name}` is named by no Lua or XML file"
        for name, line in allowed
        if not re.search(r"(?<![A-Za-z0-9_])" + re.escape(name) + r"(?![A-Za-z0-9_])", text)
    ]
    for hit in hits:
        print(hit)
    return 1 if hits else 0


sys.exit(main())
