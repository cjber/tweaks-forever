"""Reject accidental select() expansion in Lua 5.1 calls, tables and returns."""

import re
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Token:
    text: str
    line: int
    kind: str = "symbol"


class LuaSyntaxError(ValueError):
    pass


LONG = re.compile(r"\[(=*)\[")
WORD = re.compile(r"[A-Za-z_][A-Za-z_0-9]*")
NUMBER = re.compile(r"(?:0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)")
OPERATORS = re.compile(r"\.\.\.|\.\.|==|~=|<=|>=|[+*/%^#=<>;:,{}\[\]().-]")
KEYWORDS = set(
    "and break do else elseif end false for function if in local nil not or repeat return then true until while".split()
)


def tokenize(source: str) -> tuple[list[Token], dict[int, str]]:
    tokens: list[Token] = []
    comments: dict[int, str] = {}
    pos, line = 0, 1
    while pos < len(source):
        start, start_line = pos, line
        char = source[pos]
        if char.isspace():
            line += char == "\n"
            pos += 1
            continue
        comment = source.startswith("--", pos)
        if comment:
            pos += 2
        long = LONG.match(source, pos)
        if long:
            close = "]" + long[1] + "]"
            end = source.find(close, long.end())
            if end < 0:
                raise LuaSyntaxError(f"{line}: unterminated long string/comment")
            pos = end + len(close)
        elif comment:
            end = source.find("\n", pos)
            pos = len(source) if end < 0 else end
            comments[line] = source[start + 2 : pos].strip()
        elif char in "\"'":
            pos += 1
            while pos < len(source) and source[pos] != char:
                if source[pos] == "\\":
                    pos += 1
                elif source[pos] == "\n":
                    raise LuaSyntaxError(f"{line}: newline in quoted string")
                pos += 1
            if pos >= len(source):
                raise LuaSyntaxError(f"{line}: unterminated quoted string")
            pos += 1
        else:
            match = WORD.match(source, pos) or NUMBER.match(source, pos) or OPERATORS.match(source, pos)
            if not match:
                raise LuaSyntaxError(f"{line}: unexpected character {char!r}")
            pos = match.end()
        value = source[start:pos]
        line += value.count("\n")
        if not comment:
            kind = "string" if long or char in "\"'" else "symbol"
            if WORD.fullmatch(value) and value not in KEYWORDS:
                kind = "name"
            elif NUMBER.fullmatch(value):
                kind = "number"
            tokens.append(Token(value, start_line, kind))
    tokens.append(Token("<eof>", line))
    return tokens, comments


# A Pratt expression parser preserves whether an expression is exactly a bare select call.
# Balanced-token searches alone confuse keyed table fields, operators and nested function returns.
BINARY = {
    "or": (1, 2),
    "and": (2, 3),
    "<": (3, 4),
    ">": (3, 4),
    "<=": (3, 4),
    ">=": (3, 4),
    "~=": (3, 4),
    "==": (3, 4),
    "..": (4, 4),
    "+": (5, 6),
    "-": (5, 6),
    "*": (6, 7),
    "/": (6, 7),
    "%": (6, 7),
    "^": (8, 8),
}
BLOCK_END = {"end", "else", "elseif", "until", "<eof>"}


