# Declarative Rex integration — 2026-11-02

## Approved ownership

The owner requested Nix integration, specifically retained ordinary configuration
files under `home/` for Stow, and approved importing the official Rex Home Manager
module without letting it manage Lua or SSH configuration.

Implemented:

- Official Rex snapshot input, following the repository's nixpkgs. Locked immutable
  release: `0.0.1793632279-ge7974b`. Only the new `rex` node and root input reference
  were added; every existing input node remained byte-for-byte equivalent as JSON.
- `modules/shell/rex.nix`, imported by the personal desktop home profile, enables
  `programs.rex`, installs `pkgs.rexpick`, and leaves both config generation and SSH
  ownership disabled. No server service is enabled, on Darwin or Linux.
- `home/.config/rex/init.lua` registers the picker action and Cmd+Shift+K only.
  It finds both executables and the shared launcher in stable Nix profile paths,
  and uses the invoking app/session context instead of hardcoded IDs.
- The existing tested launcher is installed by `pkgs/rexpick/default.nix` at
  `share/rexpick/float.lua`. The Go sources are unchanged.
- The stowed SSH config includes `home/.config/rex/ssh_config` first. This follows
  the upstream TERM fallback, with an explicit `Match all` reset after the guard.
- README documents activation/reload, normal config ownership, defaults, scope,
  standalone invocation, and the previously completed physical keyboard tests.

## Checks

Passed:

1. Real Nix build of upstream Rex for aarch64-darwin.
2. Real Nix build of rexpick including the installed Lua helper. The resulting Go
   executable is byte-identical to the previously audited executable.
3. pp-ml1 Home Manager evaluation: packages contain Rex and rexpick;
   `programs.rex.config = null`; no `xdg.configFile."rex/init.lua"`;
   `programs.ssh.enable = false`; `services.rex.enable = false`; all four terminfo
   file entries are generated. Home profile directory is
   `/etc/profiles/per-user/pperanich`.
4. pp-ml1 Home Manager activation derivation evaluates successfully. Not built or
   activated as a full home generation.
5. pp-ld1 Linux desktop evaluation confirms both packages, no generated Lua, and
   no enabled server service. No Linux runtime build or service test claimed.
6. Existing low-level launcher mock and new `examples/config_test.lua`: profile
   selection/fallback, exactly one binding, dynamic client/session/server context,
   missing context/profile, error propagation, and no subprocesses at config load.
7. Nixfmt, targeted deadnix/statix, StyLua, and git diff whitespace checks.
8. Go tests, race tests, and vet: all five packages pass.
9. SSH `-G` checks, with no network connection: Rex TERM fallback for unknown
   hosts, allowlisted host preservation, no change outside Rex, missing-allowlist
   fallback, and no leaked Match condition.
10. Scoped Stow deployment in a temporary target verifies all Rex files and the
    SSH include configuration are linked correctly. A full-repository simulated
    Stow traversal hit its 30-second time budget; it is not claimed as passed.
    No process or target files remained from that attempt.
11. Actual new Nix CLI + packaged picker + stowed Lua action, against the existing
    Rex Beta app/server, in an owned scratch session. The config checker reports
    one binding/two actions. The popup renders, Tab changes views, Escape closes
    it, and original focus is restored. All scratch sessions were removed.

The live test uses a temporary profile and a script-local environment shim only
while loading the config, then restores the real connection environment. It does
not install a live keybinding, alter user profiles, or reload the active config.
This verifies the configured action with the actual packages; it is separate from
the earlier owner-assisted physical key-dispatch verification.

An early context probe incorrectly combined `rex do -e` with `--action`; the CLI
requires a script file for that flag. The scratch session was cleaned up, and a
file-backed probe succeeded before implementation. This was a test invocation
correction, not a product change or unresolved failure.

## Outputs and evidence

- Rex: `/nix/store/l4mz82fav702jln8mgcs9lwaxhb8c2z2-rex-0.0.1793632279-ge7974b`
- rexpick: `/nix/store/l80k85xfndqar6myg1najcrjsi4xwkk5-rexpick-0.1.0`
- Home activation derivation:
  `/nix/store/d3blq101l0qlhk5fiir1ywrs7x9xsc3h-home-manager-generation.drv`
- `/tmp/rex-go-prototype.bqGKQi/nix-integration-go-gates.log`
- `/tmp/rex-go-prototype.bqGKQi/ssh-guard-results.json`
- `/tmp/rex-go-prototype.bqGKQi/live/nix-integration-test.py`
- `/tmp/rex-go-prototype.bqGKQi/live/nix-integration-live/` contains config check,
  launch, focus, command, and before/after session evidence.

## Activation boundary

At completion of the integration task, no system rebuild, Home Manager activation,
server restart, staging, commit, or push had been performed. The active Rex config remains absent and its custom keymap
empty. The SSH source is already symlinked from the checkout, so the new Include
line is visible there, but its Rex target is not deployed until Stow activation.

After the normal rebuild/activation, run `rex --autostart=false config check`
and `rex --autostart=false config reload`. The reload applies the Lua configuration
without restarting the server. The integration was validated before staging its new files, using an explicit
`path:` flake where needed. Once tracked, ordinary Git-backed flake evaluation
includes those files as well. No entire-system build or whole-flake
check is claimed.

## Post-activation profile filtering correction

The owner's subsequent activation exposed a gap in the original temporary-profile
check: Home Manager's inner environment linked all paths, but the outer
Darwin user profile applied `environment.pathsToLink` and hid
`share/rexpick/float.lua`. Both executables, Stow links, terminfo, and the SSH guard
passed live checks, but `rex config check` failed and the running server retained
its previous empty keymap. The packaged helper itself was present.

Correction: `modules/shell/rex.nix` now exports Darwin and NixOS companion modules
that add `/share/rexpick` to the link policy. Both platform user modules import
that support. This does not enable a server or change who owns the Lua config.
NixOS had the same missing path, so the correction covers both platforms.

`pkgs/rexpick/tests/profile.nix` models both actual buildEnv layers with the real
host's link policy. It first verifies that a bin-only negative control contains
both binaries but rejects the config because its helper is hidden, then requires
the host-policy profile to expose the helper and pass actual Rex config validation
(one binding, two actions). It does not connect to or restart a server.

- RED before the fix: the check failed with
  `Host profile link policy hides share/rexpick/float.lua`.
- GREEN after the fix: `checks.aarch64-darwin.rexpick-profile` builds successfully.
  Output: `/nix/store/j2mm2c81jvljnzm0js323gga2xhbygdg-rexpick-profile-check`.
- Both Darwin and NixOS host evaluations include `/share/rexpick`.
- The Linux check derivation and Darwin system derivation evaluate successfully;
  no Linux runtime test or entire-system build is claimed.
- Nixfmt, deadnix, targeted statix, both Lua tests, and whitespace checks pass.
- RED/GREEN logs: `/tmp/rex-go-prototype.bqGKQi/profile-regression-{red,green}.log`.

The owner subsequently activated the corrected generation. Post-activation checks
confirmed the installed helper, correct Stow links, and successful Lua validation
(one binding, two actions). A configuration-only reload advanced the running
server to generation 4 with `shift+cmd+k` mapped to `rexpick` and no diagnostics.
Server instance/start time and session count (zero) remained unchanged. Todo #20
is complete. No live profile was manually patched and Rex was not restarted.
Evidence: `/tmp/rex-go-prototype.bqGKQi/post-activation-verified.json`.
