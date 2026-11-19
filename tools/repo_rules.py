#!/usr/bin/env python3
"""Check the rules this repository holds that no linter covers. CI runs it in the `project-rules` job.

- `setting-callback-outside-core`: `Settings.SetOnValueChangedCallback` is called only from Core/Core.lua's
  `ns.OnSettingChanged(key, fn)`. A feature file that restates the `"TweaksForever_" .. key` variable by hand
  registers a callback that never fires when the key is misspelt. Specs and annotations stub the API.
- `item-info-outside-core`: only Core/ItemInfo.lua, of the Lua and XML files, listens for `GET_ITEM_INFO_RECEIVED`
  or `ITEM_DATA_LOAD_RESULT`.
  Both fire for every item any addon asks about, in bursts, so a feature that reacts to the event itself reruns its
  work dozens of times a second; a feature names the items it waits for with `ns.AwaitItem(itemID, fn)` instead.
- `chat-alert`: only Core/Core.lua's `ns.Print` writes to chat, and each `ns.Print` call is one CHAT_REPLIES
  names: a reply to the player's own command or a receipt of what was done for them. An alert the player should
  see now (a rare, a pull) goes on screen with `ns.Alert`, since a chat line is lost among other addons' output
  (#627).
- `unit-event-for-every-unit`: a `UNIT_*` event is registered with `ns.OnUnit(event, unit, fn)` or
  `RegisterUnitEvent`. `ns.On` or `RegisterEvent` registers it for every unit, so in a raid each party, raid and
  nameplate unit wakes the addon to be ignored. Every quoted `UNIT_*` name must sit in one of those two calls or be
  compared against (`event == "UNIT_X"`), which also catches a name kept in a list and registered in a loop.
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
CHAT_OWNER = "Core/Core.lua"
CHAT_WRITE = re.compile(
    r"(?:(?<![A-Za-z0-9_.:])|(?<=_G\.))print\s*\(|_G\[[\"']print[\"']\]|DEFAULT_CHAT_FRAME|ChatFrame\d+\s*:\s*AddMessage"
)
# Any use of ns.Print, called or not: an alias (`local P = ns.Print`) would carry an alert past a call check.
CHAT_PRINT = re.compile(r"\bns\s*(?:\.\s*Print\b|\[\s*[\"']Print[\"']\s*\])")
CHAT_CALL = re.compile(r"\s*\(\s*")
# The chat lines allowed, by file: what each `ns.Print` call's argument starts with, and what the lines answer.
CHAT_REPLIES = {
    "Bags/Vendor.lua": (
        "the repair receipt",
        (
            'L["repaired for %s from guild funds."]',
            'L["repaired for %s."]',
            'L["not enough money to repair (%s)."]',
            'L["repair skipped (%s)."]',
        ),
    ),
    "Bags/Junk.lua": ("the junk sale receipt", ('L["Sold 1 junk stack for %s."]', 'L["Sold %d junk stacks for %s."]')),
    "Integrations/Navigate.lua": (
        "where a waypoint the player asked for is, when no navigation addon takes it",
        ('L["%s is at %s in %s."]', 'L["%s is at %s."]'),
    ),
    "UI/Settings.lua": (
        "the slash command's help",
        (
            'L["/tw report - show a report to copy into a bug report"]',
            'L["/tw issue - report a bug or request a feature with a ready-made GitHub issue link"]',
        ),
    ),
    # Model.Message's one-line update note.
    "UI/WhatsNew.lua": ("the one-line update note", ("message)",)),
}
UNIT_EVENT_NAME = re.compile(r"[\"']UNIT_[A-Z_]+[\"']")
UNIT_EVENT_OK = re.compile(r"(\bOnUnit|RegisterUnitEvent)\s*\(\s*$|[=~]=\s*$")
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


def lua_code(line: str) -> str:
    """The line before its `--` comment, a `--` inside a quoted string left alone."""
    quote = None
    for index, char in enumerate(line):
        if quote:
            if char == "\\":
                continue
            if char == quote and line[index - 1] != "\\":
                quote = None
        elif char in "\"'":
            quote = char
        elif line.startswith("--", index):
            return line[:index]
    return line


def chat_alerts(files: dict[str, str]) -> list[str]:
    hits = []
    for path, text in files.items():
        if not LUA_LIKE.search(path) or path.startswith((*SETTINGS_SKIP, "tools/")):
            continue
        allowed = CHAT_REPLIES.get(path, ("", ()))[1]
        for number, line in enumerate(text.splitlines(), 1):
            code = lua_code(line)
            if path != CHAT_OWNER and CHAT_WRITE.search(code):
                hits.append(f"{path}:{number}: chat-alert: chat output goes through ns.Print in {CHAT_OWNER}")
            for use in CHAT_PRINT.finditer(code):
                call = CHAT_CALL.match(code, use.end())
                if path != CHAT_OWNER and not (call and code[call.end() :].startswith(allowed)):
                    hits.append(
                        f"{path}:{number}: chat-alert: show an alert with ns.Alert; chat is for the replies "
                        "and receipts CHAT_REPLIES names"
                    )
    return hits


def unit_events(files: dict[str, str]) -> list[str]:
    return [
        f"{path}:{number}: unit-event-for-every-unit: register it with ns.OnUnit(event, unit, fn)"
        for path, text in files.items()
        if LUA_LIKE.search(path) and not path.startswith((*SETTINGS_SKIP, "tools/"))
        for number, line in enumerate(text.splitlines(), 1)
        for name in UNIT_EVENT_NAME.finditer(lua_code(line))
        if not UNIT_EVENT_OK.search(lua_code(line)[: name.start()])
    ]


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


RULES = (setting_callbacks, item_info_listeners, chat_alerts, unit_events, unused_luacheck_globals, unmatched_hashfiles)


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
