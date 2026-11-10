# Skills tracked here

Only skills that exist nowhere else belong in this directory. Everything else
is installed per user into `~/.agents/skills/` on the machines that need it,
from whatever owns it:

| Skill | Install |
|---|---|
| `docshare` | copy `skills/docshare` from the internal skills repo |
| `no-mistakes` | `make skill` in kunchenguid/no-mistakes, then copy `skills/no-mistakes` |
| `rex` | `rex skill setup` |
| `web-artifacts-builder` | `npx skills add https://github.com/anthropics/skills --skill web-artifacts-builder` |
| `synced/*` | claude.ai organisation sync, not installed by hand |

Tracking a copy of any of those here creates a second source of truth that
drifts silently. If a skill gains an upstream, remove it from this directory
and install it instead.
