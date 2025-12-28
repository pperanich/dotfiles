local colors = require("lua.colors")
local settings = require("lua.settings")

-- Time widget (blue border)
local time = sbar.add("item", "widgets.time", {
	icon = {
		string = "􀐫", -- clock.fill
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
		height = settings.item.height,
		corner_radius = settings.item.corner_radius,
	},
})

sbar.add("item", { position = "right", width = settings.group_paddings })

time:subscribe({ "forced", "routine", "system_woke" }, function()
	time:set({ label = os.date("%I:%M %p") })
end)

time:subscribe("mouse.clicked", function()
	sbar.exec("open -a Calendar")
end)
