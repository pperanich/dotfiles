"""Checks that turn the user-wide agent rules into blocks.

Each check takes an Event and returns Violations. A rule's message is the
instruction the agent reads, so it names the fix, not only the fault.
"""

import os
import re
from dataclasses import dataclass
from pathlib import Path

from . import attribution
from .events import Event
from .shell import Command, simple_commands


@dataclass
class Violation:
    rule: str
    message: str


_PYTHON = re.compile(r"^python(\d+(\.\d+)?)?$")
_PIP = re.compile(r"^pip(\d+(\.\d+)?)?$")
_DATE_ADJUST = re.compile(r"^-v[+-]?\d")
_GIT_GLOBAL_VALUE_FLAGS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}
_GIT_CONFIG_VALUE_FLAGS = {"--file", "-f", "--blob", "--type", "--default", "--comment", "--value"}
_GIT_CONFIG_READS = {
    "--get",
    "--get-all",
    "--get-regexp",
    "--get-urlmatch",
    "--get-color",
    "--get-colorbool",
    "--list",
    "-l",
}
_GIT_CONFIG_WRITES = {
    "--unset",
    "--unset-all",
    "--add",
    "--replace-all",
    "--rename-section",
    "--remove-section",
    "--edit",
    "-e",
}
_LAST_ARG_WRITERS = {"cp", "mv", "ln", "install", "rsync"}
_ANY_ARG_WRITERS = {"tee", "rm", "touch", "truncate", "chmod", "chown"}
_IN_PLACE = {"sed", "perl"}
_FORGE_CLIS = {"gh", "gh-axi"}
_FORGE_FILE_FLAGS = {"-F", "--body-file", "--input"}


def _home() -> Path:
    return Path(os.path.expanduser("~"))


def protected_paths() -> list[Path]:
    home = _home()
    config = Path(os.environ.get("XDG_CONFIG_HOME") or home / ".config")
    names = [
        ".gitconfig",
        ".ssh",
        ".aws",
        ".zshrc",
        ".zshenv",
        ".zprofile",
        ".bashrc",
        ".bash_profile",
        ".profile",
        ".netrc",
        ".npmrc",
        ".pypirc",
    ]
    return [home / n for n in names] + [config / "git"]


def _resolve(word: str, cwd: str) -> Path | None:
    if not word or word.startswith("-"):
        return None
    home = str(_home())
    word = re.sub(r"^(\$HOME|\$\{HOME\})(?=/|$)", home, word)
    path = Path(os.path.expanduser(word))
    if not path.is_absolute():
        path = Path(cwd or os.getcwd()) / path
    return Path(os.path.normpath(path))


def _protected(word: str, cwd: str) -> Path | None:
    path = _resolve(word, cwd)
    if path is None:
        return None
    for root in protected_paths():
        if path == root or root in path.parents:
            return path
    return None


def _show(path: Path) -> str:
    home = str(_home())
    text = str(path)
    return "~" + text[len(home) :] if text.startswith(home + "/") else text


# gnu-tools


def _gnu_tools(cmd: Command) -> str | None:
    argv = cmd.argv
    if cmd.name == "sed":
        for i, arg in enumerate(argv[1:-1], 1):
            short_cluster = arg.startswith("-") and not arg.startswith("--") and arg.endswith("i")
            if (short_cluster or arg == "--in-place") and argv[i + 1] == "":
                return "sed here is GNU: write `sed -i 's/a/b/' file`. The BSD form `sed -i ''` makes GNU sed read '' as the script and your expression as a filename, so nothing is edited."
    if cmd.name == "stat":
        for i, arg in enumerate(argv[1:-1], 1):
            if arg == "-f" and "%" in argv[i + 1]:
                return "stat here is GNU: write `stat -c '%y %n' file`. `stat -f FORMAT` is the BSD spelling; GNU reads -f as --file-system."
    if cmd.name == "date":
        for i, arg in enumerate(argv[1:], 1):
            if _DATE_ADJUST.match(arg) or (arg == "-v" and i + 1 < len(argv)) or arg == "-j":
                return "date here is GNU: write `date -d '2 days ago'` or `date -d '2026-01-31' +%s`. `-v` and `-j` are BSD-only flags."
    return None


# uv-python


def _uv_python(cmd: Command) -> str | None:
    base = os.path.basename(cmd.name)
    args = cmd.argv[1:]
    if _PYTHON.match(base) and args not in (["--version"], ["-V"]):
        return "Run Python through uv, never a bare interpreter: `uv run python script.py`, or `uv run --with <pkg> python script.py` for a one-off with packages. Fresh worktrees have no .venv and the system interpreter has no third-party packages."
    if _PIP.match(base) and "install" in args:
        return "Install Python packages through uv: `uv add <pkg>` in a project, or `uv run --with <pkg> ...` for a one-off. Never pip into an interpreter."
    return None


# machine-config


