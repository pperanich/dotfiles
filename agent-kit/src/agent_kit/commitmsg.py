"""Check a commit message file, as the commit-msg hook passes it."""

import re

from . import attribution

_SCISSORS = "# ------------------------ >8 ------------------------"
_CONVENTIONAL = re.compile(r"^[a-z]+(\([^)]+\))?!?: \S")
_EXEMPT_SUBJECT = re.compile(r"^(Merge |Revert |fixup! |squash! |amend! )")


def message_text(raw: str) -> str:
    raw = raw.split(_SCISSORS, 1)[0]
    return "\n".join(line for line in raw.splitlines() if not line.startswith("#")).strip()


def check(raw: str) -> tuple[list[str], list[str]]:
    """Return (errors, warnings) for a commit message."""
    text = message_text(raw)
    errors: list[str] = []
    warnings: list[str] = []
    phrase = attribution.find(text)
    if phrase:
        errors.append(
            f"the message announces machine authorship ('{phrase}'). Drop the trailer or footer; commits carry no AI attribution."
        )
    if "\N{EM DASH}" in text:
        errors.append("the message contains an em dash. Use a comma, colon, parentheses or a second sentence.")
    subject = text.splitlines()[0] if text else ""
    if subject and not _EXEMPT_SUBJECT.match(subject) and not _CONVENTIONAL.match(subject):
        warnings.append(
            f"the subject is not a Conventional Commit (type(scope): summary): {subject!r}. Ignore this if the repo has its own convention."
        )
    return errors, warnings
