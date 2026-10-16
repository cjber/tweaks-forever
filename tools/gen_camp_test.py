"""The camp benefit rows follow the Camp Benefits summary, with the tent placed from its own spell."""

import unittest

from tools.gen_camp import CAMP_BENEFITS, FEATURES, TENT, TENT_AURA, benefits

FIRST = 1230587


class FakeSpells:
    """The parts of gen_camp.Spells that benefits() reads, for a summary of `auras` (one $w1 branch each)."""

    def __init__(self, auras):
        branches = [f"$?a{aura}[Feature {aura}: Stat increased by ${aura}w1.\r\n\r\n][]" for aura in auras]
        self.texts = {
            CAMP_BENEFITS: "Gained the following camp benefits:\r\n\r\n" + "".join(branches),
            TENT: "Increases Rested Experience after $d spent resting near the tent.",
            TENT_AURA: "You cannot gain more rested experience from a Camp Tent for $d.",
        }

    def description(self, spell):
        return self.texts[spell]

    def effect_row(self, spell, index):
        return {"EffectBasePointsF": str(spell % 100), "EffectAuraPeriod": "0"}

    def seconds(self, spell):
        return 30 if spell == TENT else 3600


def features(count, first=FIRST):
    return [first + n for n in range(count)]


class CampTest(unittest.TestCase):
    def test_tent_first_from_its_own_spell(self):
        rows = benefits(FakeSpells(features(FEATURES)))
        self.assertEqual(len(rows), FEATURES + 1)
        self.assertEqual(
            rows[0],
            (TENT_AURA, "Tent", "Increases Rested Experience after 30 sec spent resting near the tent.", None, []),
        )
        self.assertEqual(rows[1], (FIRST, f"Feature {FIRST}", "Stat increased by 87", 3600, ["87"]))

    def test_a_changed_summary_fails(self):
        cases = [
            ("features, not 9", features(FEATURES - 1)),
            ("features, not 9", features(FEATURES + 1)),
            ("the tent again", [TENT_AURA, *features(FEATURES - 1)]),
        ]
        for message, auras in cases:
            with self.subTest(count=len(auras), tent=TENT_AURA in auras):
                with self.assertRaisesRegex(ValueError, message):
                    benefits(FakeSpells(auras))

    def test_a_renumbered_tent_lockout_fails(self):
        spells = FakeSpells(features(FEATURES))
        spells.texts[TENT_AURA] = "Something else."
        with self.assertRaisesRegex(ValueError, "rest lockout"):
            benefits(spells)


if __name__ == "__main__":
    unittest.main()
