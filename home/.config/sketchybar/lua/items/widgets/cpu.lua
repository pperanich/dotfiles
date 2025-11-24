local colors = require("lua.colors")
local icons = require("lua.icons")
local settings = require("lua.settings")

-- Execute the event provider binary which provides the event "cpu_update" for
-- the cpu load data, which is fired every 2.0 seconds.
sbar.exec(
    "killall cpu_load >/dev/null; " .. base_dir .. "/helpers/event_providers/cpu_load/bin/cpu_load cpu_update 2.0"
)

local cpu = sbar.add("graph", "widgets.cpu", 42, {
    position = "right",
    graph = { color = colors.blue },
    background = {
        height = 22,
        color = { alpha = 0 },
        border_color = { alpha = 0 },
        drawing = true,
    },
    icon = {
        string = icons.cpu,
        padding_left = 12,
        padding_right = 4,
    },
    label = {
        string = "cpu ??%",
        font = {
            family = settings.font.numbers,
            style = settings.font.style_map["Bold"],
            size = 9.0,
        },
        align = "right",
        padding_right = 12,
        width = 0,
        y_offset = 4,
    },
    padding_right = 0,
})

cpu:subscribe("cpu_update", function(env)
    -- Also available: env.user_load, env.sys_load
    local load = tonumber(env.total_load)
    if not load or load < 0 or load > 100 then
        return
    end

    cpu:push({ load / 100. })

    local color = colors.blue
    if load > 30 then
        if load < 60 then
            color = colors.yellow
        elseif load < 80 then
            color = colors.orange
        else
            color = colors.red
        end
    end

    cpu:set({
        graph = { color = color },
        label = "cpu " .. env.total_load .. "%",
    })
end)

cpu:subscribe("mouse.clicked", function(env)
    sbar.exec("open -a 'Activity Monitor'")
end)

-- Background around the cpu item
sbar.add("bracket", "widgets.cpu.bracket", { cpu.name }, {
    background = {
        color = colors.bg1,
        border_color = colors.transparent,
        border_width = 1,
        height = 30,
        corner_radius = 15,
    },
})

sbar.add("item", "widgets.cpu.padding", {
    position = "right",
    width = settings.group_paddings,
})
