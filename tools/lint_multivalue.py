"""Reject accidental select() and multi-return call expansion in Lua 5.1 calls, tables and returns."""

import sys
from pathlib import Path

try:
    from tools.forever_tools import multivalue
    from tools.forever_tools.lua import LuaSyntaxError
    from tools.typecheck_coverage import runtime_files
except ModuleNotFoundError:
    from forever_tools import multivalue
    from forever_tools.lua import LuaSyntaxError
    from typecheck_coverage import runtime_files

__all__ = ["LuaSyntaxError", "Parser", "check", "main"]

# Client functions and widget methods that return several values, called bare, through a namespace
# (C_Item.GetItemInfo) or as a method. As a final argument their extra values fill the callee's next
# parameters: CreateTexture(nil, region:GetDrawLayer()) passes the sublevel as the template name.
MULTI_RETURN = frozenset(
    """
    GetBackdropBorderColor GetBackdropColor GetBuildInfo GetCenter GetClampRectInsets GetCursorPosition
    GetDrawLayer GetFont GetHitRectInsets GetInstanceInfo GetItemInfo GetMinMaxValues GetNetStats GetPoint
    GetPointByName GetRGB GetRGBA GetRect GetScaledRect GetShadowColor GetShadowOffset GetSize
    GetStatusBarColor GetTexCoord GetTextColor GetTextInsets GetVertexColor GetXY UnitClass UnitFactionGroup
    UnitFullName UnitName UnitPosition UnitRace
    """.split()
)
# select(n, f()) exists to pick from f's values, so its own final argument expands by design.
RULES = multivalue.Rules(multi_return=MULTI_RETURN, spread_select=True)


class Parser(multivalue.Parser):
    def __init__(self, source: str):
        super().__init__(source, RULES)


def check(source: str) -> list[tuple[int, str]]:
    return multivalue.check(source, RULES)


def main() -> int:
    """Lint the paths given, or every Lua file the TOC and XML load graph reaches."""
    paths = [Path(arg) for arg in sys.argv[1:]] or runtime_files(Path.cwd().resolve())
    return multivalue.run(paths, RULES)


if __name__ == "__main__":
    sys.exit(main())
