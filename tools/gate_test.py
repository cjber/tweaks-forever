"""The changed-files gate leaves the whole-repo LuaLS run to CI.

`gate --changed` must call `tools/typecheck.sh --no-luals` in every addon, as the other Forever addons do:
LuaLS holds about 5 GB on a machine several sessions share, and CI already runs it as a required check.
"""

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def load_gate():
    spec = importlib.util.spec_from_file_location("gate", ROOT / "tools" / "gate.py")
    if spec is None or spec.loader is None:
        raise AssertionError("cannot load tools/gate.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ChangedSkipsLuaLSTests(unittest.TestCase):
    def setUp(self):
        self.gate = load_gate()

    def step(self, name):
        for step in self.gate.STEPS:
            if step.name == name:
                return step
        self.fail(f"no {name} step in the gate")

    def test_typecheck_skips_luals_under_changed(self):
        self.assertEqual(self.step("typecheck").changed_args, ("--no-luals",))

    def test_only_typecheck_carries_a_changed_variant(self):
        carrying = [step.name for step in self.gate.STEPS if step.changed_args]
        self.assertEqual(carrying, ["typecheck"])

    def test_typecheck_script_accepts_the_flag(self):
        script = (ROOT / "tools" / "typecheck.sh").read_text(encoding="utf-8")
        self.assertIn('if [ "${1:-}" = "--no-luals" ]; then', script)
        # The flag exits after the checks that need no LuaLS, so CI's run is the only one that starts it.
        self.assertIn("LuaLS left to CI (--no-luals)", script)


if __name__ == "__main__":
    unittest.main()
