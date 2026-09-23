"""Regression cases for Lua's expression-list expansion rules and lexer boundaries."""

import unittest

from tools.lint_multivalue import LuaSyntaxError, Parser


class MultivalueTest(unittest.TestCase):
    def test_expansion(self):
        cases = [
            "f(select(2, UnitClass(u)))",
            "f(x, select(2, f(1, 2)))",
            "owner:f(select(2, g()))",
            "local t = {x, select(2, g())}",
            "local t = {x; select(2, g());}",
            "return x, select(2, g())",
            "local f = function() return select(2, g()) end",
            "return {f(select(2, g()))}",
            "f(\n select(2,\n g())\n)",
            "f(select(2, g())) -- multi-value:",
        ]
        for source in cases:
            with self.subTest(source=source):
                self.assertEqual(len(Parser(source).check()), 1)

    def test_single_value_and_intentional_expansion(self):
        cases = [
            "f((select(2, UnitClass(u))))",
            "f(select(2, g()), x)",
            "local x = select(2, g())",
            "local x, y = select(2, g())",
            "return (select(2, g()))",
            "return select(2, g()) or 0",
            "return -select(2, g())",
            "return select(2, g()) + 1",
            "local t = {select(2, g()), x}",
            "local t = {name = select(2, g())}",
            "local t = {[select(2, g())] = select(2, g())}",
            "local t = {select(2, g()), name = x}",
            "return object.select(2, g())",
            "return select(2, g()).field",
            "return select(2, g())[1]",
            "return select(2, g())()",
            "f(select(2, g())) -- multi-value: forwarding the tuple",
            "return select(2, g()); -- multi-value: caller consumes the tuple",
            "local t = {select(2, g())} -- multi-value: collect the tuple",
            "-- f(select(2, g()))\nf()",
            "--[==[ return select(2, g()) ]==]\nf()",
            'local s = "f(select(2, g()))"',
            'local s = "escaped \\" return select(2, g())"',
            "local s = [==[ return select(2, g()) ]==]",
            "f 'select(2, g())'",
            "for i = 1, 2 do if i == 1 then f() elseif i == 2 then f() else f() end end",
            "for k, v in pairs(t) do repeat f() until v end",
            "function t:f(...) while true do break end; return ... end",
        ]
        for source in cases:
            with self.subTest(source=source):
                self.assertEqual(Parser(source).check(), [])

    def test_allowance_is_local(self):
        source = "f(select(2, g()))\nf(select(2, g())) -- multi-value: intentional tuple"
        self.assertEqual([line for line, _ in Parser(source).check()], [1])

    def test_lexical_errors_fail_closed(self):
        for source in ['"unterminated', "[=[unterminated", "--[=[unterminated", "f(select(2, g())", "return @"]:
            with self.subTest(source=source), self.assertRaises(LuaSyntaxError):
                Parser(source).check()


if __name__ == "__main__":
    unittest.main()
