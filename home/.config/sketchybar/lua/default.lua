local colors = require("lua.colors")
local settings = require("lua.settings")

-- Equivalent to the --default domain
sbar.default({
    updates = "when_shown",
    icon = {
        font = {
            family = settings.font.text,
            style = settings.font.style_map["Bold"],
            size = 13.0,
        },
        color = colors.white,
        padding_left = settings.paddings,
        padding_right = settings.paddings,
        background = { image = { corner_radius = 9 } },
    },
    label = {
        font = {
            family = settings.font.text,
            style = settings.font.style_map["Semibold"],
            size = 13.0,
        },
        color = colors.white,
        padding_left = settings.paddings,
        padding_right = settings.paddings,
    },
    background = {
        height = 26,
        corner_radius = 9,
        border_width = 2,
        border_color = colors.bar.border,
        image = {
            corner_radius = 8,
            border_color = colors.grey,
            border_width = 1,
        },
    },
    popup = {
        background = {
            border_width = 1,
            corner_radius = 16,
            border_color = colors.popup.border,
            color = colors.popup.bg,
            shadow = { drawing = true },
        },
    },
    padding_left = 3,
    padding_right = 3,
    scroll_texts = true,
})
