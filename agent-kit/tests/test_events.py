from agent_kit.events import normalize


def test_codex_argv_command_unwraps_bash_c():
    event = normalize({"tool_name": "shell", "tool_input": {"command": ["bash", "-lc", "python3 x.py"]}}, "codex")
    assert (event.kind, event.command) == ("shell", "python3 x.py")


def test_codex_argv_command_without_shell_is_joined():
    event = normalize({"tool_name": "exec_command", "tool_input": {"cmd": ["sed", "-i", "", "s/a/b/", "f"]}}, "codex")
    assert event.command == "sed -i '' s/a/b/ f"


def test_apply_patch_yields_paths_and_added_lines():
    patch = "*** Begin Patch\n*** Update File: ~/.ssh/config\n@@\n-old\n+Host x\n*** Add File: notes.md\n+hello\n*** End Patch"
    event = normalize({"tool_name": "apply_patch", "tool_input": {"input": patch}}, "codex")
    assert event.kind == "edit"
    assert event.paths == ["~/.ssh/config", "notes.md"]
    assert event.new_text == "Host x\nhello"


def test_claude_multiedit_collects_new_strings():
    payload = {
        "tool_name": "MultiEdit",
        "tool_input": {
            "file_path": "a.py",
            "edits": [{"old_string": "a", "new_string": "b"}, {"old_string": "c", "new_string": "d"}],
        },
    }
    event = normalize(payload, "claude")
    assert (event.kind, event.paths, event.new_text) == ("edit", ["a.py"], "b\nd")


def test_unknown_tool_keeps_its_strings():
    event = normalize(
        {"tool_name": "mcp__github__add_comment", "tool_input": {"body": "x", "meta": {"n": 1}}}, "claude"
    )
    assert (event.kind, event.strings) == ("other", ["x"])
