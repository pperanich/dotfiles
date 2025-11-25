local app_icons = require("lua.helpers.app_icons")
local colors = require("lua.colors")
local settings = require("lua.settings")

-- Front app widget (centered, light border)
local front_app = sbar.add("item", "front_app", {
    position = "center",
    display = "active",
    icon = {
        string = app_icons["Default"],
        color = colors.light_border,
        padding_left = 12,
        padding_right = 4,
        font = "sketchybar-app-font:Regular:16.0",
    },
    label = {
        color = colors.white,
        padding_right = 12,
        font = { family = settings.font.text, style = settings.font.style_map["Bold"], size = 14.0 },
        max_chars = 50,
    },
    background = {
        color = colors.bg1,
        border_color = colors.light_border,
        border_width = 1,
        height = 30,
        corner_radius = 15,
    },
    updates = true,
})

front_app:subscribe("front_app_switched", function(env)
    local app_name = env.INFO
    local icon = app_icons[app_name] or app_icons["Default"]
    front_app:set({
        icon = { string = icon },
        label = { string = app_name },
    })
end)

front_app:subscribe("mouse.clicked", function()
    sbar.trigger("swap_menus_and_spaces")
end)
