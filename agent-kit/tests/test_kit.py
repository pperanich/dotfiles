from agent_kit.api import Kit, block_command, block_paths
from agent_kit.testing import edit, rules, shell, write


def make_kit():
    kit = Kit("demo")
    block_command(kit, "prod-kubectl", command="kubectl", args=r"--context[= ]prod", message="use staging")
    block_paths(kit, "generated", patterns=["src/gen/*"], message="regenerate instead")

    @kit.commit_check("jira-key")
    def jira_key(text):
        return None if text.split(":", 1)[0].count("-") else "name the Jira key"

    return kit


def test_block_command_matches_name_and_args(home):
    kit = make_kit()
    assert rules(kit, shell("kubectl --context prod get pods")) == ["prod-kubectl"]
    assert rules(kit, shell("kubectl --context=staging get pods")) == []
    assert rules(kit, shell("echo kubectl --context prod")) == []


def test_block_paths_is_relative_to_the_repo_root(home):
    repo = home / "repo"
    (repo / ".git").mkdir(parents=True)
    (repo / "src" / "gen").mkdir(parents=True)
    kit = make_kit()
    assert rules(kit, write("src/gen/api.py", cwd=str(repo))) == ["generated"]
    assert rules(kit, edit(str(repo / "src" / "gen" / "api.py"), cwd=str(repo / "src"))) == ["generated"]
    assert rules(kit, shell("echo x > gen/api.py", cwd=str(repo / "src"))) == ["generated"]
    assert rules(kit, write("src/app.py", cwd=str(repo))) == []


def test_commit_checks_run_separately(home):
    kit = make_kit()
    assert [v.rule for v in kit.run_commit("fix: thing")] == ["jira-key"]
    assert kit.run_commit("ABC-12: thing") == []


def test_allow_env_skips_kit_rules(home, monkeypatch):
    monkeypatch.setenv("AGENT_KIT_ALLOW", "prod-kubectl")
    assert rules(make_kit(), shell("kubectl --context prod get pods")) == []


def test_rules_lists_every_registered_rule():
    assert make_kit().rules == ["prod-kubectl", "generated", "jira-key"]
