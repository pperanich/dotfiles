from agent_kit.shell import simple_commands, strip_heredocs


def argvs(script):
    return [c.argv for c in simple_commands(script)]


def test_splits_on_operators_and_keeps_quoted_words():
    assert argvs('echo "a;b" && ls -l | wc -l; pwd') == [["echo", "a;b"], ["ls", "-l"], ["wc", "-l"], ["pwd"]]


def test_newlines_separate_commands():
    assert argvs("cd x\nmake") == [["cd", "x"], ["make"]]


def test_empty_quoted_argument_survives():
    assert argvs("sed -i '' s/a/b/ f") == [["sed", "-i", "", "s/a/b/", "f"]]


def test_redirect_targets_leave_argv():
    (cmd,) = simple_commands("echo hi >> ~/.ssh/config 2>&1")
    assert cmd.argv == ["echo", "hi"]
    assert cmd.redirects == ["~/.ssh/config"]


def test_input_redirect_is_not_a_write_target():
    (cmd,) = simple_commands("wc -l < notes.txt")
    assert cmd.redirects == []


def test_heredoc_body_is_data():
    script = "cat > out.txt <<'EOF'\nsed -i '' x f\nEOF\nls"
    assert "sed" not in strip_heredocs(script)
    assert argvs(script) == [["cat"], ["ls"]]


def test_here_string_is_not_a_heredoc():
    assert argvs("grep x <<< 'a b'\nls") == [["grep", "x"], ["ls"]]


def test_unwraps_assignments_and_wrappers():
    assert argvs("FOO=1 env -u BAR sudo -u root timeout 5 nice -n 2 python3 x.py") == [["python3", "x.py"]]


def test_loop_condition_is_flagged():
    commands = simple_commands("while true; do sleep 5; done")
    assert commands[0].loop and commands[0].argv == ["true"]
    assert commands[1].argv == ["sleep", "5"]


def test_comment_line_is_dropped():
    assert argvs("# python3 x.py\nls") == [["ls"]]


def test_unterminated_quote_returns_none():
    assert simple_commands("echo 'oops") is None
