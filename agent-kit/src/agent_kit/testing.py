"""Builders for tests of kit checks: make an Event, run a kit, replay captured fixtures."""

import json
from pathlib import Path

from .events import Event, normalize
from .kit import Kit


def shell(command: str, cwd: str = "/work", harness: str = "claude") -> Event:
    return Event(harness=harness, tool="Bash", kind="shell", cwd=cwd, command=command)


def write(path: str, content: str = "", cwd: str = "/work", harness: str = "claude") -> Event:
    return Event(
        harness=harness, tool="Write", kind="write", cwd=cwd, paths=[path], new_text=content, added={path: content}
    )


def edit(path: str, new_text: str = "", cwd: str = "/work", harness: str = "claude") -> Event:
    return Event(
        harness=harness, tool="Edit", kind="edit", cwd=cwd, paths=[path], new_text=new_text, added={path: new_text}
    )


def rules(kit: Kit, event: Event) -> list[str]:
    """Names of the rules that block this event."""
    return [v.rule for v in kit.run(event)]


def fixture_files(directory: Path) -> list[Path]:
    return sorted(Path(directory).glob("*.json"))


def replay(kit: Kit, path: Path) -> tuple[list[str], list[str]]:
    """(expected, actual) rule names for one fixture written by `agent-kit fixtures`."""
    case = json.loads(Path(path).read_text())
    event = normalize(case["payload"], case["harness"])
    return case["expect"]["rules"], sorted({v.rule for v in kit.run(event)})
