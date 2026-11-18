#!/usr/bin/env python3
"""Check the rules this repository holds that no linter covers. CI runs it in the `project-rules` job.

- `setting-callback-outside-core`: `Settings.SetOnValueChangedCallback` is called only from Core/Core.lua's
  `ns.OnSettingChanged(key, fn)`. A feature file that restates the `"TweaksForever_" .. key` variable by hand
  registers a callback that never fires when the key is misspelt. Specs and annotations stub the API.
- `item-info-outside-core`: only Core/ItemInfo.lua, of the Lua and XML files, listens for `GET_ITEM_INFO_RECEIVED`
  or `ITEM_DATA_LOAD_RESULT`.
  Both fire for every item any addon asks about, in bursts, so a feature that reacts to the event itself reruns its
  work dozens of times a second; a feature names the items it waits for with `ns.AwaitItem(itemID, fn)` instead.
- `unused-luacheck-global`: every `globals`/`read_globals` entry in .luacheckrc is named by some Lua or XML file;
  luacheck never reports an allowed global that nothing reads. Locales/phrases.txt counts as Lua: translators copy
  it into Locales/<locale>.lua, so its `GetLocale()` line needs the entry.
- `workflow-hashfiles-unmatched`: every pattern a workflow passes to `hashFiles()` matches a tracked file. A cache
  key built from a pattern that matches nothing never changes when the file it was meant to track does.
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SETTINGS_OWNER = "Core/Core.lua"
SETTINGS_CALL = re.compile(r"SetOnValueChangedCallback\s*\(")
SETTINGS_SKIP = ("tests/", "types/")
ITEM_INFO_OWNER = "Core/ItemInfo.lua"
ITEM_INFO_EVENT = re.compile(r"[\"'](GET_ITEM_INFO_RECEIVED|ITEM_DATA_LOAD_RESULT)[\"']")
LUACHECK = ".luacheckrc"
LUA_LIKE = re.compile(r"\.(lua|xml)$")
LUA_TEMPLATES = {"Locales/phrases.txt"}
WORKFLOW = re.compile(r"^\.github/workflows/[^/]+\.ya?ml$")
HASHFILES = re.compile(r"hashFiles\(([^)]*)\)")
QUOTED = re.compile(r"'([^']*)'")


def setting_callbacks(files: dict[str, str]) -> list[str]:
    hits = []
    for path, text in files.items():
        if not path.endswith(".lua") or path == SETTINGS_OWNER or path.startswith(SETTINGS_SKIP):
            continue
        for number, line in enumerate(text.splitlines(), 1):
            if SETTINGS_CALL.search(line):
                hits.append(f"{path}:{number}: setting-callback-outside-core: use ns.OnSettingChanged(key, fn)")
    return hits


def item_info_listeners(files: dict[str, str]) -> list[str]:
    hits = []
    for path, text in files.items():
        # tools/ holds the vendored client simulator, which fires the events rather than listening for them.
        if not LUA_LIKE.search(path) or path == ITEM_INFO_OWNER or path.startswith((*SETTINGS_SKIP, "tools/")):
            continue
        for number, line in enumerate(text.splitlines(), 1):
            if ITEM_INFO_EVENT.search(line):
                hits.append(f"{path}:{number}: item-info-outside-core: wait for the item with ns.AwaitItem(itemID, fn)")
    return hits


def luacheck_entries(text: str) -> list[tuple[str, int]]:
    """(name, line) for each quoted name inside a `globals` or `read_globals` table that opens its own line."""
    found, inside = [], False
    for number, line in enumerate(text.splitlines(), 1):
        if re.match(r"\s*(read_)?globals\s*=\s*\{", line):
            inside = True
        if inside:
            found += [(name, number) for name in re.findall(r'"([A-Za-z_][A-Za-z0-9_]*)"', line)]
            if "}" in line:
                inside = False
    return found


def unused_luacheck_globals(files: dict[str, str]) -> list[str]:
    if LUACHECK not in files:
        return []
    corpus = "\n".join(t for p, t in files.items() if p != LUACHECK and (LUA_LIKE.search(p) or p in LUA_TEMPLATES))
    return [
        f"{LUACHECK}:{line}: unused-luacheck-global: `{name}` is named by no Lua or XML file; delete the entry"
        for name, line in luacheck_entries(files[LUACHECK])
        if not re.search(r"(?<![A-Za-z0-9_])" + re.escape(name) + r"(?![A-Za-z0-9_])", corpus)
    ]


def glob_matcher(pattern: str) -> re.Pattern[str]:
    parts = re.split(r"(\*\*/?|\*)", pattern)
    body = "".join(".*" if p.startswith("**") else "[^/]*" if p == "*" else re.escape(p) for p in parts)
    return re.compile(body + r"\Z")


def unmatched_hashfiles(files: dict[str, str]) -> list[str]:
    hits = []
    for path, text in files.items():
        if not WORKFLOW.match(path):
            continue
        for number, line in enumerate(text.splitlines(), 1):
            for call in HASHFILES.findall(line):
                for pattern in QUOTED.findall(call):
                    if pattern.startswith("!"):
                        continue
                    if not any(glob_matcher(pattern).match(p) for p in files):
                        hits.append(f"{path}:{number}: workflow-hashfiles-unmatched: `{pattern}` matches no file")
    return hits


RULES = (setting_callbacks, item_info_listeners, unused_luacheck_globals, unmatched_hashfiles)


def findings(files: dict[str, str]) -> list[str]:
    return [hit for rule in RULES for hit in rule(files)]


def tracked_files() -> dict[str, str]:
    listing = subprocess.run(["git", "-C", str(ROOT), "ls-files", "-z"], capture_output=True, check=True).stdout
    files = {}
    for path in listing.decode().split("\0"):
        file = ROOT / path
        if path and file.is_file():
            files[path] = file.read_text(encoding="utf-8", errors="replace")
    return files


def main() -> int:
    hits = findings(tracked_files())
    for hit in hits:
        print(hit)
    return int(bool(hits))


if __name__ == "__main__":
    sys.exit(main())
