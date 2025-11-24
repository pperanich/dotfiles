local colors = require("lua.colors")
local settings = require("lua.settings")

-- Time widget (blue border)
local time = sbar.add("item", "widgets.time", {
    icon = {
        string = "􀐫",  -- clock.fill
        color = colors.blue,
        padding_left = 12,
        padding_right = 4,
        font = { family = settings.font.text, style = settings.font.style_map["Regular"], size = 17.0 },
    },
    label = {
        color = colors.white,
        padding_right = 12,
        font = { family = settings.font.numbers, style = settings.font.style_map["Bold"], size = 14.0 },
    },
    position = "right",
    update_freq = 1,
    background = {
        color = colors.bg1,
        border_color = colors.blue,
        border_width = 1,
        height = 30,
        corner_radius = 15,
    },
})

sbar.add("item", { position = "right", width = settings.group_paddings })

-- Date widget (green border)
local date = sbar.add("item", "widgets.date", {
    icon = {
        string = "􀉉",  -- calendar
        color = colors.green,
        padding_left = 12,
        padding_right = 4,
        font = { family = settings.font.text, style = settings.font.style_map["Regular"], size = 17.0 },
    },
    label = {
        color = colors.white,
        padding_right = 12,
        font = { family = settings.font.text, style = settings.font.style_map["Bold"], size = 14.0 },
    },
    position = "right",
    update_freq = 60,
    background = {
        color = colors.bg1,
        border_color = colors.green,
        border_width = 1,
        height = 30,
        corner_radius = 15,
    },
})

sbar.add("item", { position = "right", width = settings.group_paddings })

-- Update handlers
time:subscribe({ "forced", "routine", "system_woke" }, function()
    time:set({ label = os.date("%I:%M %p") })
end)

date:subscribe({ "forced", "routine", "system_woke" }, function()
    date:set({ label = os.date("%a %b %d") })
end)

-- Click to open Calendar app
time:subscribe("mouse.clicked", function()
    sbar.exec("open -a Calendar")
end)

date:subscribe("mouse.clicked", function()
    sbar.exec("open -a Calendar")
end)
