"""agent-guard as the harnesses call it: a payload on stdin, an exit code back."""

import json
import os
import subprocess

from conftest import GUARD


def run(payload, harness="claude", env=None):
    data = payload if isinstance(payload, str) else json.dumps(payload)
    return subprocess.run(
        [str(GUARD), "pre-tool", "--harness", harness], input=data, capture_output=True, text=True, env=env
    )


def test_blocking_exits_2_with_the_reason(home):
    result = run({"tool_name": "Bash", "tool_input": {"command": "sed -i '' s/a/b/ f"}, "cwd": str(home)})
    assert result.returncode == 2
    assert "agent-kit blocked this (gnu-tools)" in result.stderr


def test_allowed_exits_0_silently(home):
    result = run({"tool_name": "Bash", "tool_input": {"command": "ls -la"}, "cwd": str(home)})
    assert (result.returncode, result.stderr) == (0, "")


def test_bad_payload_fails_open(home):
    result = run("{not json")
    assert result.returncode == 0
    assert "internal error" in result.stderr


def test_log_dir_records_payloads(home, tmp_path):
    env = {**os.environ, "AGENT_KIT_LOG_DIR": str(tmp_path / "log")}
    run({"tool_name": "Bash", "tool_input": {"command": "ls"}, "cwd": "/"}, harness="pi", env=env)
    lines = (tmp_path / "log" / "pi.jsonl").read_text().splitlines()
    assert json.loads(lines[0])["payload"]["tool_input"]["command"] == "ls"
