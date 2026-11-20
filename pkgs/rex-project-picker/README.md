# rex-project-picker

A project-only picker using Rex's embedded Lua engine, the native command palette
(`rex.ui.pick`), and a Bash helper running `fd`. No Go application, additional Lua
runtime, terminal popup, agent-status subscription, or background service.

## Configuration and launch

The Stow-managed `home/.config/rex/rex-project-picker` link points to this directory.
`home/.config/rex/init.lua` loads `picker.lua` and configures it with:

```lua
local home = assert(os.getenv("HOME"))
local config = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")
local picker = dofile(config .. "/rex/rex-project-picker/picker.lua")
picker.setup({
  roots = {
    { path = home .. "/dotfiles", depth = 1 },
    { path = home .. "/Documents/repos", depth = 2 },
    { path = home .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/vault", project = true },
  },
  names = {
    [home .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/vault"] = "iCloud vault",
  },
})
rex.bind("cmd+shift+k", "rex_project_picker")
```

Roots must be absolute paths. Depth 0 checks only the root; depth 2 also checks
two levels of subdirectories. Missing roots are skipped.

`project = true` lists that directory itself as a project, with no `.git` marker
and no walk, for a directory that is not a repository. It takes no depth, since
the declaration is about that one folder.

`names` maps an absolute project path to the title the palette shows for it and
the label its new session gets. An existing session found for that path is
renamed to match, so the configured name wins over a label the session already
had. An unnamed project shows its folder name and keeps whatever label its
session has. A name does not add a project: the path still has to be listed by a
root, through a `.git` marker or through `project = true`. Keys are canonical
paths, so a name still matches under a symlinked root.

To keep settings separately, put the setup table in a Lua file that returns it:

```lua
picker.setup(dofile(config .. "/rex/project-picker-settings.lua"))
```

`home/.config/rex/init.lua` keeps the roots every machine shares inline and
appends whatever roots `~/.config/rex/init.local.lua` returns when that file
exists, so a machine-only path never reaches the repository. `setup` replaces its
options rather than merging them, so a second `setup` call would drop the tracked
roots.

The module resolves `bash`, `fd`, and `pwd` through stable Nix profile paths, then
system paths. Override an executable with an absolute path in
`tools = { fd = "/path/to/fd" }` inside the setup table. `fd` is already installed
by this repository's shell tools module. The source and settings deploy through
Stow; there is no Nix package to activate.

After editing configuration:

```sh
rex --autostart=false config check
rex --autostart=false config reload
```

Press **Cmd+Shift+K**, or search for **rex-project-picker: Open Project** in the
command palette. Type to filter, Enter opens, Esc cancels. The CLI can run the
same action; with no `path` it asks in every connected Rex app and waits for an
answer, and with a `path` it opens that project without asking:

```sh
rex do rex_project_picker
rex do rex_project_picker path="$HOME/dotfiles"
```

`rex.client.queue` needs an app to switch to the session, so a CLI run needs
`-C CLIENT` and the app's Remote Control setting.

## Behavior and scope

Each row shows the project's name (or folder name) as its title, the parent
folder (or, for a named project, its full path) as its subtitle, a `branch` icon
for a repository or a `folder` icon for a declared project, and `open` when a
session already has a terminal in it. Open projects come first, then the rest by
title.

Discovery recognizes `.git` directories and worktree `.git` files, stays within
the configured depths, and skips discovered symlinks. The helper prints
NUL-terminated `NAME<TAB>PATH` records; no selected path is interpolated into
shell code. The whole list is read before the palette opens, and `rex.ui.pick`
accepts at most 2,000 rows.

Selection inspects tiled terminal blocks on demand. An exact canonical cwd match
reuses that project's tab: with one matching session, the active matching tab
wins, and any other ambiguity (several sessions, or several tabs with none
active) asks a second question listing the matching tabs. Otherwise it creates
a shell session at the selected path. The session scan runs again after the
choice, so a tab opened or closed while the palette was up is accounted for. If the shell changes into a subdirectory,
that terminal no longer exactly matches the project root. There is no persistent
project-to-session registry or concurrent creation lock.

A cancelled or timed-out prompt, or one refused because another prompt is open,
does nothing. A prompt no app can show (`no_client`, `unsupported`, `failed`)
fails the action with that reason.

Prompts only work in actions the server loaded from `init.lua`. An action run
from a file with `rex do FILE --action` gets `unsupported`.

## Remote hosts

Shortcuts come from your home server (`rex home`), so Cmd+Shift+K pressed in a
session on `pp-nas1` runs the home server's `rex_project_picker` with
`ctx.server` naming that host. The action then asks that host, through
`rex.server(ctx.server)`, to run `rex_project_picker_host`:

- `op=list` discovers projects under the host's own roots and marks the ones
  with a session there.
- `op=open path=... [session_id=... window_id=...]` finds or creates the
  project's session on the host. When the tab is ambiguous it returns the
  candidates as `choose` instead of asking.

Every prompt is shown by the home server's action, and it queues
`session.select` for the session the host returned. `rex_project_picker_host`
never prompts or queues client actions, so it also works from the CLI:

```sh
rex -S pp-nas1 do rex_project_picker_host op=list
```

The same `init.lua` deploys to every host with the `rex` home-manager module,
but each host's `~/.config/rex` links into that host's own `~/dotfiles`
checkout. A host only answers after its checkout has this version and
`rex -S HOST config reload` has run; until then the picker reports the error
from that host. Rex's Cmd+K session switcher and Activity sidebar cover
navigation and status for running sessions.

## Checks

```sh
bash -n pkgs/rex-project-picker/rex-project-picker
shellcheck pkgs/rex-project-picker/rex-project-picker
rex --autostart=false config check
PROJECT_PICKER_FD=$(command -v fd) \
  pkgs/rex-project-picker/rex-project-picker list "$HOME/repos" 2 | tr '\0' '\n'
```

`list` prints one `NAME<TAB>PATH` record per project, with the name defaulting to
the path, and accepts `--project PATH` and `--name PATH NAME` arguments.

The `rex-project-picker-config` flake check checks that a missing Stow source link
fails clearly and the deployed source loads without a running Rex server.

Checks on 2026-11-20 covered `config check`, path mode reusing an existing
session through the loaded action, the palette on the local server, both
`rex_project_picker_host` ops (including an ambiguous match returning `choose`
and a chosen tab being honored), and the remote branch with `rex.server`
stubbed to call this server's host action over the CLI. A real remote host and
the app's relay of `rex.server` calls were not exercised.
