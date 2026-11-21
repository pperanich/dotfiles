"""agent-kit's built-in kit: the user-wide agent rules as checks.

Each check returns the message the agent reads, so it names the fix, not only
the fault. Project kits use the same Kit API from agent_kit.api.
"""

import os
import re
from pathlib import Path

from . import attribution
from .events import Event
from .kit import Kit, Violation, config_dir, resolve_path, show_path, write_targets
from .shell import Command

kit = Kit("agent-kit")


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
    return [home / n for n in names] + [config / "git", config_dir() / "trusted.json"]


def _protected(word: str, cwd: str) -> Path | None:
    path = resolve_path(word, cwd)
    if path is None:
        return None
    for root in protected_paths():
        if path == root or root in path.parents:
            return path
    return None


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
        for target in write_targets(cmd):
            path = _protected(target, event.cwd)
            if path:
                found.append(f"this command writes {show_path(path)}, which is user-level config")
    for target in event.paths:
        path = _protected(target, event.cwd)
        if path:
            found.append(f"{show_path(path)} is user-level config")
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
                path = resolve_path(value, event.cwd)
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


# source-text-test

_TEST_FILE = re.compile(
    r"(^|/)(test_[^/]*\.py|[^/]*_test\.(py|go|rb)|conftest\.py|[^/]*\.(test|spec)\.[cm]?[jt]sx?|[^/]*_spec\.rb)$"
    r"|(^|/)(tests?|__tests__|spec)/.*\.(py|[cm]?[jt]sx?|go|rb|rs)$"
)
_GETSOURCE = re.compile(r"\bgetsource(lines)?\(")
_READ_CALL = re.compile(
    r"\.read_text\(|\.read_bytes\(|\.read\(\)|readFileSync\(|readFile\(|Deno\.readTextFile\(|Bun\.file\("
    r"|os\.ReadFile\(|ioutil\.ReadFile\(|File\.read\(|read_to_string\("
)
_SOURCE_LITERAL = re.compile(
    r"""["'][^"'\s]*\.(py|pyi|[cm]?[jt]sx?|go|rs|rb|java|kt|swift|c|cc|cpp|h|hpp|cs|php|lua|sh)["']"""
)
_OUTPUT_HINT = re.compile(r"tmp|fixture|golden|expected|snapshot|testdata", re.I)
_COMMENT = re.compile(r"^\s*(#|//|/\*|\*)")


def is_test_file(path: str) -> bool:
    return bool(_TEST_FILE.search(path.replace("\\", "/")))


def _source_text_line(line: str) -> bool:
    """A line that reads code as text: inspect.getsource, or reading a source file by its path."""
    if _COMMENT.match(line):
        return False
    if _GETSOURCE.search(line):
        return True
    return bool(_READ_CALL.search(line) and _SOURCE_LITERAL.search(line) and not _OUTPUT_HINT.search(line))


def _new_lines(path: str, text: str, cwd: str, whole_file: bool) -> list[str]:
    """Lines this call adds; for a whole-file write, lines the file does not already have."""
    lines = text.splitlines()
    target = resolve_path(path, cwd)
    if whole_file and target and target.is_file():
        existing = set(target.read_text(errors="replace").splitlines())
        lines = [line for line in lines if line not in existing]
    return lines


def _source_text_test(event: Event) -> str | None:
    texts = event.added or {p: event.new_text for p in event.paths}
    found: list[str] = []
    if event.kind in ("write", "edit"):
        for path, text in texts.items():
            if is_test_file(path):
                found += [
                    ln for ln in _new_lines(path, text, event.cwd, event.kind == "write") if _source_text_line(ln)
                ]
    elif event.kind == "shell" and any(is_test_file(t) for c in event.commands for t in write_targets(c)):
        found = [ln for ln in event.command.splitlines() if _source_text_line(ln)]
    if not found:
        return None
    return (
        f"this test reads code as text instead of running it: `{found[0].strip()[:120]}`. "
        "A test that matches source text fails on a rename and still passes when the behavior breaks. "
        "Call the function, command or endpoint and assert its result. If the file is output of the code "
        "under test (a generator or formatter), write and read it under tmp_path or a fixtures directory. "
        "If the user wants this test anyway, stop and say so; they can relaunch with AGENT_KIT_ALLOW=source-text-test."
    )


@kit.check("gnu-tools")
def gnu_tools(event: Event) -> str | None:
    return next((m for cmd in event.commands if (m := _gnu_tools(cmd))), None)


@kit.check("uv-python")
def uv_python(event: Event) -> str | None:
    return next((m for cmd in event.commands if (m := _uv_python(cmd))), None)


@kit.check("machine-config")
def machine_config(event: Event) -> str | None:
    reasons = _machine_config(event, event.commands)
    return "; ".join(dict.fromkeys(reasons)) + ". " + _MACHINE_CONFIG_FIX if reasons else None


@kit.check("forge-attribution")
def forge_attribution(event: Event) -> str | None:
    return _forge_attribution(event, event.commands)


@kit.check("source-text-test")
def source_text_test(event: Event) -> str | None:
    return _source_text_test(event)


@kit.check("sleep-loop")
def sleep_loop(event: Event) -> str | None:
    return _sleep_loop(event.commands)


def check(event: Event) -> list[Violation]:
    return kit.run(event)
