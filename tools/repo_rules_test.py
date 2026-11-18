"""The repository rules over the cases each one was written for."""

import unittest

from tools.repo_rules import (
    chat_alerts,
    item_info_listeners,
    setting_callbacks,
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
        self.assertEqual(chat_alerts({"Bags/Junk.lua": 'ns.Print(L["Sold"])\n'}), [], "a receipt")
        self.assertEqual(len(chat_alerts({"Features/RareAlerts.lua": 'ns.Print(L["Rare"])\n'})), 1)
        self.assertEqual(len(chat_alerts({"Bags/Junk.lua": 'print("x")\n'})), 1, "only ns.Print writes to chat")
        self.assertEqual(len(chat_alerts({"UI/X.lua": "DEFAULT_CHAT_FRAME:AddMessage(x)\n"})), 1)
        self.assertEqual(len(chat_alerts({"UI/X.xml": "<OnLoad>ChatFrame1:AddMessage(x)</OnLoad>\n"})), 1)
        self.assertEqual(chat_alerts({"UI/X.lua": "ns.Alert(text) -- not ns.Print(text)\nf:Blueprint(x)\n"}), [])

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
