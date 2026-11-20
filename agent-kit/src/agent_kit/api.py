"""The public API for agent-kit checks. Project kits import from here and nowhere else.

A kit is a Kit with checks registered on it, exposed through the
"agent_kit.kits" entry point group. A tool check takes an Event and returns
the message the agent reads (naming the fix) or None. A commit check takes the
commit message text and returns an error or None.

API_VERSION changes when a kit written against the old API would break.
"""

from .events import Event
from .kit import (
    Kit,
    Violation,
    block_command,
    block_paths,
    repo_root,
    resolve_path,
    show_path,
    write_targets,
    written_paths,
)
from .shell import Command, simple_commands

API_VERSION = 1

__all__ = [
    "API_VERSION",
    "Command",
    "Event",
    "Kit",
    "Violation",
    "block_command",
    "block_paths",
    "repo_root",
    "resolve_path",
    "show_path",
    "simple_commands",
    "write_targets",
    "written_paths",
]
