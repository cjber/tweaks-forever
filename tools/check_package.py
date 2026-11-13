#!/usr/bin/env python3
"""Check the packager's output before an upload (forever_tools.package): every file the TOC and XML load ships,
nothing from development does, a licence file and THIRD_PARTY.md do (with README's `## Credits` and THIRD_PARTY's
`## Players`, WFA-10 and WFA-31), and every spec that runs the addon passes on the packaged files.

    printf 'Package check\\n' > .release-notes.md
    <BigWigs packager release.sh> -d -z    # CI: the package job, with the release workflow's pinned packager
    python3 tools/check_package.py
"""

import sys
from pathlib import Path

try:
    from tools.forever_tools import package
except ModuleNotFoundError:
    from forever_tools import package

ROOT = Path(__file__).resolve().parent.parent
POLICY = package.Policy(
    addons=("TweaksForever", "ForeverCore"),
    specs=tuple(sorted(p.relative_to(ROOT).as_posix() for p in ROOT.glob("tests/*_spec.lua"))),
)

if __name__ == "__main__":
    sys.exit(package.main(ROOT, POLICY))
