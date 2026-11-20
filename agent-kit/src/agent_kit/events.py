"""Turn each harness's pre-tool payload into one event shape."""

import re
import shlex
from dataclasses import dataclass, field
from functools import cached_property

from .shell import Command, simple_commands

_SHELL_TOOLS = {"bash", "shell", "exec_command", "local_shell", "unified_exec", "container.exec"}
_WRITE_TOOLS = {"write", "create_file"}
_EDIT_TOOLS = {"edit", "multiedit", "str_replace_based_edit_tool"}
_PATCH_FILE = re.compile(r"^\*\*\* (?:Add File|Update File|Delete File|Move to): (.+)$", re.M)


@dataclass
class Event:
    harness: str
    tool: str
    kind: str  # "shell", "write", "edit" or "other"
    cwd: str
    command: str = ""
    paths: list[str] = field(default_factory=list)
    new_text: str = ""
    strings: list[str] = field(default_factory=list)  # every string field, for "other" tools

    @cached_property
    def commands(self) -> list[Command]:
        """The shell command split into simple commands; empty for other tools or an unparseable script."""
        return (simple_commands(self.command) or []) if self.kind == "shell" else []


def _command_text(value) -> str:
    if isinstance(value, list):
        words = [str(w) for w in value]
        if (
            len(words) >= 3
            and words[0].rsplit("/", 1)[-1] in ("bash", "sh", "zsh")
            and words[1] in ("-c", "-lc", "-ic")
        ):
            return words[2]
        return shlex.join(words)
    return value if isinstance(value, str) else ""


def _strings(value) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        return [s for v in value.values() for s in _strings(v)]
    if isinstance(value, list):
        return [s for v in value for s in _strings(v)]
    return []


def _patch(text: str) -> tuple[list[str], str]:
    paths = [m.strip() for m in _PATCH_FILE.findall(text)]
    added = "\n".join(line[1:] for line in text.splitlines() if line.startswith("+"))
    return paths, added


def normalize(payload: dict, harness: str) -> Event:
    tool = str(payload.get("tool_name") or "")
    raw_input = payload.get("tool_input")
    tool_input = raw_input if isinstance(raw_input, dict) else {}
    event = Event(harness=harness, tool=tool, kind="other", cwd=str(payload.get("cwd") or ""))
    name = tool.lower()
    patch = next((s for s in _strings(raw_input) if s.lstrip().startswith("*** Begin Patch")), None)

    if patch is not None:
        event.kind = "edit"
        event.paths, event.new_text = _patch(patch)
    elif name in _SHELL_TOOLS:
        event.kind = "shell"
        event.command = _command_text(tool_input.get("command", tool_input.get("cmd", "")))
    elif name in _WRITE_TOOLS:
        event.kind = "write"
        event.paths = [str(tool_input.get("file_path") or tool_input.get("path") or "")]
        event.new_text = str(tool_input.get("content") or "")
    elif name in _EDIT_TOOLS:
        event.kind = "edit"
        event.paths = [str(tool_input.get("file_path") or tool_input.get("path") or "")]
        edits = tool_input.get("edits") or [tool_input]
        event.new_text = "\n".join(
            str(e.get("new_string") or e.get("newText") or "") for e in edits if isinstance(e, dict)
        )
    else:
        event.strings = _strings(raw_input)
    event.paths = [p for p in event.paths if p]
    return event
