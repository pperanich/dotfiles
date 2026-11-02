# Prototype acceptance — 2026-11-02

This is the original prototype acceptance record. Subsequent owner-assisted
[physical keyboard verification](../../.agents/tasks/rex-go-prototype/keyboard-verification.md)
and [Nix/Stow integration](../../.agents/tasks/rex-go-prototype/nix-integration.md)
are recorded separately. The earlier untracked-source and unverified-keyboard
statements below describe the original acceptance stage, not the current state.

The uninstalled prototype passed independent source review, parent build checks,
and live Rex acceptance. No bindings/hooks were installed; no commit, push,
deployment, flake.lock change, or user/Rex configuration change was made.

## Recording

Playable local artifact:

`/Users/pperanich/Downloads/rexpick-demo-20261102-084204.mp4`

- H.264 MP4, 1920×1222, 50.07 seconds, 844,906 bytes.
- Actual Rex-window frames sampled approximately 3 times/second (164 captures),
  with real elapsed timing preserved in a 15 fps encoding. No reconstructed UI
  frames or unrelated windows. Sampled capture replaced a fixed-window macOS
  recording that developed black frames; that failed capture is not the deliverable.
- Shows Go Projects navigation among actual `dotfiles`, `tmux-agents`, and
  `tmux-sessionizer` directories using owned sessions; launches actual Pi 1.4.0;
  shows native **idle → working → done** in the Go Agents view; then jumps back
  to the Pi terminal from another project's session.
- Pi used a benign explanatory prompt with tools, extensions, context loading,
  MCP, and session persistence disabled. It did not inspect or modify repositories.
- Parent inspected the encoded contact sheet and an encoded working-state frame.
  Physical keyboard/shortcut parity is **not** claimed: demonstration input used
  Rex's explicit block-addressed send/send-key API.

## Automated and build gates

Final parent checks:

```sh
cd pkgs/rexpick
test -z "$(gofmt -l cmd internal)"
go test -count=1 ./...
go test -race -count=1 ./...
go vet ./...
go build -o /tmp/rex-go-prototype.bqGKQi/rexpick-final ./cmd/rexpick
```

All five packages passed. Targeted `nixfmt --check` passed for this package and
both exports. The final real Nix package build passed against locked nixpkgs,
including the actual vendor hash:

```sh
nix build --impure --no-link --print-out-paths --expr \
  'let f = builtins.getFlake (toString ./.); pkgs = import f.inputs.nixpkgs { system = builtins.currentSystem; }; in pkgs.callPackage ./pkgs/rexpick { }'
```

Demonstrated output: `/nix/store/kr8ckshj28aqa7fwq3h8may4x1p8mr7v-rexpick-0.1.0`.
After the test-only audit correction below, the final build is
`/nix/store/ygcc5czilmcffpmjd4xwzm0jhc1znrl2-rexpick-0.1.0`.
Their executables are **byte-identical**, SHA-256
`36f9c4fb38c64c943448d750942754f5e59ef7a2e8888cda21d2781ddcfa0b21`.
All 19 final Nix source inputs match the checkout; the only input changed since
the recording is `internal/rex/events_oversized_test.go`.

The untracked-source-aware flake export check also returned `rexpick`:

```sh
nix eval --raw 'path:/Users/pperanich/dotfiles#packages.aarch64-darwin.rexpick.pname' --no-write-lock-file
```

The optional launcher's offline Lua mock, Lua parse checks, and targeted StyLua
checks passed. No whole-repository `nix flake check` or system activation was claimed.

## Independent reviews

All reviewers were fresh-context Sol/high, separate from implementation:

1. Review 1 requested snapshot-overlap reconciliation and bounded event stderr.
   Both received deterministic RED/GREEN regressions and were corrected.
2. Review 2 accepted those corrections and found oversized event frames could
   strand a live subprocess. Termination/reaping/reconnect received RED/GREEN
   fake-CLI regressions, including successful subsequent event delivery.
3. Review 3 **APPROVED**, with no findings; full tests/race/vet and repeated
   focused race regressions passed.
4. A later live test exposed Rex Beta's direct-Lua floating-launch discrepancy.
   A narrow Lua-to-CLI compatibility correction and offline mock were separately
   **APPROVED**. Parent then verified the corrected launcher live.

