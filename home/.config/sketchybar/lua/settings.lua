-- Bar dimensions (change these to resize everything proportionally)
local bar_height = 32
local bar_margin = 4
local bar_y_offset = 4

-- Derived item dimensions
local item_height = bar_height - 2 -- 30
local item_corner_radius = item_height / 2 -- 15 (pill shape)
local bracket_height = bar_height -- 32
local bracket_corner_radius = bracket_height / 2 -- 16
local mode_height = bar_height - 12 -- 20

return {
	paddings = 3,
	group_paddings = 5,

	icons = "sf-symbols", -- alternatively available: NerdFont

	-- This is a font configuration for SF Pro and SF Mono (installed manually/via brew)
	font = require("lua.helpers.default_font"),

	-- Bar settings
	bar = {
		height = bar_height,
		margin = bar_margin,
		y_offset = bar_y_offset,
		corner_radius = bar_height * 0.375, -- 12 for height 32
	},

	-- Item settings (for widgets with pill-shaped backgrounds)
	item = {
		height = item_height,
		corner_radius = item_corner_radius,
	},

	-- Bracket settings (for workspace brackets)
	bracket = {
		height = bracket_height,
		corner_radius = bracket_corner_radius,
	},

	-- Mode indicator settings
	mode = {
		height = mode_height,
		corner_radius = 4,
	},

	-- Alternatively, this is a font config for JetBrainsMono Nerd Font
	-- font = {
	--   text = "JetBrainsMono Nerd Font", -- Used for text
	--   numbers = "JetBrainsMono Nerd Font", -- Used for numbers
	--   style_map = {
	--     ["Regular"] = "Regular",
	--     ["Semibold"] = "Medium",
	--     ["Bold"] = "SemiBold",
	--     ["Heavy"] = "Bold",
	--     ["Black"] = "ExtraBold",
	--   },
	-- },
}
