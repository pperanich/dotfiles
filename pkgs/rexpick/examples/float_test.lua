-- Offline Lua mock: lua pkgs/rexpick/examples/float_test.lua
local action, argv, opts, payload, exec_count
local response = { layer_id = "layer:fake", block_ids = { "block:fake" }, revision = 2 }
rex = {
	action = function(value)
		action = value
	end,
	json = {
		encode = function(value)
			payload = value
			return '{"fake":"payload"}'
		end,
		decode = function(value)
			assert(value == '{"fake":"response"}')
			return response
		end,
	},
	exec = function(command, options)
		exec_count = exec_count + 1
		argv, opts = command, options
		return { ok = true, code = 0, stdout = '{"fake":"response"}', stderr = "" }
	end,
}
dofile((arg[0]:gsub("float_test.lua$", "float.lua")))
local args = {
	binary = "/path with spaces/rexpick",
	rex_cli = "/path with spaces/rex",
	client = "client:app",
	cwd = "/private/tmp",
}
local ctx = { session_id = "session:test" }
local function check_error(context, values, pattern)
	local before = exec_count
	local ok, err = pcall(action.run, context, values)
	assert(not ok and tostring(err):find(pattern, 1, true), tostring(err))
	assert(exec_count == before, "invalid request launched CLI")
end
exec_count = 0
check_error({}, args, "explicit Rex session required")
check_error(ctx, { binary = "", rex_cli = args.rex_cli, client = args.client, cwd = args.cwd }, "binary is required")
check_error(ctx, { binary = args.binary, rex_cli = args.rex_cli, client = "", cwd = args.cwd }, "client is required")
check_error(ctx, { binary = args.binary, rex_cli = args.rex_cli, client = args.client, cwd = "" }, "cwd is required")
local got = action.run(ctx, args)
assert(got == response and got.block_ids[1] == "block:fake")
assert(payload.session_id == ctx.session_id and payload.layout.block.options.shell == "none")
assert(payload.layout.block.options.cwd == args.cwd and payload.layout.block.options.command[1] == args.binary)
assert(payload.layout.block.options.command[5] == args.client)
assert(#argv == 11 and argv[1] == args.rex_cli and argv[2] == "--autostart=false")
assert(argv[6] == "api" and argv[8] == "-s" and argv[9] == ctx.session_id)
assert(argv[10] == "session.new_layer" and argv[11] == '{"fake":"payload"}' and opts.timeout == 15)
args.server = "other-host"
action.run(ctx, args)
assert(payload.layout.block.options.command[6] == "--server" and payload.layout.block.options.command[7] == args.server)
assert(argv[6] == "-S" and argv[7] == args.server and argv[9] == "call" and argv[11] == ctx.session_id)
rex.exec = function()
	return { ok = false, code = 7, stderr = "server unavailable" }
end
local ok, err = pcall(action.run, ctx, args)
assert(not ok and tostring(err):find("server unavailable", 1, true))
rex.exec = function()
	return nil, "no executable"
end
ok, err = pcall(action.run, ctx, args)
assert(not ok and tostring(err):find("no executable", 1, true))
rex.exec = function()
	return { ok = true, stdout = "invalid" }
end
rex.json.decode = function()
	return nil, "bad JSON"
end
ok, err = pcall(action.run, ctx, args)
assert(not ok and tostring(err):find("bad JSON", 1, true))
rex.json.decode = function()
	return { layer_id = "layer:fake", block_ids = {} }
end
ok, err = pcall(action.run, ctx, args)
assert(not ok and tostring(err):find("missing layer/block IDs", 1, true))
print("float.lua offline argv/error mock: passed")
