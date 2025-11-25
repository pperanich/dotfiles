local colors = require("lua.colors")
local icons = require("lua.icons")
local settings = require("lua.settings")

-- Apple menu widget (green accent)
sbar.add("item", { width = settings.group_paddings })

local apple = sbar.add("item", "apple", {
    icon = {
        string = icons.apple,
        color = colors.green,
        padding_left = 12,
        padding_right = 12,
        font = { family = settings.font.text, style = settings.font.style_map["Regular"], size = 17.0 },
    },
    label = { drawing = false },
    background = {
        color = colors.bg1,
        border_color = colors.green,
        border_width = 1,
        height = 30,
        corner_radius = 15,
    },
    click_script = base_dir .. "/helpers/menus/bin/menus -s 0",
})

sbar.add("item", { width = settings.group_paddings })
