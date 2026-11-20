"""agent-guard: the hook entry point every harness calls.

pre-tool reads a hook payload on stdin and exits 2 with the reason on stderr to
block. commit-msg checks a message file and exits 1 to reject the commit. Any
internal error exits 0, so a broken guard never stops work.
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path

from . import commitmsg
from .events import normalize
from .rules import check


def _log(harness: str, payload: dict) -> None:
    directory = os.environ.get("AGENT_KIT_LOG_DIR")
    if not directory:
        return
    path = Path(directory) / f"{harness}.jsonl"
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a") as f:
        f.write(json.dumps({"ts": time.time(), "harness": harness, "payload": payload}) + "\n")


def pre_tool(harness: str) -> int:
    raw = sys.stdin.read()
    payload = json.loads(raw) if raw.strip() else {}
    _log(harness, payload)
    violations = check(normalize(payload, harness))
    if not violations:
        return 0
    print("\n".join(f"agent-kit blocked this ({v.rule}): {v.message}" for v in violations), file=sys.stderr)
    return 2


def commit_msg(path: str) -> int:
    errors, warnings = commitmsg.check(Path(path).read_text(errors="replace"))
    for warning in warnings:
        print(f"agent-kit warning: {warning}", file=sys.stderr)
    for error in errors:
        print(f"agent-kit rejected this commit: {error}", file=sys.stderr)
    return 1 if errors else 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="agent-guard")
    sub = parser.add_subparsers(dest="cmd", required=True)
    pre = sub.add_parser("pre-tool", help="check a pre-tool hook payload read from stdin")
    pre.add_argument("--harness", required=True, choices=["claude", "codex", "pi"])
    msg = sub.add_parser("commit-msg", help="check a commit message file")
    msg.add_argument("path")
    args = parser.parse_args(argv)
    try:
        if args.cmd == "pre-tool":
            return pre_tool(args.harness)
        return commit_msg(args.path)
    except Exception as exc:  # a guard bug must not block the agent or the commit
        print(f"agent-kit: internal error, check skipped: {exc!r}", file=sys.stderr)
        return 0