def _git_config_write(argv: list[str], cwd: str) -> str | None:
    if os.path.basename(argv[0]) != "git":
        return None
    i = 1
    while i < len(argv) and argv[i].startswith("-"):
        i += 2 if argv[i] in _GIT_GLOBAL_VALUE_FLAGS else 1
    if i >= len(argv) or argv[i] != "config":
        return None
    rest = argv[i + 1 :]
    scope = None
    positionals: list[str] = []
    flags: set[str] = set()
    j = 0
    while j < len(rest):
        arg = rest[j]
        if arg in ("--global", "--system"):
            scope = arg
        elif arg in ("--file", "-f") and j + 1 < len(rest) and _protected(rest[j + 1], cwd):
            scope = arg
        if arg in _GIT_CONFIG_VALUE_FLAGS:
            j += 2
            continue
        if arg.startswith("-"):
            flags.add(arg.split("=", 1)[0])
        else:
            positionals.append(arg)
        j += 1
    if scope is None or flags & _GIT_CONFIG_READS:
        return None
    if positionals and positionals[0] in ("get", "list"):
        return None
    if (
        len(positionals) <= 1
        and not flags & _GIT_CONFIG_WRITES
        and not (positionals and positionals[0] in ("set", "unset", "edit"))
    ):
        return None
    return f"`git config {scope}` writes user-level git config"


def _write_targets(cmd: Command) -> list[str]:
    targets = list(cmd.redirects)
    args = [a for a in cmd.argv[1:] if not a.startswith("-")]
    if cmd.name in _LAST_ARG_WRITERS and args:
        targets.append(args[-1])
    elif cmd.name in _ANY_ARG_WRITERS:
        targets += args
    elif cmd.name in _IN_PLACE and any(a.startswith("-") and "i" in a.lstrip("-")[:3] for a in cmd.argv[1:]):
        targets += args
    return targets


_MACHINE_CONFIG_FIX = (
    "Never change user-level config to make a task work. For a git identity pass "
    "`-c user.name=... -c user.email=...` or set GIT_CONFIG_GLOBAL=<tmpfile>. "
    "If the user asked for this change, stop and say so; they can make it or relaunch with AGENT_KIT_ALLOW=machine-config."
)


def _machine_config(event: Event, commands: list[Command]) -> list[str]:
    found: list[str] = []
    for cmd in commands:
        reason = _git_config_write(cmd.argv, event.cwd) if cmd.argv else None
        if reason:
            found.append(reason)
        for target in _write_targets(cmd):
            path = _protected(target, event.cwd)
            if path:
                found.append(f"this command writes {_show(path)}, which is user-level config")
    for target in event.paths:
        path = _protected(target, event.cwd)
        if path:
            found.append(f"{_show(path)} is user-level config")
    return found


# forge-attribution


def _forge_texts(event: Event, commands: list[Command]) -> list[str]:
    texts: list[str] = []
    for cmd in commands:
        base = os.path.basename(cmd.name)
        is_forge = base in _FORGE_CLIS and len(cmd.argv) > 1 and cmd.argv[1] in ("pr", "issue", "api", "release")
        is_commit = base == "git" and "commit" in cmd.argv[1:4]
        if not (is_forge or is_commit):
            continue
        texts.append(event.command)
        argv = cmd.argv
        for i, arg in enumerate(argv[:-1]):
            if arg in _FORGE_FILE_FLAGS or (is_commit and arg in ("-F", "--file")):
                value = argv[i + 1]
                value = value.split("=@", 1)[1] if "=@" in value else value
                path = _resolve(value, event.cwd)
                if path and path.is_file() and path.stat().st_size < 1_000_000:
                    texts.append(path.read_text(errors="replace"))
    return texts


def _forge_attribution(event: Event, commands: list[Command]) -> str | None:
    texts = _forge_texts(event, commands)
    if event.kind == "other" and "github" in event.tool.lower():
        texts += event.strings
    for text in texts:
        phrase = attribution.find(text)
        if phrase:
            return (
                f"This text announces machine authorship ('{phrase}'). Commits, pull requests, issues and "
                "comments are written as the account owner: the request, the finding, the result. Remove the "
                "attribution line, footer or emoji and send it again."
            )
    return None


# sleep-loop


def _sleep_loop(commands: list[Command]) -> str | None:
    if any(c.loop for c in commands) and any(c.name == "sleep" for c in commands):
        return (
            "Don't wait with sleep in a loop. Run the long command in the background and wait on its "
            "condition, or bound the poll: `timeout 300 bash -c 'until <condition>; do sleep 2; done'`."
        )
    return None


def check(event: Event) -> list[Violation]:
    allowed = {r.strip() for r in os.environ.get("AGENT_KIT_ALLOW", "").split(",") if r.strip()}
    commands = (simple_commands(event.command) or []) if event.kind == "shell" else []
    out: list[Violation] = []

    def add(rule: str, message: str | None) -> None:
        if message and rule not in allowed:
            out.append(Violation(rule, message))

    for cmd in commands:
        add("gnu-tools", _gnu_tools(cmd))
        add("uv-python", _uv_python(cmd))
    reasons = _machine_config(event, commands)
    if reasons:
        add("machine-config", "; ".join(dict.fromkeys(reasons)) + ". " + _MACHINE_CONFIG_FIX)
    add("forge-attribution", _forge_attribution(event, commands))
    add("sleep-loop", _sleep_loop(commands))
    unique: dict[tuple[str, str], Violation] = {(v.rule, v.message): v for v in out}
    return list(unique.values())
