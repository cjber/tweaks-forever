"""Regression cases for the Blizzard-taint lint: what it must flag, what stays clean, and the escape comment."""

import unittest

from tools.lint_taint import check


class TaintTest(unittest.TestCase):
    def test_flagged(self):
        cases = {
            "ObjectiveTrackerManager:SetModuleContainer(module, ObjectiveTrackerFrame)": "taint-blizzard-call",
            'hooksecurefunc(ns.frame, "SetUnit", f)': "taint-method-hook",
            'local frame = ProfessionsFrame; hooksecurefunc(frame, "RefreshRightTabs", f)': "taint-method-hook",
            'hooksecurefunc(ProfessionsFrame, \n"RightTabSelected", f)': "taint-method-hook",
            'hooksecurefunc(GameTooltip, "SetUnit", f)': "taint-method-hook",
            'local function F(frame) hooksecurefunc(frame, "UpdateAnchors", f) end': "taint-method-hook",
            'hooksecurefunc(ContainerFrameItemButtonMixin, "OnLoad", f)': "taint-method-hook",
            "bag:UpdateFrameSize()": "taint-blizzard-call",
            "for _, b in bag:EnumerateValidItems() do end": "taint-blizzard-call",
            "UpdateContainerFrameAnchors()": "taint-blizzard-call",
            "local n = frame:GetBagSize()": "taint-blizzard-call",
            "initializer:SetParentInitializer(parent)": "taint-blizzard-call",
            "StaticPopupDialogs.TF_CONFIRM = {}": "taint-blizzard-write",
            'StaticPopupDialogs["TF_CONFIRM"] = {}': "taint-blizzard-write",
            "WorldMapFrame.tfPins = {}": "taint-blizzard-write",
            "function UIErrorsFrame.ShouldDisplayMessageType() end": "taint-blizzard-write",
            "function GameTooltip:SetUnit() end": "taint-blizzard-write",
        }
        for source, code in cases.items():
            with self.subTest(source=source):
                findings = check(source)
                self.assertEqual(len(findings), 1, findings)
                self.assertTrue(findings[0][1].startswith(code + ":"), findings)

    def test_clean(self):
        cases = [
            'hooksecurefunc("ContainerFrame_GenerateFrame", f)',
            'hooksecurefunc(ns, "RefreshConflicts", f)',
            'local Model = {}\nhooksecurefunc(Model, "Layout", f)',
            'frame:HookScript("OnShow", f)',
            "TooltipDataProcessor.AddTooltipPostCall(kind, f)",
            "local Model = {}\nModel.lift = 0\nfunction Model.Layout() end",
            "ns.db = {}\nfunction ns.Print() end",
            "local t = {}\nt[key] = true",
            "local function F(frame) frame.x = 1 end",
            "for _, v in ipairs(list) do v.seen = true end",
            "SlashCmdList.TWEAKSFOREVER = f",
            "function TweaksForeverDungeonEntrancePinMixin:OnLoad() end",
            "local t = { name = 1, [2] = 3 }",
            "if a == b then end",
            'local s = "bag:UpdateFrameSize()"',
            "-- hooksecurefunc(GameTooltip, 'SetUnit', f)\nf()",
            "local function UpdateAnchors() end\nlocal Model = {}\nfunction Model.GetRows() end",
            "WorldMapFrame.tf = 1 -- taint-ok: our own field, read only by this addon",
            "bag:UpdateFrameSize() -- taint-ok: run from a secure delegate",
        ]
        for source in cases:
            with self.subTest(source=source):
                self.assertEqual(check(source), [])

    def test_blizzard_data_table_setters(self):
        # #169: a Blizzard setter on an auction category stores the addon's value where Browse reads it.
        flagged = [
            "AuctionCategories[1]:SetDetailColumnString(ITEM_LEVEL_ABBR)",
            "local c = AuctionCategories[1]\nc:SetDetailColumnString(x)",
            "for _, category in ipairs(AuctionCategories) do category:SetFlag(x) end",
            "local cats = AuctionCategories\nfor _, c in pairs(cats) do c:SetSubCategories(t) end",
            "local c = AuctionCategories[2]\nc.subCategories[1]:SetName(x)",
            "entry.category:SetDetailColumnString(on and ITEM_LEVEL_ABBR or entry.detail)",
        ]
        for source in flagged:
            with self.subTest(source=source):
                findings = check(source)
                self.assertEqual(len(findings), 1, findings)
                self.assertTrue(
                    findings[0][1].startswith("taint-blizzard-write:")
                    or findings[0][1].startswith("taint-blizzard-call:"),
                    findings,
                )
        clean = [
            "local n = #AuctionCategories",
            "local t = {}\nfor i in ipairs(AuctionCategories) do t[i] = true end",
            "local name = AuctionCategories[1].name",
            "local c = AuctionCategories[1]\nlocal d = c:GetDetailColumnString()",
            "GameTooltip:SetOwner(UIParent)\nframe:SetPoint('TOP')",
            "local own = {}\nown[1]:SetText(x)",
            "AuctionCategories[1]:SetFlag(x) -- taint-ok: a verified safe contract",
        ]
        for source in clean:
            with self.subTest(source=source):
                self.assertEqual(check(source), [])

    def test_empty_escape_still_flags(self):
        self.assertEqual(len(check("bag:UpdateFrameSize() -- taint-ok:")), 1)


if __name__ == "__main__":
    unittest.main()
