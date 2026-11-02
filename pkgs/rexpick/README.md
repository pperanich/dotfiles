# rexpick

A Rex-native terminal picker for sessions, local projects and OSC 7501 agent records. The Go binary uses Bubble Tea; it does not require fzf, tmux or Python. The Nix configuration installs it for the personal desktop profile; the normal Lua configuration under `home/.config/rex/` adds **Cmd+Shift+K** when deployed by Stow. Building the package alone changes no live configuration.

## Declarative integration

- `flake.nix` pins the upstream Rex snapshot flake through `flake.lock`, with its nixpkgs input following this repository's. Update only Rex with `nix flake update rex`.
- `modules/shell/rex.nix` imports the upstream Home Manager module, installs the Rex CLI/terminfo and `rexpick`, and leaves `programs.rex.config = null`. It does not enable a server service. On macOS, the existing Rex app continues to own the server; the Nix package does not install or replace the GUI app.
- `home/.config/rex/init.lua` remains an ordinary, editable, Stow-managed Lua file. It resolves the installed packages through `/etc/profiles/per-user/$USER` or `~/.nix-profile`, without relying on a GUI server's PATH or hardcoded store hashes. It uses the invoking app's client/session context, not a saved client ID. The tested low-level launcher is installed at `share/rexpick/float.lua` by the package.
- Only **Cmd+Shift+K** is added. Native Cmd+K, Cmd+Shift+P, splits, pane navigation, and other Rex defaults are preserved.
- `home/.ssh/config` includes the Stow-managed `home/.config/rex/ssh_config` before host settings. It falls back from `xterm-rex` to `xterm-256color` for remote hosts unless their exact hostname is listed in `~/.config/rex/terminfo-hosts`. Home Manager does not take over the SSH configuration.

After your normal system/Home Manager activation deploys the packages and Stow links, validate and reload the running server's configuration:

```sh
rex --autostart=false config check
rex --autostart=false config reload
```

Reloading configuration does not restart the server. No automatic reload, restart, system activation, or permanent live binding is performed merely by editing these repository files. On an empty Rex app, create/select a session first: the popup needs an existing session.

The current integration installs CLI support on personal desktop profiles; it does not enable Linux personal/shared/login servers or remote access. Those are separate per-host decisions.

## Build and run

From `pkgs/rexpick`:

```sh
go test ./...
go test -race ./...
go vet ./...
go build -o ./rexpick ./cmd/rexpick
./rexpick --rex /absolute/path/to/rex --client client:APP_ID
```

Use `rex client ls --json` to identify a **connected app** client ID (not a CLI connection). If exactly one connected app exists, `--client` may be omitted; otherwise ambiguity is an error. `--rex` defaults to `rex` on PATH. Optional `--server HOST_OR_ADDRESS` targets a different Rex server (otherwise the Rex CLI default); the picker always passes `--autostart=false`. Equivalent environment variables: `REXPICK_REX`, `REXPICK_CLIENT`, `REXPICK_SERVER`, `REXPICK_ROOTS`. A failed connection or snapshot is reported rather than silently starting a server. `./rexpick --help` lists flags.

Nix package exports are wired as `pkgs.rexpick` and `packages.<system>.rexpick`. From the repository root, use `nix build .#rexpick` to build it.

For experiments involving untracked package files, Git-backed flakes omit those new files. Build against the live checkout without staging or updating `flake.lock` with:

```sh
nix build --impure --no-link --expr 'let f = builtins.getFlake (toString ./.); pkgs = import f.inputs.nixpkgs { system = builtins.currentSystem; }; in pkgs.callPackage ./pkgs/rexpick { }'
```

That package uses the locked nixpkgs Go compiler, a real vendoring hash and a fileset limited to the Go sources. It also installs the shared Lua launcher from `examples/float.lua` into its output. Building it does **not** activate the user profile or run the picker.

## Keys and behavior

`Tab` / `Shift-Tab` switch Sessions, Projects, Agents; type to subsequence-filter; `Up` / `Down` or `Ctrl-P` / `Ctrl-N` select; `Enter` navigates; `?` opens help when search is empty. `Esc` / `Ctrl-C` exit without selecting. Enter asks the explicitly resolved Rex **app client** to select a session/window and exits on success; errors remain visible, then exiting returns nonzero. Preview is sanitized terminal capture, not an executable command. The UI redraw timer does not poll Rex.

