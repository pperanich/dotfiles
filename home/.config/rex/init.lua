-- Stow owns the configuration and the adjacent project-picker source link.
-- Roots every machine shares belong here. Machine-only roots go in
-- ~/.config/rex/init.local.lua, which this file appends when it exists; that
-- file sits outside the repository, so Stow neither deploys nor removes it.
local home = assert(os.getenv("HOME"))
local config_home = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")
local picker = dofile(config_home .. "/rex/rex-project-picker/picker.lua")

local settings = {
	roots = {
		{ path = home .. "/dotfiles", depth = 1 },
		{ path = home .. "/Documents/repos", depth = 2 },
		-- The iCloud Obsidian vault. project = true lists that directory as a
		-- project without requiring a .git marker; the container is per Apple
		-- account, so a machine without it skips the entry.
		{ path = home .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/vault", project = true },
		{ path = home .. "/repos", depth = 2 },
	},
	-- Text the picker shows for a project, and the label its session gets.
	-- Naming does not add a project: the path still has to be listed by a root,
	-- through a .git marker or through project = true.
	names = {
		[home .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/vault"] = "iCloud vault",
	},
}

local local_file = config_home .. "/rex/init.local.lua"
local probe = io.open(local_file, "r")
if probe then
	probe:close()
	-- Absent is normal. Broken must fail loudly, so dofile runs outside pcall
	-- and picker.setup validates the roots it appends.
	local extra = dofile(local_file)
	assert(type(extra) == "table", local_file .. " must return a table")
	for _, root in ipairs(extra.roots or {}) do
		settings.roots[#settings.roots + 1] = root
	end
end

picker.setup(settings)

-- Hosts that run the Rex login server (my.rex.loginServer). It admits admin
-- workstations only; ssh reaches the same account when the tailnet port is shut.
for _, host in ipairs({ "pp-nas1", "pp-router1", "pp-wsl1" }) do
	rex.host({
		label = host,
		endpoints = { "http://" .. host .. ".pp-ts:7297", "ssh://" .. host .. ".pp-ts" },
	})
end
rex.host({
	label = "pp-wd1",
	endpoints = { "http://pp-wd1.pp-ts:7297" },
})

rex.bind("cmd+shift+k", "rex_project_picker")
