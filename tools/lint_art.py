"""Reject art drawn outside the Art helpers, where nothing keeps its shape (forever_tools.art)."""

import sys
from pathlib import Path

try:
    from tools.forever_tools import art
    from tools.typecheck_coverage import RUNTIME_DIRS, runtime_files
except ModuleNotFoundError:
    from forever_tools import art
    from typecheck_coverage import RUNTIME_DIRS, runtime_files

# The one file that may set art: every helper in it is under spec (tests/art_spec.lua).
HELPERS = frozenset({"UI/Art.lua"})
check = art.check


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    shipped = [*runtime_files(root), *(xml for folder in RUNTIME_DIRS for xml in (root / folder).rglob("*.xml"))]
    return art.run(root, [Path(arg) for arg in sys.argv[1:]] or shipped, HELPERS)


if __name__ == "__main__":
    sys.exit(main())
