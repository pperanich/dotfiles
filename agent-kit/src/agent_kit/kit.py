"""Kit: a named set of checks, the unit both agent-kit's built-in rules and project kits use."""

import fnmatch
import os
import re
import shlex
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from .events import Event
from .shell import Command

ToolCheck = Callable[[Event], str | None]
CommitCheck = Callable[[str], str | None]


@dataclass
class Violation:
    rule: str
    message: str


def config_dir() -> Path:
    """agent-kit's own config: trusted kits and user-side project kits."""
    if os.environ.get("AGENT_KIT_CONFIG_DIR"):
        return Path(os.environ["AGENT_KIT_CONFIG_DIR"])
    return Path(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")) / "agent-kit"


def allowed_rules() -> set[str]:
    """Rules the user let through for this session with AGENT_KIT_ALLOW, set when launching the agent."""
    return {r.strip() for r in os.environ.get("AGENT_KIT_ALLOW", "").split(",") if r.strip()}


class Kit:
    def __init__(self, name: str):
        self.name = name
        self._tool_checks: list[tuple[str, ToolCheck]] = []
        self._commit_checks: list[tuple[str, CommitCheck]] = []

    def check(self, rule: str) -> Callable[[ToolCheck], ToolCheck]:
        """Register fn(event) -> message or None, run before each tool call."""

        def register(fn: ToolCheck) -> ToolCheck:
            self._tool_checks.append((rule, fn))
            return fn

        return register

    def commit_check(self, rule: str) -> Callable[[CommitCheck], CommitCheck]:
        """Register fn(message_text) -> error or None, run from the commit-msg hook."""

        def register(fn: CommitCheck) -> CommitCheck:
            self._commit_checks.append((rule, fn))
            return fn

        return register

    @property
    def rules(self) -> list[str]:
        return [rule for rule, _ in self._tool_checks + self._commit_checks]

    def run(self, event: Event) -> list[Violation]:
        allowed = allowed_rules()
        found = [Violation(rule, msg) for rule, fn in self._tool_checks if rule not in allowed and (msg := fn(event))]
        return list({(v.rule, v.message): v for v in found}.values())

    def run_commit(self, text: str) -> list[Violation]:
        allowed = allowed_rules()
        return [Violation(rule, msg) for rule, fn in self._commit_checks if rule not in allowed and (msg := fn(text))]


# Helpers for checks


def resolve_path(word: str, cwd: str) -> Path | None:
    """An argument as an absolute path, expanding ~ and $HOME; None for flags and empty words."""
    if not word or word.startswith("-"):
        return None
    home = os.path.expanduser("~")
    word = re.sub(r"^(\$HOME|\$\{HOME\})(?=/|$)", home, word)
    path = Path(os.path.expanduser(word))
    if not path.is_absolute():
        path = Path(cwd or os.getcwd()) / path
    return Path(os.path.normpath(path))


def show_path(path: Path) -> str:
    home = os.path.expanduser("~")
    text = str(path)
    return "~" + text[len(home) :] if text.startswith(home + "/") else text


def repo_root(cwd: str) -> Path | None:
    """The nearest directory at or above cwd holding a .git entry."""
    if not cwd:
        return None
    path = Path(cwd).resolve()
    for candidate in (path, *path.parents):
        if (candidate / ".git").exists():
            return candidate
    return None


_LAST_ARG_WRITERS = {"cp", "mv", "ln", "install", "rsync"}
_ANY_ARG_WRITERS = {"tee", "rm", "touch", "truncate", "chmod", "chown"}
_IN_PLACE = {"sed", "perl"}


def write_targets(cmd: Command) -> list[str]:
    """Paths a shell command writes: redirects, cp/mv destinations, tee/rm/touch args, sed -i files."""
    targets = list(cmd.redirects)
    args = [a for a in cmd.argv[1:] if not a.startswith("-")]
    if cmd.name in _LAST_ARG_WRITERS and args:
        targets.append(args[-1])
    elif cmd.name in _ANY_ARG_WRITERS:
        targets += args
    elif cmd.name in _IN_PLACE and any(a.startswith("-") and "i" in a.lstrip("-")[:3] for a in cmd.argv[1:]):
        targets += args
    return targets


def written_paths(event: Event) -> list[Path]:
    """Every path this call would write, from a write or edit tool or from a shell command."""
    words = list(event.paths) if event.kind in ("write", "edit") else []
    for cmd in event.commands:
        words += write_targets(cmd)
    return [p for w in words if (p := resolve_path(w, event.cwd))]


def block_command(kit: Kit, rule: str, *, command: str, message: str, args: str | None = None) -> ToolCheck:
    """Block a command by name, optionally only when its joined arguments match the regex args."""
    pattern = re.compile(args) if args else None

    @kit.check(rule)
    def _check(event: Event) -> str | None:
        for cmd in event.commands:
            if os.path.basename(cmd.name) == command and (pattern is None or pattern.search(shlex.join(cmd.argv[1:]))):
                return message
        return None

    return _check


def block_paths(kit: Kit, rule: str, *, patterns: list[str], message: str) -> ToolCheck:
    """Block writes to paths matching glob patterns relative to the repository root."""

    @kit.check(rule)
    def _check(event: Event) -> str | None:
        root = repo_root(event.cwd)
        for path in written_paths(event):
            relative = os.path.relpath(path, root) if root else str(path)
            if any(fnmatch.fnmatch(relative, p) for p in patterns):
                return message
        return None

    return _check
