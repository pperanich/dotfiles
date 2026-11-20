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


def test_pi_entry_is_rewritten_in_tilde_form(home):
    profile = home / ".pi" / "agent"
    profile.mkdir(parents=True)
    relative = os.path.relpath(install.PI_PACKAGE, profile.resolve())
    settings = profile / "settings.json"
    settings.write_text('{\n  "theme": "x",\n  "packages": ["npm:a@1", ' + json.dumps(relative) + "]\n}\n")
    install._pi_tilde_entry(profile, install.Report())
    want = install._short(install.PI_PACKAGE)
    assert install._pi_entry(profile) == want
    assert settings.read_text() == '{\n  "theme": "x",\n  "packages": ["npm:a@1", ' + json.dumps(want) + "]\n}\n"


def test_codex_skill_link_is_idempotent_and_removable(home, monkeypatch):
    monkeypatch.delenv("CODEX_HOME", raising=False)
    (home / ".codex").mkdir()
    install.codex_skill("install", install.Report())
    install.codex_skill("install", install.Report())
    link = home / ".codex" / "skills" / "write-agent-check"
    assert link.is_symlink() and (link / "SKILL.md").exists()
    install.codex_skill("uninstall", install.Report())
    assert not link.exists()


def test_codex_skill_leaves_a_foreign_directory_alone(home, monkeypatch):
    monkeypatch.delenv("CODEX_HOME", raising=False)
    foreign = home / ".codex" / "skills" / "write-agent-check"
    foreign.mkdir(parents=True)
    report = install.Report()
    install.codex_skill("install", report)
    assert report.problems == 1 and not foreign.is_symlink()