Source review 3: run `fef0724a-c088-4ed1-a97a-5d95c43f8a2d`.
Launcher review: run `005d7c6f-5c82-4d11-a746-270cbe1d9a34`.

## Live acceptance

**33 checks passed**, with the actual Nix-built Go binary and an empty unrelated
session baseline. Coverage included:

- Sessions search, actual focused-terminal preview, app session selection,
  cancellation, focus restoration, and no input to the wrong session.
- Corrected optional Lua launcher opens Go and closes its floating layer on exit.
- Session creation/removal updates an already-open picker.
- Native OSC root and blocked child coexistence; live working/idle/done updates;
  descendant removal and root removal; exact cross-session agent block focus.
- Project discovery, canonical-cwd reuse without creating a duplicate, and new
  project-session creation at the exact requested cwd.
- Rex rejects control-bearing status text before publishing it; the Go view
  remains intact and accepts subsequent valid updates. Go escape sanitization
  is separately covered by automated tests; upstream rejection is not presented
  as proof of Go sanitization.

Initial parent harness failures were investigated rather than hidden: the preview
correctly follows the focused tab, not an arbitrary sibling; app focus restoration
lags server layer removal; removed status text can legitimately remain in a
terminal preview's scrollback. Final assertions account for these distinctions.
All owned test/demo sessions were removed. Final server listing was empty.

## Completion-audit finding and test-only repair

The first completion audit **rejected** acceptance after observing one failure in
`TestOversizedEventStopsAndReapsPersistentCLI` (former line 43). Ten focused and
five later full-suite reruns passed, but those passes did not erase the failure:
the old 600 ms deadline covered subprocess startup, oversized-frame generation,
scanning, termination, and reaping without readiness synchronization.

The test now concurrently drains both channels, observes the actual Scanner
`token too long` diagnostic under a separate bounded 5-second readiness budget,
and then requires automatic closure under a separate 1-second teardown budget.
It still checks retained diagnostics, no unexpected event, and PID reaping;
parent cancellation is failure cleanup, not a way to satisfy the assertion.
A marker-gated 750 ms delayed-start case exceeds the former deadline and verifies
the new phase separation. No production source, dependencies, or launcher changed.

Fresh Sol/high reviewer `f2643ee4-5604-4ce6-9612-caa1341d42ee` **APPROVED** the repair
with repeated focused normal/race tests, constrained `GOMAXPROCS=1` race runs,
full suites and vet. Parent then independently passed:

```sh
go test -count=5 ./...
go test -race -count=3 ./...
go vet ./...
go build -o /tmp/rex-go-prototype.bqGKQi/rexpick-post-audit ./cmd/rexpick
```

All five packages passed, as did the rebuilt real Nix package. Parent compared
all source-input hashes and the two Nix executables; the recording still shows
the exact final executable bytes. Extreme scheduler stalls can still exceed
finite test deadlines, but startup is no longer incorrectly charged to teardown.

## Local evidence

Parent evidence directory: `/tmp/rex-go-prototype.bqGKQi/` (temporary; video above
is retained separately in Downloads).

- `final-go-gates.log`, `final-nix-gate.log` (initial parent gates)
- `post-audit-go-gates.log`, `post-audit-nix-gate.log` (final repeated gates)
- `post-audit-source-hashes.json`, `post-audit-binary-equivalence.json`
- `live/go-live-final.log`, `live/go-live-results.json`, `live/go-live/commands.json`
- `live/go-live/{sessions-preview,projects,agents-blocked-child}.png`
- `live/record-demo-sampled.log`, `live/demo-timeline.json`
- `live/demo-pi-native-events.json`, `live/demo-delivery-sampled.json`
- `live/sampled-frames/frames.json`, `live/demo-working-video-frame.png`
- `live/final-demo-sampled/sessions-after.json`

## Remaining limitations

Rex supplies no verified revision/replay token or remote snapshot barrier.
Reconnect and bounded event-driven reconciliation improve consistency but cannot
guarantee recovery of every event missed during disconnect or transport races.
The display is never an authorization signal. Physical keyboard/shortcut behavior
remains unverified; the existing floating-pane `pane.send_key` issue is distinct
from direct block-addressed input. This is not full tma/worktree/daemon parity.
New package files remain untracked intentionally; ordinary Git-backed flake builds
exclude them until tracked. The callPackage build and path-flake export check above
required no staging or lock-file change.
