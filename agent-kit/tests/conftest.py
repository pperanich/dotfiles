import sys
from pathlib import Path

import pytest

KIT = Path(__file__).resolve().parent.parent
# The project's own console script, so the tests never depend on the uv tool install.
GUARD = Path(sys.executable).parent / "agent-guard"


@pytest.fixture
def home(tmp_path, monkeypatch):
    """A throwaway HOME, so path checks never read or touch the real one."""
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path / ".config"))
    monkeypatch.delenv("AGENT_KIT_ALLOW", raising=False)
    return tmp_path
