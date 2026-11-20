"""Real payloads captured from each harness (agent-kit fixtures <log>), replayed."""

import json
from pathlib import Path

import pytest

from agent_kit.events import normalize
from agent_kit.rules import check

FIXTURES = sorted((Path(__file__).parent / "fixtures").glob("*.json"))


@pytest.mark.parametrize("path", FIXTURES, ids=[p.stem for p in FIXTURES])
def test_fixture_verdict_holds(home, path):
    case = json.loads(path.read_text())
    event = normalize(case["payload"], case["harness"])
    assert event.kind == case["expect"]["kind"]
    assert sorted({v.rule for v in check(event)}) == case["expect"]["rules"]


def test_every_harness_has_fixtures():
    harnesses = {json.loads(p.read_text())["harness"] for p in FIXTURES}
    assert {"claude", "pi"} <= harnesses
