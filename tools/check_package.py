#!/usr/bin/env python3
"""Check the packager's output before an upload (forever_tools.package): every file the TOC and XML load ships,
nothing from development does, a licence file and THIRD_PARTY.md do (with README's `## Credits` and THIRD_PARTY's
`## Ideas and contributors`, WFA-10 and WFA-31), and every spec that runs the addon passes on the packaged files.

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
# Every spec but those that read the checkout rather than the addon: auctionator_spec loads LibAHTab from the
# repository layout (the package ships it as its own folder, which the TOC check above covers).
REPO_ONLY = {"tests/auctionator_spec.lua"}
POLICY = package.Policy(
    addons=("TweaksForever", "LibAHTab"),
    specs=tuple(
        spec
        for spec in sorted(p.relative_to(ROOT).as_posix() for p in ROOT.glob("tests/*_spec.lua"))
        if spec not in REPO_ONLY
    ),
)

if __name__ == "__main__":
    sys.exit(package.main(ROOT, POLICY))