Projects discover only explicitly configured local roots and depths. Defaults from the existing tms config: `~/dotfiles:1,~/nix-private:1,~/Documents/repos:2,~/repos:2` (depth 0 includes only the root). Override with `--roots '/path/to/repos:2,/other:1'`; paths containing commas/colons are not supported by this shorthand. Discovery is sorted, bounded, recognizes `.git` directories and worktree `.git` files, avoids discovered symlinks and never invokes Git or edits repositories. A project reuses an inspected session only if a terminal block has an unambiguous _exact canonical cwd match_; otherwise it creates a Rex session with that project's explicit cwd. It does not rename/synchronize existing worktrees or infer cwd from labels.

Agents bootstrap `program_status` records (including root and individual child IDs), subscribe via one persistent `rex events --all --json`, and show blocked, done, working, idle, then unknown states. Enter focuses the exact agent block and selects its session/window. Status titles/messages and captures are **untrusted text** and are sanitized; status never grants permission to approve/run something. No send-key, deletion, agent approval, or terminal command injection action exists in the picker.

## Floating launcher and explicit invocation

`examples/float.lua` defines a Rex action for a transient shell layer. Invoke it explicitly in a **chosen existing session**, replacing **all** example paths, session and app-client IDs:

```sh
/absolute/path/to/rex --autostart=false -C client:APP_ID do /absolute/path/to/pkgs/rexpick/examples/float.lua \
  -s session:SESSION_ID --action rexpick_float \
  --args '{"binary":"/absolute/path/to/rexpick","rex_cli":"/absolute/path/to/rex","client":"client:APP_ID","cwd":"/absolute/home/path","server":""}'
```

When targeting a nondefault server, pass `-S SERVER` to the outer `rex` call **and** `"server":"SERVER"` in the action arguments. The outer `-C` names the app; `client` is passed explicitly to Go for its later app selection. The action requires `-s` and invokes the specified Rex CLI via `rex.exec` with argv, `--autostart=false`, explicit session ID, a bounded timeout and JSON `session.new_layer` request. It checks the exit status and returned layer/block IDs; it neither shells out nor falls back to a login shell. In parent-owned live tests of the currently installed Rex Beta, Lua's direct `rex.session.new_layer` created a `/usr/bin/login` block despite serializing the intended command; the raw `rex api call session.new_layer` path launched Go. The CLI workaround passed the parent-owned live popup retest; the observation is not a general claim about Rex Lua behavior. The low-level launcher installs no binding itself; the Stow-managed config registers the convenient `rexpick` action and binds it. The normal child exit closes the temporary layer and restores focus. Rex's app-level `pane.send_key` fails on floating layers in the tested Beta build; use explicit block-addressed input for automation instead. Separate owner-assisted physical testing on 2026-11-02 verified Cmd+Shift+K, view/row navigation, search, selection, cancellation, and restored terminal input. This is not inferred from automated input. The original live tests also verified real project/real Pi status and cleanup.

Offline Lua checks never connect to Rex:

```sh
lua pkgs/rexpick/examples/float_test.lua
lua pkgs/rexpick/examples/config_test.lua
```

Run these from the repository root. The second check tests the stowed config against the shared launcher, including profile lookup, preserving defaults, runtime client/server selection, missing context, and failures.

## Prototype limitations

Rex does not expose a verified event revision/replay token: an event during disconnect, reconnect or snapshot boundaries can be missed or temporarily displayed stale. Failures are surfaced and reconnect takes a fresh snapshot with bounded retry; the status view is not an authorization signal. Discovery is local and bounded; cwd identities can change between inspection and selection. No persistent daemon, full tma parity, or worktree synchronization. Physical keyboard behavior was verified on the tested macOS/Rex build, not every client/platform. Independent source review, Go/Nix builds, 33 parent-owned live checks, and a window-only recording demonstrating multiple real projects and real Pi status are complete. See [VALIDATION.md](VALIDATION.md) for commands, evidence, recording path, capture method, and remaining limitations.
