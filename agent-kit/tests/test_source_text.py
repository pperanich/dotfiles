"""source-text-test: tests that read code as text are blocked; tests that run it are not.

The cases live in data/source_text_cases.json, not in this file, so editing
these tests never trips the rule they test.
"""

import json
from pathlib import Path

import pytest

from agent_kit.events import normalize
from agent_kit.rules import check, is_test_file

CASES = json.loads((Path(__file__).parent / "data" / "source_text_cases.json").read_text())


def payload(case, cwd):
    tool = case["tool"]
    if tool == "Bash":
        tool_input = {"command": case["command"]}
    elif tool == "apply_patch":
        tool_input = {"input": case["patch"]}
    elif tool == "Edit":
        tool_input = {"file_path": case["path"], "old_string": "x", "new_string": case["text"]}
    else:
        tool_input = {"file_path": case["path"], "content": case["text"]}
    return {"tool_name": tool, "tool_input": tool_input, "cwd": str(cwd)}


def rules_for(case, cwd):
    return [v.rule for v in check(normalize(payload(case, cwd), "claude"))]


@pytest.mark.parametrize("case", CASES["blocked"], ids=[c["name"] for c in CASES["blocked"]])
def test_blocks(home, case):
    assert "source-text-test" in rules_for(case, home)


@pytest.mark.parametrize("case", CASES["allowed"], ids=[c["name"] for c in CASES["allowed"]])
def test_allows(home, case):
    assert "source-text-test" not in rules_for(case, home)


def test_rewriting_a_file_does_not_blame_lines_it_already_had(home):
    existing = home / "tests" / "test_app.py"
    existing.parent.mkdir()
    old_line = CASES["preexisting_line"]
    existing.write_text(f"def test_old():\n{old_line}\n")
    rewrite = {
        "tool": "Write",
        "path": str(existing),
        "text": f"def test_old():\n{old_line}\n\ndef test_new():\n    assert run() == 1\n",
    }
    assert "source-text-test" not in rules_for(rewrite, home)
    added = {
        "tool": "Write",
        "path": str(existing),
        "text": f"def test_old():\n{old_line}\n{old_line.replace('src', 'body')}\n",
    }
    assert "source-text-test" in rules_for(added, home)


@pytest.mark.parametrize(
    ("path", "expected"),
    [
        ("tests/test_app.py", True),
        ("pkg/app_test.go", True),
        ("web/src/app.spec.tsx", True),
        ("web/__tests__/helpers.js", True),
        ("spec/models/user_spec.rb", True),
        ("src/app/testing.py", False),
        ("src/contest.py", False),
        ("tests/data/cases.json", False),
    ],
)
def test_is_test_file(path, expected):
    assert is_test_file(path) is expected
