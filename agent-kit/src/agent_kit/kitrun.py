"""agent-kit-run: run the kits installed in this environment's "agent_kit.kits" entry points.

The global guard calls this inside each project kit's .venv. It mirrors
agent-guard's contract: pre-tool exits 2 to block, commit-msg exits 1 to
reject, and a kit that fails to load or crashes is skipped.
"""

import argparse
import json
import sys
from importlib.metadata import entry_points
from pathlib import Path

from . import commitmsg
from .events import normalize
from .kit import Kit


def load_kits() -> dict[str, Kit]:
    kits: dict[str, Kit] = {}
    for ep in entry_points(group="agent_kit.kits"):
        try:
            kit = ep.load()
        except Exception as exc:  # one broken kit must not stop the others
            print(f"agent-kit: kit {ep.name} failed to load: {exc!r}", file=sys.stderr)
            continue
        if isinstance(kit, Kit):
            kits[ep.name] = kit
    return kits


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="agent-kit-run")
    sub = parser.add_subparsers(dest="cmd", required=True)
    pre = sub.add_parser("pre-tool")
    pre.add_argument("--harness", required=True, choices=["claude", "codex", "pi"])
    msg = sub.add_parser("commit-msg")
    msg.add_argument("path")
    sub.add_parser("list")
    fix = sub.add_parser("fixtures", help="turn AGENT_KIT_LOG_DIR logs into fixtures judged by these kits")
    fix.add_argument("logs", nargs="+", type=Path)
    fix.add_argument("--out", type=Path, default=Path("tests/fixtures"))
    args = parser.parse_args(argv)
    kits = load_kits()
    if args.cmd == "fixtures":
        from .fixtures import import_logs

        for path in import_logs(args.logs, args.out, lambda event: [v for k in kits.values() for v in k.run(event)]):
            print(f"  wrote {path}")
        return 0
    if args.cmd == "list":
        for name, kit in kits.items():
            print(f"{name}: {', '.join(kit.rules) or '(no rules)'}")
        return 0
    lines: list[str] = []
    try:
        if args.cmd == "pre-tool":
            event = normalize(json.loads(sys.stdin.read() or "{}"), args.harness)
            for name, kit in kits.items():
                lines += [f"agent-kit blocked this ({name}: {v.rule}): {v.message}" for v in kit.run(event)]
            code = 2
        else:
            text = commitmsg.message_text(Path(args.path).read_text(errors="replace"))
            for name, kit in kits.items():
                lines += [
                    f"agent-kit rejected this commit ({name}: {v.rule}): {v.message}" for v in kit.run_commit(text)
                ]
            code = 1
    except Exception as exc:  # a kit bug must not block the agent or the commit
        print(f"agent-kit: kit run failed, check skipped: {exc!r}", file=sys.stderr)
        return 0
    if lines:
        print("\n".join(lines), file=sys.stderr)
        return code
    return 0
