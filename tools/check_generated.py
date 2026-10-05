"""Regenerate pinned data in a scratch tree and reject stale or unstable output."""

import argparse
import subprocess
import sys
from pathlib import Path

from forever_tools import generated
from forever_tools.report import Hint

ROOT = Path(__file__).resolve().parent.parent
DATA = (
    "Data/Overlays.lua",
    "Data/CampBenefits.lua",
    "Data/ZoneLevels.lua",
    "Data/DungeonEntrances.lua",
    "Data/ClassSpells.lua",
    "Data/ForeverQuests.lua",
    "media/TooltipBorderModern.tga",
    "media/TooltipBorderRetail.tga",
    "Locales/phrases.txt",
)


compare = generated.compare


# CampBenefits is an array of { aura, feature, effect, seconds, numbers } records keyed by aura.
HINTS = {"ns.CampBenefits": Hint(("aura", "feature", "effect", "seconds", "numbers"), key=0)}


def run(root, *command):
    subprocess.run(command, cwd=root, check=True)


def outputs(root):
    files = set(DATA)
    files.update(str(path.relative_to(root)) for path in (root / "Data").glob("*.lua"))
    return {name: (root / name).read_bytes() for name in sorted(files)}


def regenerate(root, offline):
    for name in DATA:
        (root / name).unlink()
    mode = ["--offline"] if offline else []
    for generator in ("overlays", "camp", "zonelevels", "dungeons", "classspells", "foreverquests"):
        run(root, sys.executable, f"tools/gen_{generator}.py", *mode)
    run(root, sys.executable, "tools/tooltip_border.py")
    run(root, sys.executable, "-m", "tools.phrases", "--write")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--offline", action="store_true", help="require cached inputs in the main checkout's tools/.cache"
    )
    generated.check_generated(
        ROOT,
        outputs=outputs,
        regenerate=regenerate,
        offline=parser.parse_args().offline,
        hints=HINTS,
        success="Generated data and phrases are current and reproducible.",
        prefix="tweaks-regenerate-",
    )


if __name__ == "__main__":
    main()
