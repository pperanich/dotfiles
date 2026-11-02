-- Stow owns this file; Nix installs Rex, rexpick, and the shared launcher.
-- Keep Rex's native shortcuts, including Cmd+K and Cmd+Shift+P.
local home = assert(os.getenv("HOME"), "HOME is required for the Rex configuration")
local user = assert(os.getenv("USER"), "USER is required for the Rex configuration")

local function readable(path)
	local file = io.open(path, "rb")
	if not file then
		return false
	end
	file:close()
	return true
end

-- GUI-launched servers need not inherit a login shell's PATH. Use the stable
-- profile paths, not a particular Nix store hash or the app's version directory.
local profile
for _, candidate in ipairs({ "/etc/profiles/per-user/" .. user, home .. "/.nix-profile" }) do
	if
		readable(candidate .. "/bin/rex")
		and readable(candidate .. "/bin/rexpick")
		and readable(candidate .. "/share/rexpick/float.lua")
	then
		profile = candidate
		break
	end
end
if not profile then
	error(
		"Rex configuration requires rex and rexpick in the same Nix profile; activate the Nix configuration first.",
		0
	)
end

dofile(profile .. "/share/rexpick/float.lua")

rex.action({
	name = "rexpick",
	title = "Sessions, Projects, and Agents…",
	description = "Open the floating rexpick navigator",
	run = function(ctx)
		-- Always target the invoking app, never a stored client ID or a guessed app.
		if type(ctx) ~= "table" or type(ctx.client_id) ~= "string" or ctx.client_id == "" then
			error("Invoke rexpick from a Rex app, or pass an explicit app client with -C.", 0)
		end
		local result, err = rex.invoke("rexpick_float", {
			binary = profile .. "/bin/rexpick",
			rex_cli = profile .. "/bin/rex",
			client = ctx.client_id,
			cwd = home,
			server = ctx.server or "",
		})
		if not result then
			error(tostring(err or "rexpick launch failed"), 0)
		end
		return result
	end,
})

rex.bind("cmd+shift+k", "rexpick")
