"""Reject addon code that writes into or hooks Blizzard's objects, or runs Blizzard code whose state it would taint.

See AGENTS.md for the ways to hook that stay clean; the shared rules live in `tools/forever_tools/taint.py`.
This file adds Tweaks' own rule on top: a `Set*` method called on an entry of one of Blizzard's data tables
stores the addon's value in a Lua field Blizzard's code reads later, which is the same write `taint.py` flags
for `Blizzard.field = value`, done through Blizzard's own setter.
"""

import re
import sys
from pathlib import Path

try:
    from tools.forever_tools import taint
    from tools.forever_tools.lua import LuaSyntaxError, Token, tokenize
    from tools.typecheck_coverage import runtime_files
except ModuleNotFoundError:
    from forever_tools import taint
    from forever_tools.lua import LuaSyntaxError, Token, tokenize
    from typecheck_coverage import runtime_files

# Blizzard globals that hold plain Lua data (tables of mixin objects) rather than widgets. A setter on a widget
# is an engine call and stays clean; a setter on one of these writes a field into Blizzard's table.
DATA_TABLES = frozenset({"AuctionCategories"})

# Setters on Blizzard's data mixins, flagged on any receiver: a value often reaches them through a table of
# the addon's own (`entry.category:SetDetailColumnString(...)`), where no receiver tracking can follow it.
DATA_SETTERS = {
    "SetDetailColumnString": "writes the auction category's detail column, which the Browse results layout reads",
}

POLICY = taint.Policy(calls={**taint.CALLS, **DATA_SETTERS})

SETTER = re.compile(r"Set[A-Z]\w*")
CALL_OPENERS = frozenset({"(", "{"})
ITERATORS = frozenset({"ipairs", "pairs", "next"})


def receiver_root(tokens: list[Token], index: int) -> str | None:
    """The root name of the receiver of the method name at `index` (`a.b[i]:SetX` gives a), or None when the
    receiver is a call's result or not a name chain."""
    cursor = index - 2
    while cursor >= 0:
        if tokens[cursor].text == "]":
            depth = 0
            while cursor >= 0:
                depth += tokens[cursor].text == "]"
                depth -= tokens[cursor].text == "["
                cursor -= 1
                if depth == 0:
                    break
            continue
        if tokens[cursor].kind != "name":
            return None
        if cursor >= 2 and tokens[cursor - 1].text in {".", ":"}:
            if tokens[cursor - 2].text == "_G" and tokens[cursor - 1].text == ".":
                return tokens[cursor].text
            cursor -= 2
            continue
        return tokens[cursor].text
    return None


def is_call(token: Token) -> bool:
    """Whether `token`, just after a method name, opens a call: `(`, or Lua's `f"s"` and `f{}` forms."""
    return token.text in CALL_OPENERS or token.kind == "string"


def data_bound(tokens: list[Token]) -> set[str]:
    """Names bound, anywhere in the file, to one of Blizzard's data tables or an entry of one: `local x =
    AuctionCategories[1]`, `for _, x in ipairs(AuctionCategories)`, and names bound in turn from those."""
    sources = set(DATA_TABLES)
    while True:
        bound = set(sources)
        for index, token in enumerate(tokens):
            if token.text not in {"local", "for"}:
                continue
            cursor = index + 1
            names = []
            while tokens[cursor].kind == "name":
                names.append(tokens[cursor].text)
                if tokens[cursor + 1].text != ",":
                    break
                cursor += 2
            if not names:
                continue
            rest = tokens[cursor + 1 : cursor + 5]
            texts = [t.text for t in rest]
            if token.text == "local" and texts[:1] == ["="] and len(names) == 1:
                if rest[1].kind == "name" and rest[1].text in sources and texts[2:3] != ["("]:
                    bound.add(names[0])
            elif token.text == "for" and texts[:1] == ["in"]:
                # `in ipairs(t)`, `in pairs(t)`, `in next(t)` and `in next, t` all bind t's entries.
                if texts[1] in ITERATORS and texts[2] in {"(", ","} and texts[3] in sources:
                    bound.update(names[1:])
        if bound == sources:
            return bound - DATA_TABLES
        sources = bound


def data_writes(source: str) -> list[tuple[int, str]]:
    """`(line, message)` for each `Set*` method called on an entry of one of Blizzard's data tables."""
    tokens, comments = tokenize(source)
    try:
        bound = data_bound(tokens)
        findings = []
        for index, token in enumerate(tokens):
            if not (
                token.kind == "name"
                and SETTER.fullmatch(token.text)
                and tokens[index - 1].text in {".", ":"}
                and is_call(tokens[index + 1])
                and taint.flagged(comments, token.line)
            ):
                continue
            if token.text in DATA_SETTERS:
                # The shared rule flags `name(`; the call forms without parentheses are caught here.
                if tokens[index + 1].text != "(":
                    findings.append((token.line, f"taint-blizzard-call: {token.text} ({DATA_SETTERS[token.text]})"))
                continue
            root = receiver_root(tokens, index)
            if root is not None and (root in DATA_TABLES or root in bound):
                table = root if root in DATA_TABLES else "a Blizzard data table"
                findings.append(
                    (token.line, f"taint-blizzard-write: {token.text} on an entry of {table} writes its field")
                )
        return findings
    except IndexError as error:
        raise LuaSyntaxError("unexpected end of file") from error


def check(source: str) -> list[tuple[int, str]]:
    """`(line, message)` for each taint risk in `source`, shared rules and Tweaks' own; malformed Lua raises."""
    return sorted(taint.check(source, POLICY) + data_writes(source))


def run(paths: list[Path]) -> int:
    failed = False
    for path in paths:
        try:
            findings = check(path.read_text(encoding="utf-8"))
        except (LuaSyntaxError, OSError, UnicodeDecodeError) as error:
            print(f"{path}: {error}", file=sys.stderr)
            failed = True
            continue
        for line, message in findings:
            print(f"{path}:{line}: {message}")
            failed = True
    return int(failed)


def main() -> int:
    return run([Path(arg) for arg in sys.argv[1:]] or runtime_files(Path.cwd().resolve()))


if __name__ == "__main__":
    sys.exit(main())
