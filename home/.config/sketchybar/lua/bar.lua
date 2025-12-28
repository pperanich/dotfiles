local colors = require("lua.colors")
local settings = require("lua.settings")

-- Equivalent to the --bar domain
sbar.bar({
	height = settings.bar.height,
	color = colors.transparent,
	display = "all",
	topmost = "window",
	padding_right = 10,
	padding_left = 10,
	margin = settings.bar.margin,
	y_offset = settings.bar.y_offset,
	corner_radius = settings.bar.corner_radius,
})
