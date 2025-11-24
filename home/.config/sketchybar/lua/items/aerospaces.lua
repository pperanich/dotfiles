-- Simplified aerospace workspace implementation
local app_icons = require("lua.helpers.app_icons")
local colors = require("lua.colors")
local icons = require("lua.icons")
local settings = require("lua.settings")

local spaces = {}

-- Create workspace items for numbered workspaces 1-8
for i = 1, 8, 1 do
    local space = sbar.add("item", "space." .. i, {
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
            height = 30,
            border_color = colors.transparent,
            corner_radius = 15,
            blur_radius = 2,
        },
        click_script = "/opt/homebrew/bin/aerospace workspace " .. i,
    })

    spaces[i] = space

    -- Single item bracket for space items to achieve double border on highlight
    local space_bracket = sbar.add("bracket", "bracket." .. i, { space.name }, {
        background = {
            color = colors.transparent,
            border_color = colors.transparent,
            height = 32,
            border_width = 1,
            corner_radius = 16,
        },
    })

    -- Padding space
    sbar.add("item", "space.padding." .. i, {
        width = settings.group_paddings,
    })

    -- Subscribe to aerospace_workspace_change event
    space:subscribe("aerospace_workspace_change", function(env)
        local selected = (env.FOCUSED_WORKSPACE == tostring(i))
        sbar.animate("tanh", 10, function()
            space:set({
                icon = { highlight = selected },
                label = { highlight = selected },
                background = { border_color = selected and colors.pink or colors.transparent },
            })
            space_bracket:set({
                background = { border_color = selected and colors.light_border or colors.transparent },
            })
        end)
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
        local selected = false
        -- Check if this space is currently focused
        sbar.exec("/opt/homebrew/bin/aerospace list-workspaces --focused", function(result)
            selected = (result:match("^%s*(.-)%s*$") == tostring(i))
            sbar.animate("tanh", 10, function()
                space_bracket:set({
                    background = { border_color = selected and colors.light_border or colors.transparent },
                })
            end)
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
    -- Get all windows and group by workspace
    sbar.exec("/opt/homebrew/bin/aerospace list-windows --all --format '%{app-name}|%{workspace}'", function(result)
        -- Clear all labels first
        for i = 1, 8 do
            spaces[i]:set({ label = "" })
        end

        -- Parse output and group apps by workspace
        local workspace_apps = {}
        for line in result:gmatch("[^\r\n]+") do
            local app, workspace = line:match("([^|]+)|([^|]+)")
            if app and workspace then
                workspace = tonumber(workspace)
                if workspace and workspace >= 1 and workspace <= 8 then
                    if not workspace_apps[workspace] then
                        workspace_apps[workspace] = {}
                    end
                    -- Only add unique apps
                    local found = false
                    for _, existing_app in ipairs(workspace_apps[workspace]) do
                        if existing_app == app then
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(workspace_apps[workspace], app)
                    end
                end
            end
        end

        -- Update labels with app icons
        for workspace, apps in pairs(workspace_apps) do
            local icon_line = ""
            table.sort(apps)
            for _, app in ipairs(apps) do
                local lookup = app_icons[app]
                local icon = ((lookup == nil) and app_icons["Default"] or lookup)
                icon_line = icon_line .. " " .. icon
            end
            spaces[workspace]:set({ label = icon_line })
        end
    end)
end

-- Subscribe to various events
space_window_observer:subscribe("aerospace_workspace_change", update_space_icons)
space_window_observer:subscribe("front_app_switched", update_space_icons)
space_window_observer:subscribe("space_windows_change", update_space_icons)

-- Initial update
update_space_icons()
