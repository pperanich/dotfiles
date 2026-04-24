-- Aerospace workspace implementation (i3/sway style: flat, numbers only)
local colors = require("lua.colors")
local settings = require("lua.settings")

local spaces = {}
local focused_workspace = nil

-- Build NSScreen-to-sketchybar display mapping dynamically
-- This runs once at startup to correlate screen positions
local nsscreen_to_sbar = {}
local function build_display_mapping()
	local config_dir = os.getenv("HOME") .. "/.config/sketchybar"
	local handle = io.popen(config_dir .. "/lua/helpers/display_mapping.sh 2>/dev/null")
	if handle then
		for line in handle:lines() do
			local ns_id, sbar_id = line:match("(%d+)|(%d+)")
			if ns_id and sbar_id then
				nsscreen_to_sbar[tonumber(ns_id)] = tonumber(sbar_id)
			end
		end
		handle:close()
	end
	-- Fallback: identity mapping if script fails
	if next(nsscreen_to_sbar) == nil then
		for i = 1, 10 do
			nsscreen_to_sbar[i] = i
		end
	end
end
build_display_mapping()

-- Get workspace-to-display mapping using aerospace NSScreen IDs
local function get_workspace_monitor_mapping()
	local mapping = {}
	local handle = io.popen(
		"/opt/homebrew/bin/aerospace list-workspaces --all --format '%{workspace}|%{monitor-appkit-nsscreen-screens-id}'"
	)
	if handle then
		for line in handle:lines() do
			local ws, nsscreen_id = line:match("([^|]+)|([^|]+)")
			if ws and nsscreen_id then
				ws = ws:match("^%s*(.-)%s*$")
				local ns_id = tonumber(nsscreen_id)
				mapping[ws] = nsscreen_to_sbar[ns_id] or 1
			end
		end
		handle:close()
	end
	return mapping
end

-- Dynamically get the list of workspaces from aerospace
local function get_aerospace_workspaces()
	local workspaces = {}
	local handle = io.popen("/opt/homebrew/bin/aerospace list-workspaces --all")
	if handle then
		for line in handle:lines() do
			local workspace = line:match("^%s*(.-)%s*$")
			if workspace and workspace ~= "" then
				table.insert(workspaces, workspace)
			end
		end
		handle:close()
	end
	return workspaces
end

local workspace_list = get_aerospace_workspaces()

if #workspace_list == 0 then
	for i = 1, 10 do
		table.insert(workspace_list, tostring(i))
	end
end

local workspace_displays = get_workspace_monitor_mapping()

-- Update all workspace display assignments on display_change / workspace moves
local function update_workspace_displays()
	sbar.exec(
		"/opt/homebrew/bin/aerospace list-workspaces --all --format '%{workspace}|%{monitor-appkit-nsscreen-screens-id}'",
		function(result)
			if not result then
				return
			end
			for line in result:gmatch("[^\r\n]+") do
				local ws, nsscreen_id = line:match("([^|]+)|([^|]+)")
				if ws and nsscreen_id then
					ws = ws:match("^%s*(.-)%s*$")
					local key = tonumber(ws) or ws
					local ns_id = tonumber(nsscreen_id)
					local new_display = nsscreen_to_sbar[ns_id] or 1
					if spaces[key] then
						spaces[key]:set({ display = new_display })
					end
				end
			end
		end
	)
end

-- Create workspace items: flat square, number only, solid fill when active
for _, workspace_id in ipairs(workspace_list) do
	local i = tonumber(workspace_id) or workspace_id
	local display_id = workspace_displays[workspace_id] or 1
	local space = sbar.add("item", "space." .. i, {
		display = display_id,
		icon = {
			font = { family = settings.font.text, style = settings.font.style_map["Bold"], size = 12.0 },
			string = tostring(i),
			padding_left = 10,
			padding_right = 10,
			color = colors.subtext0,
			highlight_color = colors.base,
			align = "center",
		},
		label = { drawing = false },
		padding_right = 0,
		padding_left = 0,
		background = {
			color = colors.transparent,
			border_width = 0,
			height = settings.item.height,
			corner_radius = 0,
		},
		click_script = "/opt/homebrew/bin/aerospace workspace " .. i,
	})

	spaces[i] = space

	space:subscribe("aerospace_workspace_change", function(env)
		focused_workspace = env.FOCUSED_WORKSPACE
		local selected = (focused_workspace == workspace_id)
		space:set({
			icon = { highlight = selected },
			background = { color = selected and colors.blue or colors.transparent },
		})
	end)

	space:subscribe("mouse.entered", function()
		sbar.animate("tanh", 10, function()
			local selected = (focused_workspace == workspace_id)
			space:set({
				background = { color = selected and colors.blue or colors.surface0 },
			})
		end)
	end)

	space:subscribe("mouse.exited", function()
		local selected = (focused_workspace == workspace_id)
		sbar.animate("tanh", 10, function()
			space:set({
				background = { color = selected and colors.blue or colors.transparent },
			})
		end)
	end)
end

-- Observer for display/workspace movement
local workspace_observer = sbar.add("item", {
	drawing = false,
	updates = true,
})

workspace_observer:subscribe("aerospace_workspace_change", update_workspace_displays)
workspace_observer:subscribe("display_change", update_workspace_displays)

-- Initial focus highlight
sbar.exec("/opt/homebrew/bin/aerospace list-workspaces --focused", function(result)
	if result then
		local ws = result:match("^%s*(.-)%s*$")
		if ws and ws ~= "" then
			sbar.trigger("aerospace_workspace_change", { FOCUSED_WORKSPACE = ws })
		end
	end
end)

sbar.add("event", "aerospace_mode_change")
sbar.add("event", "aerospace_window_move")

-- Mode indicator (flat, right-aligned, only visible in non-main modes)
local mode_indicator = sbar.add("item", "aerospace.mode", {
	position = "right",
	icon = { string = "", padding_left = 0, padding_right = 0 },
	label = {
		string = "",
		font = { family = settings.font.text, style = settings.font.style_map["Bold"], size = 11.0 },
		color = colors.base,
		padding_left = 10,
		padding_right = 10,
	},
	background = {
		color = colors.peach,
		corner_radius = 0,
		height = settings.item.height,
	},
	padding_left = 0,
	padding_right = 0,
	drawing = false,
	updates = true,
})

mode_indicator:subscribe("aerospace_mode_change", function(env)
	local mode = env.MODE
	if mode and mode ~= "" and mode ~= "main" then
		mode_indicator:set({
			label = { string = mode:upper() },
			drawing = true,
		})
	else
		mode_indicator:set({ drawing = false })
	end
end)
