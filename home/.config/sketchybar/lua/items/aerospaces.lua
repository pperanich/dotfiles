-- Aerospace workspace implementation
local app_icons = require("lua.helpers.app_icons")
local colors = require("lua.colors")
local settings = require("lua.settings")

local spaces = {}
local space_brackets = {}
local space_paddings = {}
local focused_workspace = nil

-- Get workspace-to-monitor mapping using NSScreen IDs (maps to SketchyBar display)
local function get_workspace_monitor_mapping()
	local mapping = {}
	local handle = io.popen("/opt/homebrew/bin/aerospace list-workspaces --all --format '%{workspace}|%{monitor-appkit-nsscreen-screens-id}'")
	if handle then
		for line in handle:lines() do
			local ws, display = line:match("([^|]+)|([^|]+)")
			if ws and display then
				ws = ws:match("^%s*(.-)%s*$")
				mapping[ws] = tonumber(display)
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
			local workspace = line:match("^%s*(.-)%s*$") -- trim whitespace
			if workspace and workspace ~= "" then
				table.insert(workspaces, workspace)
			end
		end
		handle:close()
	end
	return workspaces
end

-- Get the list of workspaces
local workspace_list = get_aerospace_workspaces()

-- Fallback to a reasonable default if aerospace is not available
if #workspace_list == 0 then
	for i = 1, 10 do
		table.insert(workspace_list, tostring(i))
	end
end

-- Get initial workspace-monitor mapping
local workspace_displays = get_workspace_monitor_mapping()

-- Update all workspace display assignments (called on display_change and workspace moves)
local function update_workspace_displays()
	sbar.exec("/opt/homebrew/bin/aerospace list-workspaces --all --format '%{workspace}|%{monitor-appkit-nsscreen-screens-id}'", function(result)
		if not result then return end
		for line in result:gmatch("[^\r\n]+") do
			local ws, disp = line:match("([^|]+)|([^|]+)")
			if ws and disp then
				ws = ws:match("^%s*(.-)%s*$")
				local key = tonumber(ws) or ws
				local new_display = tonumber(disp)
				if spaces[key] then
					spaces[key]:set({ display = new_display })
				end
				if space_brackets[key] then
					space_brackets[key]:set({ display = new_display })
				end
				if space_paddings[key] then
					space_paddings[key]:set({ display = new_display })
				end
			end
		end
	end)
end

-- Create workspace items for each configured workspace
for _, workspace_id in ipairs(workspace_list) do
	local i = tonumber(workspace_id) or workspace_id
	local display_id = workspace_displays[workspace_id] or 1
	local space = sbar.add("item", "space." .. i, {
		display = display_id,
		icon = {
			font = { family = settings.font.text, style = settings.font.style_map["Bold"], size = 14.0 },
			string = i,
			padding_left = 12,
			padding_right = 4,
			color = colors.white,
			highlight_color = colors.white,
			align = "center",
			width = 30,
		},
		label = {
			padding_left = 4,
			padding_right = 12,
			color = colors.white,
			highlight_color = colors.white,
			font = "sketchybar-app-font:Regular:14.0",
			y_offset = -1,
		},
		padding_right = 0,
		padding_left = 0,
		background = {
			color = colors.bg1,
			border_width = 1,
			height = settings.item.height,
			border_color = colors.transparent,
			corner_radius = settings.item.corner_radius,
		},
		click_script = "/opt/homebrew/bin/aerospace workspace " .. i,
	})

	spaces[i] = space

	-- Single item bracket for space items to achieve double border on highlight
	local space_bracket = sbar.add("bracket", "bracket." .. i, { space.name }, {
		display = display_id,
		background = {
			color = colors.transparent,
			border_color = colors.transparent,
			height = settings.bracket.height,
			border_width = 1,
			corner_radius = settings.bracket.corner_radius,
		},
	})

	space_brackets[i] = space_bracket

	-- Padding space
	local space_padding = sbar.add("item", "space.padding." .. i, {
		display = display_id,
		width = settings.group_paddings,
	})

	space_paddings[i] = space_padding

	-- Subscribe to aerospace_workspace_change event
	space:subscribe("aerospace_workspace_change", function(env)
		focused_workspace = env.FOCUSED_WORKSPACE
		local selected = (focused_workspace == workspace_id)
		space:set({
			icon = { highlight = selected },
			label = { highlight = selected },
			background = { border_color = selected and colors.peach or colors.transparent },
		})
		space_bracket:set({
			background = { border_color = selected and colors.light_border or colors.transparent },
		})
	end)


	-- Mouse hover effects
	space:subscribe("mouse.entered", function(env)
		sbar.animate("tanh", 10, function()
			space_bracket:set({
				background = { border_color = colors.light_border },
			})
		end)
	end)

	space:subscribe("mouse.exited", function(env)
		-- Use cached focused_workspace instead of querying aerospace
		local selected = (focused_workspace == workspace_id)
		sbar.animate("tanh", 10, function()
			space_bracket:set({
				background = { border_color = selected and colors.light_border or colors.transparent },
			})
		end)
	end)
