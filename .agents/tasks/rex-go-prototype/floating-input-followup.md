# Floating-pane input follow-up — 2026-11-02

## Disposition

The owner accepted the verified block-addressed automation workaround and closure
of todo #8 as an investigation. This does **not** mean Rex's app-level API is fixed.
Physical keyboard behavior was subsequently verified in the owner-assisted test
recorded in `keyboard-verification.md` (todo #7), including the temporary launcher
shortcut and restored terminal input. The app-level API limitation remains.

## Reproduction and isolation

Installed app: Rex Beta 0.1.0 (1696).
Server: 0.0.1793377904-ge6592f.

A fresh parent-owned session ran `/bin/cat -u` in two tiled panes. In the same
second pane:

1. `rex -C CLIENT do pane.send_key key=m` succeeded and produced `m`.
2. Rex's own `pane.float` action floated that pane.
3. `rex -C CLIENT do pane.send_key -s SESSION -b BLOCK key=n` failed with
   `"Send Key" isn't available here right now.` The server still identified that
   exact block as focused.
4. `rex send-key -s SESSION -b BLOCK o` succeeded; capture contained `mo`.
5. After closing only the owned floating layer, app-level input worked again in
   the underlying tiled pane.

A separate comparison also rejected implicit targeting, explicit session-only,
explicit block-only, explicit session+block, key-origin action dispatch, and
explicit server refocusing while floating. Changing the origin is automation,
not a physical-keyboard test.

The actual Nix-built Go picker was then opened using its reviewed Lua launcher.
Its Sessions view rendered. App-level Tab failed with the same error; direct
block-addressed Tab selected Projects, and direct Escape dismissed the picker.
No product code change was needed for this workaround.

The first generic server-created-layer probe showed login text rather than
verified `cat` startup. That case is not relied upon as proof of the intended
program launch. The same-block native Float Pane reproduction and independently
verified Go-picker rendering above provide the isolation evidence.

## Supported workaround

Use explicit session and block IDs returned by the owned popup launch:

```sh
rex --autostart=false send-key -s "$session_id" -b "$popup_block_id" tab
rex --autostart=false send-key -s "$session_id" -b "$popup_block_id" escape
```

Do not route automation through app-level `pane.send_key` while a floating pane
is focused. Do not infer hardware keyboard dispatch from these commands. Verify
ownership and the target program before sending input; never target a user pane
by label or guessed focus.

## Evidence and cleanup

- `/tmp/rex-go-prototype.bqGKQi/live/input-investigation.py`
- `/tmp/rex-go-prototype.bqGKQi/live/input-investigation-20261102/results.json`
- `/tmp/rex-go-prototype.bqGKQi/live/input-isolation-confirm.py`
- `/tmp/rex-go-prototype.bqGKQi/live/input-isolation-confirm-20261102/commands.json`
- Both evidence directories contain `sessions-before.json` and
  `sessions-after.json`, confirming empty baselines and complete scratch cleanup.

No production bindings, Rex settings, or product files were changed during this
investigation. The root cause inside Rex has not been established; the evidence
isolates a reproducible app-level floating-input limitation, not a Go TUI defect.
