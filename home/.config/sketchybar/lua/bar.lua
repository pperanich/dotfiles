local colors = require("lua.colors")

-- Equivalent to the --bar domain
sbar.bar({
    height = 36,
    color = colors.transparent,
    display = "all",
    topmost = "window",
    padding_right = 10,
    padding_left = 10,
    margin = 3,
    y_offset = 3,
    corner_radius = 12,
})
