"""Turn AGENT_KIT_LOG_DIR payload logs into redacted test fixtures.

Each fixture records the guard's current verdict, so a harness upgrade that
changes its payload shape shows up as a failing test instead of a silent pass.
"""

import json
import os
from pathlib import Path

from .events import normalize
from .rules import check

FIXTURES = Path(__file__).resolve().parents[2] / "tests" / "fixtures"
_IDS = {"session_id", "tool_use_id", "prompt_id", "toolCallId"}


def _redact(value, swaps: list[tuple[str, str]]):
    if isinstance(value, str):
        for old, new in swaps:
            value = value.replace(old, new)
        return value
    if isinstance(value, dict):
        return {k: ("redacted" if k in _IDS else _redact(v, swaps)) for k, v in value.items()}
    if isinstance(value, list):
        return [_redact(v, swaps) for v in value]
    return value


def import_logs(paths: list[Path], out: Path = FIXTURES) -> list[Path]:
    out.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    for log in paths:
        for n, line in enumerate(log.read_text().splitlines(), 1):
            record = json.loads(line)
            harness, payload = record["harness"], record["payload"]
            swaps = [(payload["cwd"], "/work")] if payload.get("cwd") else []
            swaps.append((os.path.expanduser("~"), "/home/user"))
            payload = _redact(payload, swaps)
            if "transcript_path" in payload:
                payload["transcript_path"] = "/home/user/.claude/transcript.jsonl"
            event = normalize(payload, harness)
            expect = {"kind": event.kind, "rules": sorted({v.rule for v in check(event)})}
            tool = str(payload.get("tool_name") or "tool").lower().replace("/", "_")
            path = out / f"{harness}-{n:02d}-{tool}.json"
            path.write_text(json.dumps({"harness": harness, "payload": payload, "expect": expect}, indent=2) + "\n")
            written.append(path)
    return written
