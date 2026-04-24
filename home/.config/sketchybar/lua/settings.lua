local profile = require("lua.profile")

local common = {
	icons = "sf-symbols",
	font = require("lua.helpers.default_font"),
}

if profile == "pill" then
	local bar_height = 32
	local bar_margin = 4
	local bar_y_offset = 4
	local item_height = bar_height - 2
	local item_corner_radius = item_height / 2
	local bracket_height = bar_height
	local bracket_corner_radius = bracket_height / 2
	local mode_height = bar_height - 12

	return {
		icons = common.icons,
		font = common.font,
		paddings = 3,
		group_paddings = 5,
		bar = {
			height = bar_height,
			margin = bar_margin,
			y_offset = bar_y_offset,
			corner_radius = bar_height * 0.375,
		},
		item = {
			height = item_height,
			corner_radius = item_corner_radius,
		},
		bracket = {
			height = bracket_height,
			corner_radius = bracket_corner_radius,
		},
		mode = {
			height = mode_height,
			corner_radius = 4,
		},
	}
end

-- i3 profile (default)
local bar_height = 24
local bar_margin = 0
local bar_y_offset = 0

return {
	icons = common.icons,
	font = common.font,
	paddings = 2,
	group_paddings = 0,
	bar = {
		height = bar_height,
		margin = bar_margin,
		y_offset = bar_y_offset,
		corner_radius = 0,
	},
	item = {
		height = bar_height,
		corner_radius = 0,
	},
	bracket = {
		height = bar_height,
		corner_radius = 0,
	},
	mode = {
		height = bar_height - 6,
		corner_radius = 0,
	},
}
