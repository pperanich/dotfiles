local colors = require("lua.colors")
local settings = require("lua.settings")
local profile = require("lua.profile")

if profile == "pill" then
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
else
	-- i3 profile: flat, edge-to-edge, bottom-positioned
	sbar.bar({
		position = "bottom",
		height = settings.bar.height,
		color = colors.base,
		display = "all",
		topmost = "window",
		padding_right = 0,
		padding_left = 0,
		margin = 0,
		y_offset = 0,
		corner_radius = 0,
	})
end
