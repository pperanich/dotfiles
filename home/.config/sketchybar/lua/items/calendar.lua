local colors = require("lua.colors")
local settings = require("lua.settings")

-- Padding item required because of bracket
sbar.add("item", { position = "right", width = settings.group_paddings })

local cal = sbar.add("item", {
    icon = {
        color = colors.white,
        padding_left = 12,
        font = { family = settings.font.text, style = settings.font.style_map["Bold"], size = 14.0 },
    },
    label = {
        color = colors.white,
        padding_right = 12,
        align = "right",
        font = { family = settings.font.text, style = settings.font.style_map["Bold"], size = 14.0 },
    },
    position = "right",
    update_freq = 30,
    padding_left = 0,
    padding_right = 0,
    background = {
        color = colors.bg1,
        border_color = colors.transparent,
        border_width = 1,
        height = 30,
        corner_radius = 15,
    },
})

-- Double border for calendar using a single item bracket
sbar.add("bracket", { cal.name }, {
    background = {
        color = colors.transparent,
        height = 32,
        border_color = colors.transparent,
        border_width = 1,
        corner_radius = 16,
    },
})

-- Padding item required because of bracket
sbar.add("item", { position = "right", width = settings.group_paddings })

cal:subscribe({ "forced", "routine", "system_woke" }, function(env)
    cal:set({ icon = os.date("􀉉  %B %d %a"), label = os.date("􀐫  %H:%M") })
end)
