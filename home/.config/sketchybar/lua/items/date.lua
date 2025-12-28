local colors = require("lua.colors")
local settings = require("lua.settings")

-- Date widget (green border)
local date = sbar.add("item", "widgets.date", {
	icon = {
		string = "􀉉", -- calendar
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
		height = settings.item.height,
		corner_radius = settings.item.corner_radius,
	},
})

sbar.add("item", { position = "right", width = settings.group_paddings })

date:subscribe({ "forced", "routine", "system_woke" }, function()
	date:set({ label = os.date("%a %b %d") })
end)

date:subscribe("mouse.clicked", function()
	sbar.exec("open -a Calendar")
end)
