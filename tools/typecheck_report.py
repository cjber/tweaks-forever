"""Make every LuaLS diagnostic fail the gate, including informational findings."""

import json
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse


def report(path: Path, status: int, log: Path) -> int:
    try:
        diagnostics = json.loads(path.read_text())
        if diagnostics == []:
            diagnostics = {}
        if not isinstance(diagnostics, dict):
            raise ValueError("expected a diagnostic object")
        count = 0
        for uri, findings in sorted(diagnostics.items()):
            file = Path(unquote(urlparse(uri).path))
            if file.is_relative_to(Path.cwd()):
                file = file.relative_to(Path.cwd())
            for finding in sorted(findings, key=lambda value: value["range"]["start"]["line"]):
                line = finding["range"]["start"]["line"] + 1
                message = finding["message"].replace("\n", " ")
                print(f"{file}:{line}: {finding['code']}: {message}")
                count += 1
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"LuaLS report failed: {error}", file=sys.stderr)
        print(log.read_text(), file=sys.stderr)
        return 1
    if status or count:
        print(f"LuaLS: {count} diagnostic(s), exit status {status}", file=sys.stderr)
        if status and not count:
            print(log.read_text(), file=sys.stderr)
        return 1
    print("LuaLS and multi-value lint: no diagnostics")
    return 0


if __name__ == "__main__":
    sys.exit(report(Path(sys.argv[1]), int(sys.argv[2]), Path(sys.argv[3])))
