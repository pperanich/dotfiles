-- Uninstalled example. Invoke with an explicit session (-s), app client (-C),
-- rex_cli, binary, cwd, client and server ("" for the default server).
-- Lua session.new_layer produced /usr/bin/login in the observed Rex Beta build;
-- the same layout through the CLI control API launched rexpick correctly.
rex.action({
	name = "rexpick_float",
	title = "Rex Go Picker (prototype)",
	args = { binary = "string", rex_cli = "string", client = "string", cwd = "string", server = "string?" },
	run = function(ctx, args)
		for _, key in ipairs({ "binary", "rex_cli", "client", "cwd" }) do
			if type(args[key]) ~= "string" or args[key] == "" then
				error(key .. " is required", 0)
			end
		end
		if args.server ~= nil and type(args.server) ~= "string" then
			error("server must be a string", 0)
		end
		if type(ctx) ~= "table" or type(ctx.session_id) ~= "string" or ctx.session_id == "" then
			error("explicit Rex session required (pass -s SESSION)", 0)
		end

		local command = { args.binary, "--rex", args.rex_cli, "--client", args.client }
		if args.server and args.server ~= "" then
			command[#command + 1] = "--server"
			command[#command + 1] = args.server
		end
		local request, encode_err = rex.json.encode({
			session_id = ctx.session_id,
			bounds = { 0.1, 0.2, 0.8, 0.6 },
			focus = true,
			layout = {
				block = {
					flavor = "com.superlogical.terminal.shell",
					options = { command = command, shell = "none", cwd = args.cwd },
				},
			},
		})
		if not request then
			error("encode floating layout: " .. tostring(encode_err), 0)
		end

		-- Separate CLI connection avoids the observed Lua session.new_layer launch
		-- discrepancy. Do not pass -C here: the chosen app client is for the Go
		-- picker's later session.select, not for this server control API request.
		local argv = { args.rex_cli, "--autostart=false", "--color=never", "--timeout", "10s" }
		if args.server and args.server ~= "" then
			argv[#argv + 1] = "-S"
			argv[#argv + 1] = args.server
		end
		argv[#argv + 1] = "api"
		argv[#argv + 1] = "call"
		argv[#argv + 1] = "-s"
		argv[#argv + 1] = ctx.session_id
		argv[#argv + 1] = "session.new_layer"
		argv[#argv + 1] = request
		local process, exec_err = rex.exec(argv, { timeout = 15 })
		if not process then
			error("Rex CLI could not start: " .. tostring(exec_err), 0)
		end
		if not process.ok or process.timed_out then
			local detail = tostring(process.stderr or ""):sub(1, 512)
			error("Rex CLI session.new_layer failed (exit " .. tostring(process.code) .. "): " .. detail, 0)
		end
		local result, decode_err = rex.json.decode(process.stdout or "")
		if
			not result
			or type(result) ~= "table"
			or type(result.layer_id) ~= "string"
			or result.layer_id == ""
			or type(result.block_ids) ~= "table"
			or type(result.block_ids[1]) ~= "string"
			or result.block_ids[1] == ""
		then
			error(
				"invalid Rex CLI session.new_layer response: " .. tostring(decode_err or "missing layer/block IDs"),
				0
			)
		end
		return result
	end,
})
