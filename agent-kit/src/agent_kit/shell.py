"""Split a shell command into simple commands without running it.

The parse is deliberately shallow: enough to see each command's words and its
redirect targets. A script it cannot tokenize yields None, and callers skip it.
"""

import re
import shlex
from dataclasses import dataclass, field

_HEREDOC = re.compile(r"(?<!<)<<(?!<)(-?)\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\2")
_ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
_PUNCT = set(";&|()<>\n")
_KEYWORDS = {"do", "then", "else", "elif", "if", "while", "until", "{", "!"}
_WRAPPERS = {"command", "builtin", "exec", "nohup", "time"}
_XARGS_VALUE_FLAGS = {"-I", "-n", "-P", "-L", "-s", "-d", "-E", "-a"}


@dataclass
class Command:
    argv: list[str]
    redirects: list[str] = field(default_factory=list)
    loop: bool = False  # the command is a while or until condition

    @property
    def name(self) -> str:
        return self.argv[0] if self.argv else ""


def strip_heredocs(script: str) -> str:
    """Drop heredoc bodies, which are data rather than commands."""
    lines = script.split("\n")
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        i += 1
        for match in _HEREDOC.finditer(line):
            term = match.group(3)
            while i < len(lines) and lines[i].strip() != term:
                i += 1
            i += 1
    return "\n".join(out)


def _tokens(script: str) -> list[str] | None:
    lexer = shlex.shlex(script, posix=True, punctuation_chars=";&|()<>\n")
    lexer.whitespace = " \t\r"
    lexer.commenters = ""
    lexer.wordchars += "$@%+,:{}^[]"
    try:
        return list(lexer)
    except ValueError:
        return None


def _is_operator(token: str) -> bool:
    return bool(token) and all(c in _PUNCT for c in token)


def _unwrap(argv: list[str]) -> list[str]:
    """Skip keywords, VAR=value prefixes and wrappers to reach the real command."""
    i = 0
    while i < len(argv):
        word = argv[i]
        if word in _KEYWORDS or _ASSIGNMENT.match(word) or word in _WRAPPERS:
            i += 1
        elif word == "env":
            i += 1
            while i < len(argv) and (argv[i].startswith("-") or _ASSIGNMENT.match(argv[i])):
                i += 2 if argv[i] in ("-u", "-C", "-S") else 1
        elif word in ("sudo", "doas", "nice"):
            i += 1
            while i < len(argv) and argv[i].startswith("-"):
                i += 2 if argv[i] in ("-u", "-g", "-n") else 1
        elif word == "timeout":
            i += 1
            while i < len(argv) and argv[i].startswith("-"):
                i += 2 if argv[i] in ("-s", "-k") else 1
            i += 1
        elif word == "xargs":
            i += 1
            while i < len(argv) and argv[i].startswith("-"):
                i += 2 if argv[i] in _XARGS_VALUE_FLAGS else 1
        else:
            break
    return argv[i:]


def simple_commands(script: str) -> list[Command] | None:
    tokens = _tokens(strip_heredocs(script))
    if tokens is None:
        return None
    commands: list[Command] = []
    current = Command(argv=[])
    pending = ""  # "write" after an output redirect, "skip" after an input one

    def flush() -> None:
        nonlocal current
        current.loop = bool(current.argv) and current.argv[0] in ("while", "until")
        current.argv = _unwrap(current.argv)
        if current.argv and current.argv[0].startswith("#"):
            current.argv = []
        if current.argv or current.redirects or current.loop:
            commands.append(current)
        current = Command(argv=[])

    for token in tokens:
        if pending:
            if pending == "write" and not token.isdigit() and token != "-":
                current.redirects.append(token)
            pending = ""
            continue
        if _is_operator(token):
            if token in ("&", "&&") or any(c in token for c in ";|()\n"):
                flush()
            if ">" in token or "<" in token:
                if current.argv and current.argv[-1].isdigit():
                    current.argv.pop()  # the fd number of 2>&1 or 2>file
            if ">" in token:
                pending = "write"
            elif "<" in token:
                pending = "skip"
            continue
        current.argv.append(token)
    flush()
    return commands
