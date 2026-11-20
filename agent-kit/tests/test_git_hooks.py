"""The global hooks path, exercised in throwaway repositories."""

import os
import subprocess

import pytest
from conftest import GUARD, KIT


@pytest.fixture
def repo(tmp_path):
    gitconfig = tmp_path / "gitconfig"
    gitconfig.write_text(
        f"[core]\n\thooksPath = {KIT / 'git-hooks'}\n[user]\n\tname = Test\n\temail = test@example.com\n"
    )
    env = {**os.environ, "GIT_CONFIG_GLOBAL": str(gitconfig), "GIT_CONFIG_NOSYSTEM": "1", "AGENT_GUARD": str(GUARD)}
    path = tmp_path / "repo"
    subprocess.run(["git", "init", "-q", "-b", "main", str(path)], check=True, env=env)
    (path / "f.txt").write_text("x\n")
    subprocess.run(["git", "add", "f.txt"], cwd=path, check=True, env=env)
    return path, env


def commit(repo, message):
    path, env = repo
    return subprocess.run(["git", "commit", "-q", "-m", message], cwd=path, env=env, capture_output=True, text=True)


def test_clean_commit_passes(repo):
    assert commit(repo, "feat: add f").returncode == 0


def test_attribution_trailer_is_rejected(repo):
    result = commit(repo, "feat: add f\n\nCo-Authored-By: Claude <noreply@anthropic.com>")
    assert result.returncode != 0
    assert "machine authorship" in result.stderr


def test_em_dash_is_rejected(repo):
    assert commit(repo, "feat: add f \N{EM DASH} quickly").returncode != 0


def test_repo_hooks_still_run(repo):
    path, _ = repo
    hooks = path / ".git" / "hooks"
    for name in ("pre-commit", "commit-msg"):
        hook = hooks / name
        hook.write_text(f'#!/bin/sh\necho ran > "$(git rev-parse --git-dir)/{name}.ran"\n')
        hook.chmod(0o755)
    assert commit(repo, "feat: add f").returncode == 0
    assert (path / ".git" / "pre-commit.ran").exists()
    assert (path / ".git" / "commit-msg.ran").exists()


def test_repo_hook_failure_still_blocks(repo):
    path, _ = repo
    hook = path / ".git" / "hooks" / "pre-commit"
    hook.write_text("#!/bin/sh\nexit 1\n")
    hook.chmod(0o755)
    assert commit(repo, "feat: add f").returncode != 0


def test_worktree_uses_the_main_repo_hooks(repo):
    path, env = repo
    assert commit(repo, "feat: add f").returncode == 0
    hook = path / ".git" / "hooks" / "pre-commit"
    hook.write_text('#!/bin/sh\necho ran > "$(git rev-parse --git-common-dir)/wt.ran"\n')
    hook.chmod(0o755)
    tree = path.parent / "wt"
    subprocess.run(["git", "worktree", "add", "-q", str(tree)], cwd=path, check=True, env=env)
    (tree / "g.txt").write_text("y\n")
    subprocess.run(["git", "add", "g.txt"], cwd=tree, check=True, env=env)
    result = subprocess.run(
        ["git", "commit", "-q", "-m", "feat: add g"], cwd=tree, env=env, capture_output=True, text=True
    )
    assert result.returncode == 0
    assert (path / ".git" / "wt.ran").exists()
