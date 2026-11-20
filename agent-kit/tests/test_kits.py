"""Kit discovery, trust and dispatch, with a stand-in runner instead of a built kit."""

import json
import os
import subprocess

import pytest
from conftest import GUARD

from agent_kit import kits

BLOCKING_RUNNER = (
    "#!/bin/sh\ncat > /dev/null\necho 'agent-kit blocked this (demo: no-ls): ls is banned here' >&2\nexit 2\n"
)


@pytest.fixture
def config(home, monkeypatch):
    path = home / "agent-kit-config"
    monkeypatch.setenv("AGENT_KIT_CONFIG_DIR", str(path))
    return path


def make_repo(root, url="git@github.com:acme/widgets.git"):
    (root / ".git").mkdir(parents=True)
    (root / ".git" / "config").write_text(f'[core]\n\tbare = false\n[remote "origin"]\n\turl = {url}\n')
    return root


def make_kit(path, runner=BLOCKING_RUNNER):
    (path / ".venv" / "bin").mkdir(parents=True)
    (path / "pyproject.toml").write_text('[project]\nname = "demo"\n')
    script = path / ".venv" / "bin" / "agent-kit-run"
    script.write_text(runner)
    script.chmod(0o755)
    return path


@pytest.mark.parametrize(
    ("url", "key"),
    [
        ("git@github.com:acme/widgets.git", "github.com/acme/widgets"),
        ("https://github.com/acme/widgets", "github.com/acme/widgets"),
        ("ssh://git@gitlab.example.com/team/svc.git", "gitlab.example.com/team/svc"),
        (None, "local/repo"),
    ],
)
def test_repo_key(tmp_path, url, key):
    assert kits.repo_key(url, tmp_path / "repo") == key


def test_remote_url_from_a_worktree(tmp_path):
    main = make_repo(tmp_path / "main")
    (main / ".git" / "worktrees" / "wt").mkdir(parents=True)
    (main / ".git" / "worktrees" / "wt" / "commondir").write_text("../..\n")
    tree = tmp_path / "wt"
    tree.mkdir()
    (tree / ".git").write_text(f"gitdir: {main / '.git' / 'worktrees' / 'wt'}\n")
    assert kits.remote_url(tree) == "git@github.com:acme/widgets.git"


def test_discover_finds_user_and_repo_kits(config, home):
    repo = make_repo(home / "widgets")
    make_kit(repo / ".agent-kit")
    make_kit(config / "projects" / "github.com" / "acme" / "widgets")
    found = kits.discover(str(repo / "src"))
    assert [(r.location, r.path) for r in found] == [
        ("repo", repo / ".agent-kit"),
        ("user", config / "projects" / "github.com" / "acme" / "widgets"),
    ]


def test_repo_kit_needs_trust_and_loses_it_on_change(config, home):
    repo = make_repo(home / "widgets")
    ref = kits.KitRef(make_kit(repo / ".agent-kit"), "repo")
    assert not ref.trusted
    kits.record_trust(ref.path)
    assert ref.trusted
    (ref.path / "pyproject.toml").write_text('[project]\nname = "changed"\n')
    assert not ref.trusted


def test_venv_changes_do_not_break_trust(config, home):
    repo = make_repo(home / "widgets")
    ref = kits.KitRef(make_kit(repo / ".agent-kit"), "repo")
    kits.record_trust(ref.path)
    (ref.path / ".venv" / "bin" / "python").write_text("rebuilt")
    assert ref.trusted


def guard(payload, env):
    return subprocess.run(
        [str(GUARD), "pre-tool", "--harness", "claude"],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        env=env,
    )


def test_guard_runs_user_kits(config, home):
    repo = make_repo(home / "widgets")
    make_kit(config / "projects" / "github.com" / "acme" / "widgets")
    result = guard({"tool_name": "Bash", "tool_input": {"command": "ls"}, "cwd": str(repo)}, dict(os.environ))
    assert result.returncode == 2
    assert "(demo: no-ls)" in result.stderr


def test_guard_skips_untrusted_repo_kits(config, home):
    repo = make_repo(home / "widgets")
    make_kit(repo / ".agent-kit")
    result = guard({"tool_name": "Bash", "tool_input": {"command": "ls"}, "cwd": str(repo)}, dict(os.environ))
    assert result.returncode == 0
    kits.record_trust(repo / ".agent-kit")
    result = guard({"tool_name": "Bash", "tool_input": {"command": "ls"}, "cwd": str(repo)}, dict(os.environ))
    assert result.returncode == 2


def test_a_crashing_kit_does_not_block(config, home):
    repo = make_repo(home / "widgets")
    make_kit(config / "projects" / "github.com" / "acme" / "widgets", runner="#!/bin/sh\nexit 1\n")
    result = guard({"tool_name": "Bash", "tool_input": {"command": "ls"}, "cwd": str(repo)}, dict(os.environ))
    assert result.returncode == 0


def test_trust_file_is_protected_from_agents(config, home):
    from agent_kit.rules import kit
    from agent_kit.testing import rules, write

    assert rules(kit, write(str(config / "trusted.json"))) == ["machine-config"]
    assert rules(kit, write(str(config / "projects" / "x" / "checks.py"))) == []


def test_guard_runs_kit_commit_checks(config, home):
    repo = make_repo(home / "widgets")
    runner = (
        '#!/bin/sh\n[ "$1" = commit-msg ] || exit 0\n'
        "echo 'agent-kit rejected this commit (demo: jira-key): name the Jira key' >&2\nexit 1\n"
    )
    make_kit(config / "projects" / "github.com" / "acme" / "widgets", runner=runner)
    message = repo / "MSG"
    message.write_text("fix: thing\n")
    result = subprocess.run([str(GUARD), "commit-msg", str(message)], cwd=repo, capture_output=True, text=True)
    assert result.returncode == 1
    assert "(demo: jira-key)" in result.stderr
