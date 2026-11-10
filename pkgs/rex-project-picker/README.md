# rex-project-picker

A project-only picker using Rex's embedded Lua engine, a native floating terminal,
and a Bash helper running `fd` and `fzf`. No Go application, additional Lua runtime,
agent-status subscription, or background service.

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
  bounds = { 0.1, 0.2, 0.8, 0.6 },
  names = {
    [home .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/vault"] = "iCloud vault",
  },
})
rex.bind("cmd+shift+k", "rex_project_picker")
```

Roots must be absolute paths. Depth 0 checks only the root; depth 2 also checks
two levels of subdirectories. Missing roots are skipped. `bounds` contains the
popup's x, y, width, and height as fractions of its window.

`project = true` lists that directory itself as a project, with no `.git` marker
and no walk, for a directory that is not a repository. It takes no depth, since
the declaration is about that one folder.

`names` maps an absolute project path to the text the popup shows for it and the
label its new session gets. An existing session found for that path is renamed to
match, so the configured name wins over a label the session already had. An
unnamed project shows its full path and keeps whatever label its session has. A
name does not add a project: the path still has to be listed by a root, through a
`.git` marker or through `project = true`. Keys are canonical paths, so a name
still matches under a symlinked root. Once a name is set, `fzf` filters on the
name rather than the path, because it searches what it displays.

To keep settings separately, put the setup table in a Lua file that returns it:

```lua
picker.setup(dofile(config .. "/rex/project-picker-settings.lua"))
```

`home/.config/rex/init.lua` keeps the roots every machine shares inline and
appends whatever roots `~/.config/rex/init.local.lua` returns when that file
exists, so a machine-only path never reaches the repository. `setup` replaces its
options rather than merging them, so a second `setup` call would drop the tracked
roots.

The module resolves `rex`, `bash`, `fd`, `fzf`, and `pwd` through stable Nix profile
paths, then system paths. Override an executable with an absolute path in
`tools = { fzf = "/path/to/fzf" }` inside the setup table. `fd` and `fzf` are already
installed by this repository's shell tools module. This prototype's source and
settings deploy through Stow; there is no new Nix package to activate.

After editing configuration:

```sh
rex --autostart=false config check
rex --autostart=false config reload
```

Press **Cmd+Shift+K**, or search for **rex-project-picker: Open Project** in the
command palette. From a Rex terminal, the helper can also launch the loaded action:

```sh
~/.config/rex/rex-project-picker/rex-project-picker
# From outside Rex, choose an existing session and connected app:
~/.config/rex/rex-project-picker/rex-project-picker popup SESSION APP_CLIENT
```

Type to filter; Up/Down or Ctrl-P/Ctrl-N move; Enter opens; Esc/Ctrl-C cancel.
The floating layer closes on normal exit. Errors stay visible until Enter.

## Behavior and scope

Discovery recognizes `.git` directories and worktree `.git` files, stays within
the configured depths, skips discovered symlinks, and sorts/deduplicates paths by
their displayed name. The list streams into `fzf` through a FIFO, so the popup
paints before discovery finishes; records stay NUL-separated through `fd`, `sort`,
and `fzf`, and each record is `NAME<TAB>PATH` so `fzf` can display the name and
accept the path. No selected path is interpolated into shell code.

Selection inspects tiled terminal blocks on demand. A unique exact canonical cwd
match reuses the session and matching tab; otherwise it creates a shell session
at the selected path. Multiple matching sessions produce an error rather than
choosing arbitrarily. With multiple matching tabs, the active matching tab wins.
If the shell changes into a subdirectory, that terminal no longer exactly matches
the project root. There is no persistent project-to-session registry or concurrent
creation lock.

This is a local-server prototype tested on macOS. It does not provide remote
project discovery or agent status. Rex's Cmd+K session switcher and Activity sidebar
provide those respective native navigation/status surfaces.

The launcher retains the earlier Beta workaround: create the floating layer
through `rex api call session.new_layer` from Lua instead of the direct Lua call.
The legacy `pkgs/rexpick` source and installed Go package remain untouched; only
the configured shortcut and associated configuration check now use this picker.

## Checks

```sh
bash -n pkgs/rex-project-picker/rex-project-picker
shellcheck pkgs/rex-project-picker/rex-project-picker
rex --autostart=false config check
pkgs/rex-project-picker/rex-project-picker list "$HOME/repos" 2 | tr '\0' '\n'
```

`list` prints one `NAME<TAB>PATH` record per project, with the name defaulting to
the path, and accepts the same `--project PATH` and `--name PATH NAME` arguments
the picker passes.

The `rex-project-picker-config` flake check checks that a missing Stow source link
fails clearly and the deployed source loads without a running Rex server.

Live checks on 2026-11-03 verified session creation, exact-cwd reuse through the
loaded config action, native popup rendering, filtering 76 projects to `dotfiles`,
and Escape closing the layer with original terminal focus restored. Fixture checks
covered depth limits, worktree markers, symlink policy, duplicate roots, missing
roots, and names containing spaces, quotes, shell characters, and newlines. These
checks used block-addressed input; physical shortcut input is not claimed.
