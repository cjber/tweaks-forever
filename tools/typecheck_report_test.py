"""The runner must reject diagnostics at every severity and failed or incomplete checks."""

import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path

from tools.typecheck_report import report


class ReportTest(unittest.TestCase):
    def test_reports(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "diagnostics.json"
            log = Path(directory) / "server.log"
            log.write_text("server output")
            cases = [([], 0, 0), ({}, 0, 0), ([], 1, 1), ({}, 2, 1), ([{}], 0, 1)]
            for severity in range(1, 5):
                cases.append(
                    (
                        {
                            "file:///tmp/some%20file.lua": [
                                {
                                    "code": "unused-local",
                                    "severity": severity,
                                    "message": "unused\nvariable",
                                    "range": {"start": {"line": 2}},
                                }
                            ]
                        },
                        0,
                        1,
                    )
                )
            for diagnostics, status, expected in cases:
                with self.subTest(diagnostics=diagnostics, status=status):
                    path.write_text(json.dumps(diagnostics))
                    output = io.StringIO()
                    with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
                        self.assertEqual(report(path, status, log), expected)
                    if isinstance(diagnostics, dict) and diagnostics:
                        self.assertIn("/tmp/some file.lua:3: unused-local: unused variable", output.getvalue())
            for contents in ("", "{broken", "null"):
                path.write_text(contents)
                with contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(report(path, 0, log), 1)
            path.unlink()
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(report(path, 0, log), 1)


if __name__ == "__main__":
    unittest.main()
