"""Text that announces a machine wrote a commit, comment or pull request."""

import re

_TOOLS = r"(claude|codex|chatgpt|gpt|copilot|gemini|cursor|an? (ai|llm|agent))"
_PATTERNS = [
    re.compile(rf"generated (with|by) \[?{_TOOLS}", re.I),
    re.compile(r"co-authored-by:[^\n]*(claude|anthropic|codex|openai|chatgpt|copilot|gemini|cursor)", re.I),
    re.compile("\N{ROBOT FACE}"),
    re.compile(r"\bmachine[- ]written\b", re.I),
    re.compile(r"\bposted by an? (ai|agent|bot)\b", re.I),
    re.compile(
        r"\b(this|the) (pr|pull request|comment|review|description|issue|commit|change)"
        r"( description)? (was |is )?(written|generated|drafted|authored|created) (by|with|using) "
        rf"{_TOOLS}\b",
        re.I,
    ),
]


def find(text: str) -> str | None:
    """Return the first attribution phrase in text, or None."""
    for pattern in _PATTERNS:
        match = pattern.search(text)
        if match:
            return match.group(0).strip()
    return None
