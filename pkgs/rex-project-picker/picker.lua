local terminal = "com.superlogical.terminal"
local directory = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/")
local home = assert(os.getenv("HOME"))
local options

local function tool(name)
	if options.tools and options.tools[name] then
		return options.tools[name]
	end
	local user = assert(os.getenv("USER"))
	for _, prefix in ipairs({
		"/etc/profiles/per-user/" .. user,
		home .. "/.nix-profile",
		"/run/current-system/sw",
		"/usr",
		"",
	}) do
		local path = prefix .. "/bin/" .. name
		local file = io.open(path, "rb")
		if file then
			file:close()
			return path
		end
	end
	error("rex-project-picker requires " .. name .. " in your Nix profile (or set tools." .. name .. ")", 0)
end

local function checked(result, err)
	if not result then
		error(tostring(err or "Rex returned no result"), 0)
	end
	return result
end

local function basename(path)
	return path:match("([^/]+)$") or path
end

local function parent(path)
	local dir = path:match("^(.*)/[^/]*$")
	return (dir == nil or dir == "") and "/" or dir
end

local function tilde(path)
	if path == home then
		return "~"
	elseif path:sub(1, #home + 1) == home .. "/" then
		return "~" .. path:sub(#home + 1)
	end
	return path
end

-- A cancelled, timed-out or already-open prompt is a quiet no-op; anything else
-- means no app could ask, which the person needs to see.
local function unanswered(why, detail)
	if why == "cancelled" or why == "timeout" or why == "busy" then
		return nil
	end
	error("rex-project-picker: " .. tostring(why) .. (detail and (": " .. detail) or ""), 0)
end

local function choose_tab(matches, title)
	local items, by_id = {}, {}
	for _, tab in ipairs(matches) do
		local id = tab.session_id .. "\n" .. tab.window_id
		by_id[id] = tab
		items[#items + 1] = {
			id = id,
			title = tab.session_label or "Untitled session",
			subtitle = tab.window_label,
			icon = "terminal",
			detail = tab.active and "active" or nil,
		}
	end
	local choice, why, detail = rex.ui.pick({ title = title, placeholder = "Filter tabs", items = items })
	if choice == nil then
		return unanswered(why, detail)
	end
	return by_id[choice]
end

local function setup(config)
	options = config
	assert(type(options.roots) == "table" and #options.roots > 0, "Configure at least one project root")
	for _, root in ipairs(options.roots) do
		assert(type(root.path) == "string" and root.path:sub(1, 1) == "/", "Project roots must be absolute paths")
		if root.project then
			-- A declared project is that one directory, marker or not, so a depth
			-- would only make the declaration mean something else.
			assert(root.depth == nil or root.depth == 0, "A declared project takes no depth")
		else
			assert(
				type(root.depth) == "number" and root.depth >= 0 and root.depth <= 32 and root.depth % 1 == 0,
				"Root depths must be integers in 0..32"
			)
		end
	end
	-- names maps an absolute project path to the text the picker shows for it.
	-- A named path still has to be discovered through a root, so naming alone
	-- never adds a project.
	options.names = options.names or {}
	local named_paths = {}
	for path, name in pairs(options.names) do
		assert(type(path) == "string" and path:sub(1, 1) == "/", "Name keys must be absolute paths")
		assert(
			type(name) == "string" and name ~= "" and not name:find("[%z\t\r\n]"),
			"Name values must be one line of non-empty text"
		)
		named_paths[#named_paths + 1] = path
	end
	table.sort(named_paths)

	-- Canonical paths are memoized per action run; the session scan, names and
	-- declared roots resolve the same strings repeatedly.
	local resolved = {}
	local function canonical(path)
		if type(path) ~= "string" or path:sub(1, 1) ~= "/" then
			return nil
		end
		if resolved[path] == nil then
			local process = rex.exec({ tool("pwd"), "-P" }, { cwd = path, timeout = 2 })
			resolved[path] = process and process.ok and (process.stdout:gsub("\n$", "")) or false
		end
		return resolved[path] or nil
	end

	-- True when a root declared the path with project = true. The literal key is
	-- the common case; canonical() covers a declared path behind a symlink.
	local function declared_project(path)
		for _, root in ipairs(options.roots) do
			if root.project and (root.path == path or canonical(root.path) == path) then
				return true
			end
		end
		return false
	end

	local function name_for(path)
		if options.names[path] then
			return options.names[path]
		end
		for _, key in ipairs(named_paths) do
			if canonical(key) == path then
				return options.names[key]
			end
		end
	end

	local function discover()
		local argv = { tool("bash"), directory .. "/rex-project-picker", "list" }
		for _, root in ipairs(options.roots) do
			if root.project then
				argv[#argv + 1] = "--project"
				argv[#argv + 1] = root.path
			else
				argv[#argv + 1] = root.path
				argv[#argv + 1] = tostring(root.depth)
			end
		end
		for _, path in ipairs(named_paths) do
			argv[#argv + 1] = "--name"
			argv[#argv + 1] = path
			argv[#argv + 1] = options.names[path]
		end
		local process = checked(rex.exec(argv, { env = { PROJECT_PICKER_FD = tool("fd") }, timeout = 10 }))
		if not process.ok then
			local reason = process.stderr ~= "" and process.stderr or ("exit " .. tostring(process.code))
			error("Project discovery failed: " .. reason, 0)
		end
		local projects = {}
		for record in process.stdout:gmatch("([^%z]+)%z") do
			local name, path = record:match("^([^\t]*)\t(.*)$")
			if path then
				projects[#projects + 1] = { name = name, path = path }
			end
		end
		return projects
	end

	local function block_cwd(session, block)
		local args = { session_id = session, block_id = block.block_id }
		local process = rex.block.call(terminal, "process", args)
		local cwd = canonical(process and process.foreground and process.foreground.cwd)
		if cwd then
			return cwd
		end
		local pwd = rex.block.call(terminal, "pwd", args)
		local path = pwd and pwd.pwd
		if type(path) == "string" and path:sub(1, 5) == "file:" then
			local host, encoded = path:match("^file://([^/]*)(/.*)$")
			if not encoded or (host ~= "" and host ~= "localhost") then
				return nil
			end
			path = encoded:gsub("%%(%x%x)", function(hex)
				return string.char(tonumber(hex, 16))
			end)
		end
		return canonical(path)
	end

	-- Maps each canonical terminal cwd to the tabs showing it, one entry per
	-- window. Floating layers are excluded from project identity.
	local function session_tabs()
		local tabs = {}
		for _, session in ipairs(checked(rex.call("session.list")).sessions or {}) do
			-- session.view refuses a session this action has not attached to.
			local view = checked(rex.call("session.attach", { session_id = session.session_id })).view
			for _, window in ipairs(view.windows or {}) do
				local seen = {}
				for _, layer in ipairs(window.layers or {}) do
					if layer.kind == "tiled" then
						for _, block in ipairs(layer.blocks or {}) do
							local cwd = block.creator_name == terminal and block_cwd(session.session_id, block)
							if cwd and not seen[cwd] then
								seen[cwd] = true
								tabs[cwd] = tabs[cwd] or {}
								table.insert(tabs[cwd], {
									session_id = session.session_id,
									session_label = session.label,
									window_id = window.window_id,
									window_label = window.label,
									active = window.window_id == view.active_window_id,
								})
							end
						end
					end
				end
			end
		end
		return tabs
	end

	local function list_items()
		local tabs = session_tabs()
		local items, seen = {}, {}
		for _, project in ipairs(discover()) do
			local path = project.path
			if not seen[path] then
				seen[path] = true
				local named = project.name ~= path
				items[#items + 1] = {
					id = path,
					title = named and project.name or basename(path),
					subtitle = tilde(named and path or parent(path)),
					icon = declared_project(path) and "folder" or "branch",
					detail = tabs[path] and "open" or nil,
				}
			end
		end
		table.sort(items, function(a, b)
			if (a.detail == nil) ~= (b.detail == nil) then
				return a.detail ~= nil
			end
			local left, right = a.title:lower(), b.title:lower()
			if left ~= right then
				return left < right
			end
			return a.id < b.id
		end)
		return items
	end

	-- Resolves the tab to reuse without asking: the requested tab if it still
	-- matches, the only match, or the active match within a single session.
	local function settle(matches, tab)
		if tab then
			for _, match in ipairs(matches) do
				if match.session_id == tab.session_id and match.window_id == tab.window_id then
					return match
				end
			end
		end
		local sessions, count = {}, 0
		for _, match in ipairs(matches) do
			if not sessions[match.session_id] then
				sessions[match.session_id] = true
				count = count + 1
			end
		end
		if count == 1 then
			if #matches == 1 then
				return matches[1]
			end
			for _, match in ipairs(matches) do
				if match.active then
					return match
				end
			end
		end
	end

	-- Opens a project on this server. When the tab is ambiguous it returns the
	-- candidates as `choose` so the caller, which can prompt, picks one.
	local function open_project(requested, name, tab)
		local path = assert(canonical(requested), "Project directory is unavailable")
		-- A root declared with project = true is a project without a marker;
		-- everything else still has to prove it is a repository.
		if not declared_project(path) then
			local marker = io.open(path .. "/.git", "r")
			assert(marker, "Selected directory has no .git marker")
			marker:close()
		end
		-- A configured name is the session's name: it labels a new session and
		-- is re-applied when an existing one is reused.
		local custom_label = name or name_for(path)
		if custom_label then
			custom_label = custom_label:gsub("%c", " "):sub(1, 100)
		end
		local matches = session_tabs()[path]
		if matches then
			local target = settle(matches, tab)
			if not target then
				return { choose = matches, label = custom_label or basename(path) }
			end
			if custom_label and target.session_label ~= custom_label then
				checked(rex.call("session.set_label", { session_id = target.session_id, label = custom_label }))
			end
			return { session_id = target.session_id, window_id = target.window_id, reused = true, path = path }
		end
		local created = checked(rex.call("session.create", {
			label = custom_label or basename(path):gsub("%c", " "):sub(1, 100),
			initial_windows = {
				{
					window_label = "Terminal",
					layout = { block = { flavor = terminal .. ".shell", options = { cwd = path } } },
				},
			},
		}))
		return {
			session_id = created.session_id,
			window_id = created.initial_windows[1].window_id,
			reused = false,
			path = path,
		}
	end

	local this_host = { list = list_items, open = open_project }

	-- A key pressed in another host's session runs this home-server action with
	-- ctx.server set; discovery and sessions then belong to that host.
	local function remote_host(label)
		local server = rex.server(label)
		local function request(args)
			local reply, err = server.call("client.action", { action = "rex_project_picker_host", args = args })
			if not reply then
				error(label .. ": " .. tostring(err) .. " (is rex-project-picker current there?)", 0)
			end
			return reply.result
		end
		return {
			list = function()
				local reply = request({ op = "list" })
				if type(reply) ~= "table" or type(reply.items) ~= "table" then
					error(label .. " returned no project list; update rex-project-picker there", 0)
				end
				return reply.items
			end,
			open = function(path, name, tab)
				return request({
					op = "open",
					path = path,
					name = name,
					session_id = tab and tab.session_id,
					window_id = tab and tab.window_id,
				})
			end,
		}
	end

	rex.action({
		name = "rex_project_picker",
		title = "rex-project-picker: Open Project…",
		args = { path = "string?", name = "string?" },
		run = function(ctx, args)
			resolved = {}
			local host = ctx.server and remote_host(ctx.server) or this_host
			local where = ctx.server and (" on " .. ctx.server) or ""
			local path = args.path
			if not path then
				local items = host.list()
				if #items == 0 then
					error("No projects found under the configured roots" .. where .. ".", 0)
				end
				local choice, why, detail = rex.ui.pick({
					title = "Open project" .. where,
					placeholder = "Filter projects",
					items = items,
				})
				if choice == nil then
					return unanswered(why, detail)
				end
				path = choice
			end
			local result = host.open(path, args.name)
			-- A tab chosen here can close before open runs again; ask at most twice.
			for _ = 1, 2 do
				if type(result) ~= "table" or not result.choose then
					break
				end
				local tab = choose_tab(result.choose, "Open " .. tostring(result.label) .. where .. " in")
				if not tab then
					return nil
				end
				result = host.open(path, args.name, tab)
			end
			if type(result) ~= "table" or not result.session_id then
				error("rex-project-picker: no tab to open for " .. path .. where, 0)
			end
			rex.client.queue("session.select", { session_id = result.session_id, window_id = result.window_id })
			return result
		end,
	})

	rex.action({
		name = "rex_project_picker_host",
		title = "rex-project-picker: Host Request",
		description = "Lists or opens this server's projects for a picker running on your home server.",
		args = { op = "string", path = "string?", name = "string?", session_id = "string?", window_id = "string?" },
		run = function(_, args)
			resolved = {}
			if args.op == "list" then
				return { items = list_items() }
			elseif args.op == "open" then
				assert(args.path, "op=open needs a path")
				local tab = args.session_id and { session_id = args.session_id, window_id = args.window_id }
				return open_project(args.path, args.name, tab)
			end
			error("rex_project_picker_host: unknown op " .. tostring(args.op), 0)
		end,
	})
end

return { setup = setup }