end

-- Observer for window changes to update app icons
local space_window_observer = sbar.add("item", {
	drawing = false,
	updates = true,
})

-- Update app icons when windows change
local function update_space_icons()
	sbar.exec("/opt/homebrew/bin/aerospace list-windows --all --format '%{app-name}|%{workspace}'", function(result)
		if not result or result == "" then
			return
		end
		-- Clear all labels first for configured workspaces
		for _, workspace_id in ipairs(workspace_list) do
			local key = tonumber(workspace_id) or workspace_id
			if spaces[key] then
				spaces[key]:set({ label = "" })
			end
		end

		-- Parse output and group apps by workspace (using sets for O(1) deduplication)
		local workspace_apps = {}
		local workspace_app_sets = {}
		for line in result:gmatch("[^\r\n]+") do
			local app, workspace = line:match("([^|]+)|([^|]+)")
			if app and workspace then
				app = app:match("^%s*(.-)%s*$")
				workspace = workspace:match("^%s*(.-)%s*$")

				if app ~= "" and workspace ~= "" then
					local workspace_key = tonumber(workspace) or workspace

					if not workspace_apps[workspace_key] then
						workspace_apps[workspace_key] = {}
						workspace_app_sets[workspace_key] = {}
					end
					-- O(1) deduplication using set
					if not workspace_app_sets[workspace_key][app] then
						workspace_app_sets[workspace_key][app] = true
						table.insert(workspace_apps[workspace_key], app)
					end
				end
			end
		end

		-- Update labels with app icons
		for workspace_key, apps in pairs(workspace_apps) do
			if spaces[workspace_key] then
				table.sort(apps)
				local icons_list = {}
				for _, app in ipairs(apps) do
					local lookup = app_icons[app]
					icons_list[#icons_list + 1] = lookup or app_icons["Default"]
				end
				spaces[workspace_key]:set({ label = " " .. table.concat(icons_list, " ") })
			end
		end
	end)
end

-- Subscribe to various events to update app icons
-- The individual space items handle their own highlight updates via aerospace_workspace_change
-- This observer handles updating the app icons for all workspaces when windows change
space_window_observer:subscribe("aerospace_workspace_change", function()
	update_space_icons()
	update_workspace_displays() -- Also handles manual workspace-to-monitor moves
end)
space_window_observer:subscribe("front_app_switched", update_space_icons)
space_window_observer:subscribe("space_windows_change", update_space_icons)
space_window_observer:subscribe("display_change", function()
	update_workspace_displays()
	update_space_icons()
end)

-- Initial update: get current focused workspace and trigger event to highlight it
sbar.exec("/opt/homebrew/bin/aerospace list-workspaces --focused", function(result)
	if result then
		local ws = result:match("^%s*(.-)%s*$")
		if ws and ws ~= "" then
			sbar.trigger("aerospace_workspace_change", { FOCUSED_WORKSPACE = ws })
		end
	end
end)
update_space_icons()

-- Register custom event for mode changes
sbar.add("event", "aerospace_mode_change")

-- Register custom event for window moves (triggered from aerospace keybindings)
sbar.add("event", "aerospace_window_move")
space_window_observer:subscribe("aerospace_window_move", update_space_icons)

-- Mode indicator (only shown when not in main mode)
local mode_indicator = sbar.add("item", "aerospace.mode", {
	icon = {
		string = "",
		padding_left = 0,
		padding_right = 0,
	},
	label = {
		string = "",
		font = { family = settings.font.text, style = settings.font.style_map["Bold"], size = 12.0 },
		color = colors.base,
		padding_left = 8,
		padding_right = 8,
	},
	background = {
		color = colors.peach,
		corner_radius = settings.mode.corner_radius,
		height = settings.mode.height,
	},
	padding_left = 8,
	padding_right = 0,
	drawing = false,
	updates = true,
})

mode_indicator:subscribe("aerospace_mode_change", function(env)
	local mode = env.MODE
	-- Hide indicator for main mode (default) or empty mode
	if mode and mode ~= "" and mode ~= "main" then
		mode_indicator:set({
			label = { string = mode:upper() },
			drawing = true,
		})
	else
		mode_indicator:set({ drawing = false })
	end
end)
