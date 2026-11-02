# Physical keyboard verification — 2026-11-02

Todo #7 is complete. This follow-up establishes physical input behavior that the
earlier automated prototype acceptance deliberately did not claim.

## Scope and authorization

The owner explicitly authorized a temporary Cmd+Shift+K binding and an assisted
physical keyboard test. No permanent binding, package installation, or app-level
shortcut override was installed. Rex Beta was 0.1.0 (1696), server
0.0.1793377904-ge6592f. AeroSpace was in main mode.

The existing Nix executable was used:
`/nix/store/ygcc5czilmcffpmjd4xwzm0jhc1znrl2-rexpick-0.1.0/bin/rexpick`.
No Go product code changed.

## Setup

Two explicitly owned scratch sessions, rex-keyboard-alpha and rex-keyboard-beta,
ran `/bin/cat -u`, not a shell. Temporary project roots were restricted to the
scratch directories. The temporary Lua binding invoked the reviewed floating
launcher and refused invocation outside those two session IDs.

Before loading the binding, Rex reported an absent config file and no custom
bindings; `~/.config/rex/` itself was absent. The generated config passed
`rex config check`; the loaded keymap contained only the temporary binding.
A direct action invocation verified launcher setup, but was not counted as a
physical-shortcut test. Original absence and a content hash were recorded for
safe restoration without overwriting subsequent user edits.

## Physical checks

The owner reported these steps passed using the keyboard:

1. Cmd+Shift+K opens the floating picker.
2. Up/Down and Ctrl+P/Ctrl+N move selection.
3. Tab/Shift+Tab switch among Sessions, Projects, and Agents.
4. Typing `beta` filters; Enter selects BETA and closes the popup.
5. Cmd+Shift+K reopens it; Escape closes it without leaving BETA.

These are owner-reported physical observations, not automated key-injection proof.

The initial response said all six requested steps passed, but the final BETA
capture did not contain the requested `keyboard-ok` marker. On clarification,
the owner confirmed the final typing step had been skipped. That omission was
not counted as a successful focus/input check.

A separate isolated BETA recheck opened the real picker without reinstalling a
binding. The owner physically pressed Escape, typed `keyboard-ok`, and pressed
Return. Both the owner and the subsequent server inspection confirmed success:

- BETA terminal capture contains `keyboard-ok` (echoed by the terminal and cat).
- The original base block is focused.
- The popup block is removed.

This completes cancellation/focus restoration and physical typing verification.
The app-level `pane.send_key` floating limitation remains; physical typing works.
See `floating-input-followup.md` for its accepted automation workaround.

## Cleanup

After the first test, the temporary config was removed only after verifying its
recorded SHA-256. Rex was reloaded and confirmed the original absent config and
empty custom keymap. The previously absent config directory was removed while
empty. Both original scratch sessions were killed by exact owned IDs.

After the final recheck, its single owned session was also removed. The final
Rex session list was empty, no custom bindings remained, and `~/.config/rex/`
was absent. Cmd+Shift+K is therefore **not installed now**.

## Evidence

Temporary evidence under `/tmp/rex-go-prototype.bqGKQi/live/`:

- `manual-keyboard-20261102/manifest.json`
- `manual-keyboard-20261102/init.lua.candidate`
- `manual-keyboard-20261102/commands.json` (launcher preflight)
- `manual-keyboard-20261102/physical-confirmation.json` (initial missing marker)
- `manual-keyboard-20261102/cleanup-commands.json`
- `manual-keyboard-20261102/sessions-after.json`
- `manual-focus-recheck-20261102/physical-confirmation.json` (marker/focus/removal)
- `manual-focus-recheck-20261102/manifest.json`
- `manual-focus-recheck-20261102/sessions-after.json`

The earlier VALIDATION.md and recording retain their original, narrower automated
acceptance claims. This document records the later owner-assisted verification.
