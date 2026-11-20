from agent_kit.commitmsg import check


def test_clean_conventional_message():
    assert check("feat(guard): block BSD sed\n\nBody text.\n") == ([], [])


def test_attribution_trailer_is_an_error():
    errors, _ = check("fix: x\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\n")
    assert len(errors) == 1 and "machine authorship" in errors[0]


def test_em_dash_is_an_error():
    errors, _ = check("docs: one thing \N{EM DASH} another\n")
    assert len(errors) == 1 and "em dash" in errors[0]


def test_non_conventional_subject_only_warns():
    errors, warnings = check("Update the readme\n")
    assert errors == [] and len(warnings) == 1


def test_merge_and_revert_subjects_are_exempt():
    assert check("Merge branch 'main' into feature\n") == ([], [])
    assert check('Revert "feat: x"\n') == ([], [])


def test_comments_and_verbose_diff_are_ignored():
    raw = (
        "fix: y\n# Co-Authored-By: Claude\n"
        "# ------------------------ >8 ------------------------\n"
        "diff --git a/x b/x\n+text \N{EM DASH} with a dash\n"
    )
    assert check(raw) == ([], [])
