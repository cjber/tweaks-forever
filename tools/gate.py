#!/usr/bin/env python3
"""The fast local gate: the CI checks that need no packager, game build or network, and nothing else.

    python3 tools/gate.py             # every step
    python3 tools/gate.py --changed   # only the steps the diff against origin/main reaches; tools/ reaches all
                                      # but LuaLS itself, which stays in CI

Every step runs even after one fails, as in CI, and the exit status is 1 when any failed. The specs load ForeverCore
from $FOREVER_CORE, else the sibling ../forever-core checkout; set it when working from a worktree. The simulator,
package, workflow and secret jobs stay in CI.
"""

import argparse
import fnmatch
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UV = ("uv", "run", "--project", "tools", "--frozen", "--group", "dev")
LUA = ("*.lua", "*.toc", "*.xml")


@dataclass(frozen=True)
class Step:
    name: str
    argv: tuple[str, ...]
    # fnmatch patterns over changed paths ("*" crosses folders); empty means the step runs for any change.
    reaches: tuple[str, ...] = ()
    # The step loads ForeverCore from $FOREVER_CORE.
    needs_core: bool = False
    # Arguments --changed adds, for a step with a part too heavy for the shared machine that it leaves to CI.
    changed_args: tuple[str, ...] = ()


STEPS = (
    Step("stylua", ("stylua", "--check", "."), ("*.lua", "stylua.toml", ".styluaignore")),
    Step("luacheck", ("luacheck", "."), ("*.lua", ".luacheckrc")),
    Step(
        "typecheck",
        ("bash", "tools/typecheck.sh"),
        LUA
        + (
            "types/*",
            "Locales/*",
            "docs/*",
            "README.md",
            ".luarc.json",
            ".editorconfig",
            "stylua.toml",
            "ruff.toml",
            ".pkgmeta",
        ),
        # The whole-repo LuaLS run inside typecheck.sh holds about 5 GB; --changed leaves it to CI, which
        # runs it as a required check. Every other check in that script still runs.
        changed_args=("--no-luals",),
    ),
    Step("specs", ("python3", "-m", "tools.forever_tools.specs"), LUA, needs_core=True),
    Step("deadcode", ("python3", "tools/deadcode.py", "--check"), LUA),
    Step("ruff check", (*UV, "ruff", "check", "tools"), ("*.py", "ruff.toml", "tools/pyproject.toml")),
    Step("ruff format", (*UV, "ruff", "format", "--check", "tools"), ("*.py", "ruff.toml", "tools/pyproject.toml")),
    Step(
        "assets",
        ("python3", "-m", "tools.forever_tools.assets"),
        LUA + ("media/*", "*.png", "*.tga", "*.blp", ".pkgmeta"),
    ),
    Step(
        "changelog",
        ("python3", "tools/changelog.py", "--check", "--base", "origin/main"),
        ("CHANGELOG.md", "changes/*", "tools/changelog.py"),
    ),
    Step(
        "credits",
        ("python3", "tools/forever_tools/credits.py", "--check"),
        ("THIRD_PARTY.md", "README.md", "docs/curseforge.md", "Data/Credits.lua"),
    ),
    Step("api docs", ("python3", "tools/check_api_docs.py"), ("*API*.lua", "docs/api.md")),
    Step("menu scroll", ("python3", "tools/check_menu_scroll.py"), LUA),
    Step("screenshots", ("python3", "tools/check_screenshots.py")),
    Step(
        "generated", ("python3", "tools/check_generated.py", "--offline"), ("Data/*", "Nav/*", "media/*", "Locales/*")
    ),
    Step("phrases", ("python3", "-m", "tools.phrases", "--check"), ("Locales/*",) + LUA),
    Step("repo rules", ("python3", "tools/repo_rules.py")),
    # The vendored copies match their MANIFEST.json, offline.
    Step("vendored tools", ("python3", "tools/forever_tools/sync.py", "check"), ("tools/forever_tools/*",)),
    Step("vendored sim", ("python3", "tools/forever_sim/sync.py", "check"), ("tools/forever_sim/*",)),
    Step(
        "ty",
        (*UV, "ty", "check", "tools", "--extra-search-path", ".", "--extra-search-path", "tools"),
        ("*.py", "tools/pyproject.toml"),
    ),
)


def git(*args: str) -> list[str]:
    done = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=True)
    return done.stdout.split("\n") if done.stdout else []


def changed_paths(base: str) -> set[str]:
    merge_base = git("merge-base", base, "HEAD")[0]
    paths = git("diff", "--name-only", merge_base) + git("ls-files", "--others", "--exclude-standard")
    return {path for path in paths if path}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--changed", action="store_true", help="run only the steps the diff against --base reaches")
    parser.add_argument("--base", default="origin/main", help="the branch to diff against (default: origin/main)")
    args = parser.parse_args()
    changed = changed_paths(args.base) if args.changed else set()
    # A change under tools/ can alter any check, so it reaches every step.
    everything = not args.changed or any(path.startswith("tools/") for path in changed)
    selected = [
        step
        for step in STEPS
        if everything or not step.reaches or any(fnmatch.fnmatch(p, g) for p in changed for g in step.reaches)
    ]
    env = dict(os.environ)
    if any(step.needs_core for step in selected):
        # Resolved from the caller's directory, so the steps (run from the repo root) see the same checkout.
        core = Path(env.get("FOREVER_CORE") or ROOT.parent / "forever-core").resolve()
        if not core.is_dir():
            print(
                f"ForeverCore checkout not found at {core}: set FOREVER_CORE to a cjber/forever-core checkout",
                file=sys.stderr,
            )
            return 2
        env["FOREVER_CORE"] = str(core)
    failed: list[str] = []
    for step in STEPS:
        if step not in selected:
            print(f"-- {step.name}: skipped, the diff does not reach it", flush=True)
            continue
        argv = (*step.argv, *step.changed_args) if args.changed and step.changed_args else step.argv
        print(f"== {step.name}: {' '.join(argv)}", flush=True)
        started = time.monotonic()
        try:
            code = subprocess.run(argv, cwd=ROOT, env=env, stdin=subprocess.DEVNULL).returncode
        except OSError as exc:
            print(f"== {step.name}: cannot start: {exc}", flush=True)
            code = 127
        print(
            f"== {step.name}: {'ok' if code == 0 else f'FAILED (exit {code})'} in {time.monotonic() - started:.1f}s",
            flush=True,
        )
        if code != 0:
            failed.append(step.name)
    if failed:
        print("Failed: " + ", ".join(failed), file=sys.stderr)
        return 1
    print("Gate passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
