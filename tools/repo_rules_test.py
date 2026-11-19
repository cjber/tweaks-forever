"""The repository rules over the cases each one was written for."""

import unittest

from tools.repo_rules import (
    chat_alerts,
    item_info_listeners,
    setting_callbacks,
    unit_events,
    unmatched_hashfiles,
    unused_luacheck_globals,
)

CALLBACK = 'Settings.SetOnValueChangedCallback("TweaksForever_x", print)\n'
WORKFLOW = "      - with:\n          key: k-${{ hashFiles('tools/gen_*.py', %s) }}\n"


class SettingCallbackTest(unittest.TestCase):
    def test_only_core_and_specs_register_a_callback(self):
        stub = 'local stub = { SetOnValueChangedCallback = print }\nstub.SetOnValueChangedCallback("x", print)\n'
        self.assertEqual(setting_callbacks({"Core/Core.lua": CALLBACK, "tests/x_spec.lua": stub}), [])
        self.assertEqual(len(setting_callbacks({"Errors.lua": 'print("quiet")\n' + CALLBACK})), 1)
        self.assertEqual(len(setting_callbacks({"Core.lua": CALLBACK})), 1)


class LuacheckGlobalTest(unittest.TestCase):
    def test_only_the_item_info_owner_listens_for_item_data(self):
        listen = 'ns.On("GET_ITEM_INFO_RECEIVED", function() end)\n'
        self.assertEqual(item_info_listeners({"Core/ItemInfo.lua": listen, "tests/junk_spec.lua": listen}), [])
        self.assertEqual(len(item_info_listeners({"Bags/Junk.lua": listen})), 1)
        self.assertEqual(len(item_info_listeners({"UI/X.lua": "f:RegisterEvent('ITEM_DATA_LOAD_RESULT')\n"})), 1)
        self.assertEqual(item_info_listeners({"Bags/Junk.lua": "ns.AwaitItem(info.itemID, OnItemInfo)\n"}), [])
        xml = '<OnLoad>self:RegisterEvent("GET_ITEM_INFO_RECEIVED")</OnLoad>\n'
        self.assertEqual(len(item_info_listeners({"UI/Frame.xml": xml})), 1, "an XML OnLoad listens too")

    def test_alerts_go_on_screen(self):
        self.assertEqual(chat_alerts({"Core/Core.lua": 'print("x")\n', "tests/x_spec.lua": 'print("ok")\n'}), [])
        sold = 'ns.Print(L["Sold %d junk stacks for %s."]:format(n, money))\n'
        self.assertEqual(chat_alerts({"Bags/Junk.lua": sold}), [], "a receipt")
        self.assertEqual(len(chat_alerts({"Bags/Junk.lua": 'ns.Print(L["Rare nearby"])\n'})), 1, "a new line there")
        self.assertEqual(len(chat_alerts({"UI/WhatsNew.lua": 'ns.Print(L["Rare"])\n'})), 1, "per call, not per file")
        self.assertEqual(chat_alerts({"UI/WhatsNew.lua": "\t\tns.Print(message)\n"}), [])
        self.assertEqual(len(chat_alerts({"Features/RareAlerts.lua": 'ns.Print(L["Rare"])\n'})), 1)
        self.assertEqual(len(chat_alerts({"Bags/Junk.lua": 'print("x")\n'})), 1, "only ns.Print writes to chat")
        self.assertEqual(len(chat_alerts({"Features/X.lua": '_G.print("x")\n'})), 1)
        self.assertEqual(len(chat_alerts({"Features/X.lua": '_G["print"]("x")\n'})), 1)
        self.assertEqual(len(chat_alerts({"UI/X.lua": "DEFAULT_CHAT_FRAME:AddMessage(x)\n"})), 1)
        self.assertEqual(len(chat_alerts({"UI/X.xml": "<OnLoad>ChatFrame1:AddMessage(x)</OnLoad>\n"})), 1)
        self.assertEqual(chat_alerts({"UI/X.lua": "ns.Alert(text) -- not ns.Print(text)\nf:Blueprint(x)\n"}), [])
        self.assertEqual(len(chat_alerts({"Features/X.lua": 'local P = ns.Print\nP(L["Rare"])\n'})), 1, "an alias")
        self.assertEqual(len(chat_alerts({"Features/X.lua": 'ns["Print"]("x")\n'})), 1)
        self.assertEqual(len(chat_alerts({"Features/X.lua": "ns.Print\n"})), 1, "a call split over lines")
        self.assertEqual(len(chat_alerts({"Features/X.lua": 'local s = "--" ns.Print(s)\n'})), 1, "-- in a string")
        self.assertEqual(chat_alerts({"Core/Core.lua": "function ns.Print(message)\n"}), [])

    def test_unit_events_name_their_unit(self):
        self.assertEqual(len(unit_events({"UI/X.lua": 'ns.On("UNIT_PET", fn)\n'})), 1)
        self.assertEqual(
            unit_events({"UI/X.lua": 'ns.OnUnit("UNIT_PET", "player", fn)\nns.On("PLAYER_LOGIN", fn)\n'}), []
        )
        self.assertEqual(unit_events({"tests/x_spec.lua": 'ns.On("UNIT_PET", fn)\n'}), [])
        listed = 'for _, event in ipairs({\n\t"PLAYER_LEVEL_UP",\n\t"UNIT_PET",\n}) do\n\tns.On(event, fn)\nend\n'
        self.assertEqual(len(unit_events({"UI/X.lua": listed})), 1, "a name in a list registered in a loop")
        self.assertEqual(len(unit_events({"UI/X.lua": 'f:RegisterEvent("UNIT_AURA")\n'})), 1)
        self.assertEqual(len(unit_events({"UI/X.lua": 'ns.On(\n\t"UNIT_PET",\n\tfn\n)\n'})), 1, "a multiline call")
        ok = 'f:RegisterUnitEvent("UNIT_AURA", "player")\nif event == "UNIT_FACTION" then\n'
        self.assertEqual(unit_events({"UI/X.lua": ok}), [])

    def test_an_entry_nothing_names_fails(self):
        config = '\nread_globals = {\n\t"CreateFrame",\n\t"GetLocale",\n\t"tInvert",\n}\n'
        files = {".luacheckrc": config, "a.lua": 'CreateFrame("Frame")', "Locales/phrases.txt": "GetLocale()"}
        hits = unused_luacheck_globals(files)
        self.assertEqual([hit.split(": ")[0] for hit in hits], [".luacheckrc:5"])


class HashFilesTest(unittest.TestCase):
    def test_a_pattern_matching_nothing_fails(self):
        files = {"tools/gen_a.py": "", "tools/uv.lock": ""}
        self.assertEqual(unmatched_hashfiles({**files, ".github/workflows/ci.yml": WORKFLOW % "'**/*.lock'"}), [])
        dead = unmatched_hashfiles({**files, ".github/workflows/ci.yml": WORKFLOW % "'tools/db2.py'"})
        self.assertEqual([hit.split(": ")[0] for hit in dead], [".github/workflows/ci.yml:2"])


if __name__ == "__main__":
    unittest.main()
