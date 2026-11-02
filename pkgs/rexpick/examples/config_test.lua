-- Offline integration test of the Stow-managed config and packaged launcher.
-- Run: lua pkgs/rexpick/examples/config_test.lua
local real_dofile, real_getenv, real_open = dofile, os.getenv, io.open
local directory = arg[0]:match("^(.*[/])") or "./"
local config_path = directory .. "../../../home/.config/rex/init.lua"
local launcher_path = directory .. "float.lua"
local user_profile = "/etc/profiles/per-user/test-user"
local home = "/test home"
local home_profile = home .. "/.nix-profile"
local actions, bindings, files, command, payload, current_context, exec_count
local fail_exec

os.getenv = function(name)
	if name == "HOME" then
		return home
	elseif name == "USER" then
		return "test-user"
	end
	return nil
end
io.open = function(path)
	if files[path] then
		return { close = function() end }
	end
	return nil
end
dofile = function(path)
	assert(files[path], "unavailable launcher: " .. path)
	return real_dofile(launcher_path)
end

local function install(profile)
	for _, suffix in ipairs({ "/bin/rex", "/bin/rexpick", "/share/rexpick/float.lua" }) do
		files[profile .. suffix] = true
	end
end

local function reset()
	actions, bindings, files, exec_count, fail_exec = {}, {}, {}, 0, false
	rex = {
		action = function(action)
			assert(not actions[action.name])
			actions[action.name] = action
		end,
		bind = function(key, action)
			bindings[#bindings + 1] = { key, action }
		end,
		invoke = function(name, args)
			return actions[name].run(current_context, args)
		end,
		json = {
			encode = function(value)
				payload = value
				return "request"
			end,
			decode = function(value)
				assert(value == "response")
				return { layer_id = "layer:test", block_ids = { "block:test" } }
			end,
		},
		exec = function(argv, options)
			exec_count = exec_count + 1
			command = argv
			assert(options.timeout == 15)
			if fail_exec then
				return { ok = false, code = 1, stderr = "test failure" }
			end
			return { ok = true, code = 0, stdout = "response" }
		end,
	}
end

local function load()
	real_dofile(config_path)
	assert(exec_count == 0, "loading config must not launch processes")
	assert(#bindings == 1 and bindings[1][1] == "cmd+shift+k" and bindings[1][2] == "rexpick")
	assert(actions.rexpick and actions.rexpick_float)
end

local function invoke(ctx)
	current_context = ctx
	return actions.rexpick.run(ctx)
end

reset()
install(user_profile)
install(home_profile)
load()
for _, id in ipairs({ "client:first", "client:second" }) do
	invoke({ session_id = "session:current", client_id = id })
	local argv = payload.layout.block.options.command
	assert(argv[1] == user_profile .. "/bin/rexpick")
	assert(argv[3] == user_profile .. "/bin/rex" and argv[5] == id)
	assert(payload.session_id == "session:current" and payload.layout.block.options.cwd == home)
	assert(command[1] == user_profile .. "/bin/rex" and command[2] == "--autostart=false")
end
invoke({ session_id = "session:remote", client_id = "client:current", server = "remote-server" })
assert(payload.session_id == "session:remote")
assert(command[6] == "-S" and command[7] == "remote-server")
assert(payload.layout.block.options.command[7] == "remote-server")

for _, ctx in ipairs({ {}, { client_id = "" }, { client_id = "client:current" } }) do
	local before = exec_count
	assert(not pcall(invoke, ctx), "missing client/session must fail")
	assert(exec_count == before)
end
fail_exec = true
local ok, err = pcall(invoke, { session_id = "session:current", client_id = "client:current" })
assert(not ok and tostring(err):find("test failure", 1, true))

reset()
install(home_profile)
load()
invoke({ session_id = "session:current", client_id = "client:current" })
assert(command[1] == home_profile .. "/bin/rex")

reset()
install(user_profile)
files[user_profile .. "/share/rexpick/float.lua"] = nil
local missing_ok, missing_err = pcall(real_dofile, config_path)
assert(not missing_ok and tostring(missing_err):find("activate the Nix configuration first", 1, true))
assert(exec_count == 0 and #bindings == 0)

os.getenv, io.open, dofile = real_getenv, real_open, real_dofile
print("Stowed Rex config: profile resolution, binding, runtime context, and error checks passed")
