#!/usr/bin/env python3
# sift-scope: all
# sift-fix: delete the pattern from hashFiles(), or fix its path; a pattern that matches nothing adds nothing to the key
"""Every pattern a workflow passes to hashFiles() matches at least one file in the repository.

A cache key built from a pattern that matches nothing never changes when the file it was meant to track does.
Patterns are literal quoted strings; `*` matches within a path segment and `**` across segments.
"""

import os
import re
import sys

RULE = os.environ["SIFT_RULE"]
WORKFLOW = re.compile(r"^\.github/workflows/[^/]+\.ya?ml$")
CALL = re.compile(r"hashFiles\(([^)]*)\)")
PATTERN = re.compile(r"'([^']*)'")


def matcher(pattern):
    parts = re.split(r"(\*\*/?|\*)", pattern)
    body = "".join(".*" if p.startswith("**") else "[^/]*" if p == "*" else re.escape(p) for p in parts)
    return re.compile(body + r"\Z")


def main():
    with open(os.environ["SIFT_FILES"], encoding="utf-8") as listing:
        paths = [p for p in listing.read().splitlines() if p]
    hits = []
    for path in paths:
        if not WORKFLOW.match(path):
            continue
        with open(path, encoding="utf-8") as source:
            for number, line in enumerate(source, 1):
                for call in CALL.findall(line):
                    for pattern in PATTERN.findall(call):
                        if pattern.startswith("!"):
                            continue
                        match = matcher(pattern).match
                        if not any(match(p) for p in paths):
                            hits.append(f"{path}:{number}: {RULE} hashFiles pattern `{pattern}` matches no file")
    for hit in hits:
        print(hit)
    return 1 if hits else 0


sys.exit(main())
