"""The Copier template, end to end: agent-kit new makes a kit whose rule the guard then enforces.

This runs Copier and uv for real (uv's cache keeps it to seconds), because the
template is only proven by a kit that installs, passes its own tests, and blocks.
"""

import os
import subprocess
import sys
from pathlib import Path

import pytest

AGENT_KIT = str(Path(sys.executable).parent / "agent-kit")
RULE = """
from agent_kit.api import block_command

block_command(kit, "prod-kubectl", command="kubectl", args=r"--context[= ]prod", message="Use the staging context.")
"""


@pytest.fixture
def kit_env(tmp_path):
    repo = tmp_path / "widgets"
    subprocess.run(["git", "init", "-q", "-b", "main", str(repo)], check=True)
    subprocess.run(["git", "-C", str(repo), "remote", "add", "origin", "git@github.com:acme/widgets.git"], check=True)
    env = {**os.environ, "AGENT_KIT_CONFIG_DIR": str(tmp_path / "config")}
    env.pop("AGENT_KIT_ALLOW", None)
    return repo, env, tmp_path / "config" / "projects" / "github.com" / "acme" / "widgets"


def run(args, cwd, env):
    return subprocess.run([AGENT_KIT, *args], cwd=cwd, env=env, capture_output=True, text=True, timeout=300)


def test_new_user_kit_blocks_through_the_guard(kit_env):
    repo, env, kit = kit_env
    created = run(["new"], repo, env)
    assert created.returncode == 0, created.stderr
    assert (kit / ".venv" / "bin" / "agent-kit-run").exists()
    assert "_commit:" in (kit / ".copier-answers.yml").read_text()
    log = subprocess.run(["git", "-C", str(kit), "log", "--oneline"], capture_output=True, text=True).stdout
    assert "create kit from the agent-kit template" in log

    with (kit / "src" / "widgets_kit" / "checks.py").open("a") as f:
        f.write(RULE)
    blocked = run(["check", "kubectl --context prod get pods"], repo, env)
    assert blocked.returncode == 2
    assert "(widgets: prod-kubectl): Use the staging context." in blocked.stdout
    assert run(["check", "kubectl --context staging get pods"], repo, env).returncode == 0
    assert "prod-kubectl" in run(["kits"], repo, env).stdout


def test_new_refuses_an_existing_kit(kit_env):
    repo, env, kit = kit_env
    kit.mkdir(parents=True)
    result = run(["new"], repo, env)
    assert result.returncode == 1
    assert "already exists" in result.stderr


def test_trust_refuses_without_a_terminal(kit_env, tmp_path):
    repo, env, _ = kit_env
    (repo / ".agent-kit").mkdir()
    (repo / ".agent-kit" / "pyproject.toml").write_text('[project]\nname = "x"\n')
    result = run(["trust"], repo, env)
    assert result.returncode == 1
    assert "needs a terminal" in result.stderr
    assert not (tmp_path / "config" / "trusted.json").exists()