class Parser:
    def __init__(self, source: str):
        self.tokens, self.comments = tokenize(source)
        self.index = 0
        self.findings: list[tuple[int, str]] = []

    @property
    def current(self) -> Token:
        return self.tokens[self.index]

    def take(self, value: str | None = None) -> Token:
        token = self.current
        if value is not None and token.text != value:
            raise LuaSyntaxError(f"{token.line}: expected {value!r}, got {token.text!r}")
        if token.text == "<eof>":
            raise LuaSyntaxError(f"{token.line}: unexpected end of file")
        self.index += 1
        return token

    def accept(self, value: str) -> bool:
        if self.current.text != value:
            return False
        self.take()
        return True

    def name(self) -> Token:
        if self.current.kind != "name":
            raise LuaSyntaxError(f"{self.current.line}: expected a name")
        return self.take()

    def flag(self, select: Token | None, context: str) -> None:
        if select is None:
            return
        end_line = self.tokens[self.index - 1].line
        if re.fullmatch(r"multi-value:\s*\S.*", self.comments.get(end_line, "")):
            return
        self.findings.append((select.line, f"multi-value-select: parenthesise select() in the last {context}"))

    def expressions(self) -> Token | None:
        last = self.expression()
        while self.accept(","):
            last = self.expression()
        return last

    def arguments(self) -> None:
        if self.accept("("):
            last = None if self.current.text == ")" else self.expressions()
            self.take(")")
            self.flag(last, "call argument")
        elif self.current.text == "{":
            self.table()
        elif self.current.kind == "string":
            self.take()
        else:
            raise LuaSyntaxError(f"{self.current.line}: expected call arguments")

    def table(self) -> None:
        self.take("{")
        last = None
        while self.current.text != "}":
            if self.accept("["):
                self.expression()
                self.take("]")
                self.take("=")
                self.expression()
                last = None
            elif self.current.kind == "name" and self.tokens[self.index + 1].text == "=":
                self.take()
                self.take("=")
                self.expression()
                last = None
            else:
                last = self.expression()
            if not (self.accept(",") or self.accept(";")):
                break
        self.take("}")
        self.flag(last, "table element")

    def function(self) -> None:
        self.take("(")
        if self.current.text != ")":
            while True:
                if self.accept("..."):
                    break
                self.name()
                if not self.accept(","):
                    break
        self.take(")")
        self.block()
        self.take("end")

    def expression(self, minimum: int = 0) -> Token | None:
        token = self.current
        bare_name = None
        if token.text in {"not", "-", "#"}:
            self.take()
            self.expression(7)
        elif self.accept("function"):
            self.function()
        elif token.text == "{":
            self.table()
        elif self.accept("("):
            self.expression()
            self.take(")")
        elif token.kind in {"name", "string", "number"} or token.text in {"nil", "true", "false", "..."}:
            self.take()
            if token.kind == "name":
                bare_name = token
        else:
            raise LuaSyntaxError(f"{token.line}: expected expression, got {token.text!r}")
        result = None
        while True:
            if self.accept("."):
                self.name()
            elif self.accept("["):
                self.expression()
                self.take("]")
            elif self.accept(":"):
                self.name()
                self.arguments()
            elif self.current.text in {"(", "{"} or self.current.kind == "string":
                self.arguments()
                result = bare_name if bare_name and bare_name.text == "select" else None
                bare_name = None
                continue
            else:
                break
            bare_name, result = None, None
        while self.current.text in BINARY:
            left, right = BINARY[self.current.text]
            if left < minimum:
                break
            self.take()
            self.expression(right)
            result = None
        return result

    def block(self) -> None:
        while self.current.text not in BLOCK_END:
            if self.accept(";") or self.accept("break"):
                continue
            if self.accept("return"):
                if self.current.text not in BLOCK_END | {";"}:
                    last = self.expressions()
                    self.accept(";")
                    self.flag(last, "return value")
            elif self.accept("do"):
                self.block()
                self.take("end")
            elif self.accept("while"):
                self.expression()
                self.take("do")
                self.block()
                self.take("end")
            elif self.accept("repeat"):
                self.block()
                self.take("until")
                self.expression()
            elif self.accept("if"):
                self.expression()
                self.take("then")
                self.block()
                while self.accept("elseif"):
                    self.expression()
                    self.take("then")
                    self.block()
                if self.accept("else"):
                    self.block()
                self.take("end")
            elif self.accept("for"):
                self.name()
                while self.accept(","):
                    self.name()
                if not self.accept("="):
                    self.take("in")
                self.expressions()
                self.take("do")
                self.block()
                self.take("end")
            elif self.accept("function"):
                self.name()
                while self.accept("."):
                    self.name()
                if self.accept(":"):
                    self.name()
                self.function()
            elif self.accept("local"):
                if self.accept("function"):
                    self.name()
                    self.function()
                else:
                    self.name()
                    while self.accept(","):
                        self.name()
                    if self.accept("="):
                        self.expressions()
            else:
                self.expressions()
                if self.accept("="):
                    self.expressions()

    def check(self) -> list[tuple[int, str]]:
        self.block()
        if self.current.text != "<eof>":
            raise LuaSyntaxError(f"{self.current.line}: unexpected {self.current.text!r}")
        return self.findings


def main() -> int:
    paths = [Path(arg) for arg in sys.argv[1:]]
    if not paths:
        # Follow the release's actual load list, including generated runtime data.
        paths = [
            Path(line.replace("\\", "/"))
            for line in Path("TweaksForever.toc").read_text().splitlines()
            if line.strip() and not line.startswith("#")
        ]
    failed = False
    for path in paths:
        try:
            findings = Parser(path.read_text()).check()
        except (LuaSyntaxError, OSError) as error:
            print(f"{path}:{error}", file=sys.stderr)
            failed = True
            continue
        for line, message in findings:
            print(f"{path}:{line}: {message}")
            failed = True
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())
