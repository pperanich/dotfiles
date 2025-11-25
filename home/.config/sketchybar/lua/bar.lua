local colors = require("lua.colors")

-- Equivalent to the --bar domain
sbar.bar({
	height = 32,
	color = colors.transparent,
	display = "all",
	topmost = "window",
	padding_right = 10,
	padding_left = 10,
	margin = 4,
	y_offset = 4,
	corner_radius = 12,
})
