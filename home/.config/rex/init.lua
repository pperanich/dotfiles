-- Stow owns the configuration and the adjacent project-picker source link.
local home = assert(os.getenv("HOME"))
local config_home = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")
local picker = dofile(config_home .. "/rex/rex-project-picker/picker.lua")

-- This table can also live in a separate file loaded with dofile.
picker.setup({
	roots = {
		{ path = home .. "/dotfiles", depth = 1 },
		{ path = home .. "/nix-private", depth = 1 },
		{ path = home .. "/repos", depth = 2 },
	},
	bounds = { 0.1, 0.2, 0.8, 0.6 }, -- x, y, width, height as window fractions
})

rex.bind("cmd+shift+k", "rex_project_picker")
