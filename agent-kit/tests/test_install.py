"""The installer's file edits, against throwaway homes."""

import json
import os

from agent_kit import install


def codex_hooks(home):
    return json.loads((home / ".codex" / "hooks.json").read_text())


def test_codex_install_merges_and_is_idempotent(home, monkeypatch):
    monkeypatch.delenv("CODEX_HOME", raising=False)
    (home / ".codex").mkdir()
    existing = {"hooks": {"SessionStart": [{"matcher": "", "hooks": [{"type": "command", "command": "gh-axi"}]}]}}
    (home / ".codex" / "hooks.json").write_text(json.dumps(existing))
    install.codex("install", install.Report())
    first = codex_hooks(home)
    install.codex("install", install.Report())
    assert codex_hooks(home) == first
    assert first["hooks"]["SessionStart"] == existing["hooks"]["SessionStart"]
    assert [h["command"] for g in first["hooks"]["PreToolUse"] for h in g["hooks"]] == [install.codex_command()]
    assert (home / ".codex" / "hooks.json.agent-kit.bak").exists()


def test_codex_uninstall_leaves_other_hooks(home, monkeypatch):
    monkeypatch.delenv("CODEX_HOME", raising=False)
    (home / ".codex").mkdir()
    other = {"matcher": "Bash", "hooks": [{"type": "command", "command": "other-guard"}]}
    (home / ".codex" / "hooks.json").write_text(json.dumps({"hooks": {"PreToolUse": [other]}}))
    install.codex("install", install.Report())
    install.codex("uninstall", install.Report())
    assert codex_hooks(home) == {"hooks": {"PreToolUse": [other]}}


def test_codex_without_a_home_is_skipped(home, monkeypatch):
    monkeypatch.delenv("CODEX_HOME", raising=False)
    install.codex("install", install.Report())
    assert not (home / ".codex").exists()


def test_claude_profiles_sharing_plugins_count_once(home, monkeypatch):
    monkeypatch.delenv("CLAUDE_CONFIG_DIR", raising=False)
    (home / ".claude" / "plugins").mkdir(parents=True)
    (home / ".claude-work").mkdir()
    (home / ".claude-work" / "plugins").symlink_to(home / ".claude" / "plugins")
    assert install.claude_dirs([]) == [home / ".claude"]


def test_pi_package_entry_is_found_by_relative_path(home):
    profile = home / ".pi" / "agent"
    profile.mkdir(parents=True)
    relative = os.path.relpath(install.PI_PACKAGE, profile.resolve())
    (profile / "settings.json").write_text(json.dumps({"packages": ["npm:x@1", relative]}))
    assert install._pi_has_kit(profile)
