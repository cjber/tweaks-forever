"""What counts as a phrase, and which UI calls with literal text the check rejects."""

import unittest
from pathlib import Path

from tools.phrases import encode, render, scan

PATH = Path("Example.lua")


def phrases(source: str) -> set[str]:
    return scan(PATH, source)[0]


def findings(source: str) -> list[int]:
    return [finding.line for finding in scan(PATH, source)[1]]


class PhrasesTest(unittest.TestCase):
    def test_phrases(self):
        self.assertEqual(phrases('f(L["Open"], L["a " .. "b"], L[key])'), {"Open", "a b"})
        source = """ns.Feature({
            key = "x", category = "Maps", name = "Show " .. 'it', tooltip = L["Built"]:format(1),
            options = { { "strip", "A strip" }, { "none", "Nothing" } },
            conflicts = { { addon = "Other", title = "Other Addon" } },
        })
        ns.ClickMode({ feature = "x", label = "Mark", tooltip = "Click items." })"""
        self.assertEqual(phrases(source), {"Maps", "Show it", "Built", "A strip", "Nothing", "Mark", "Click items."})
        self.assertEqual(phrases('f(L["say \\"hi\\"\\n"])'), {'say "hi"\n'})

    def test_declared_text_must_be_literal(self):
        self.assertEqual(findings('ns.Feature({ key = "x", name = NAME })'), [1])
        self.assertEqual(findings('ns.Feature({ key = "x", name = "A" .. suffix })'), [1])

    def test_sinks(self):
        rejected = [
            'label:SetText("Future Spells")',
            'ns.Print(("Sold %d stacks."):format(n))',
            'root:CreateButton("Equip " .. name)',
            'GameTooltip_AddNormalLine(tooltip, "Hint")',
            'Label(dialog, "Scale", "GameFontHighlight", 1, 2)',
        ]
        for source in rejected:
            with self.subTest(source=source):
                self.assertEqual(findings(source), [1])
        allowed = [
            'label:SetText(L["Future Spells"])',
            'ns.Print(L["Sold %d stacks."]:format(n))',
            'text:SetFormattedText("%s / %s", a, b)',
            'tooltip:AddLine(" ")',
            'label:SetText(value .. "%")',
            'text:SetText(mark.kind == "fishing" and ICON or name)',
            'root:CreateCheckbox(Coloured({ kind = "group", name = name }), f)',
            'line:SetText("|cffffd200" .. name .. "|r")',
            "button:SetText(CLOSE)",
        ]
        for source in allowed:
            with self.subTest(source=source):
                self.assertEqual(findings(source), [])

    def test_render(self):
        self.assertEqual(encode('a "b"\\'), '"a \\"b\\"\\\\"')
        self.assertEqual(render(["B", "a"]), 'L["B"] = true\nL["a"] = true\n')


if __name__ == "__main__":
    unittest.main()
