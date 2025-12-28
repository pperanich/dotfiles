local colors = require("lua.colors")
local icons = require("lua.icons")
local settings = require("lua.settings")

-- Execute the event provider binary which provides the event "cpu_update" for
-- the cpu load data, which is fired every 2.0 seconds.
sbar.exec(
	"killall cpu_load >/dev/null; " .. base_dir .. "/helpers/event_providers/cpu_load/bin/cpu_load cpu_update 2.0"
)

-- CPU widget (magenta border)
local cpu = sbar.add("item", "widgets.cpu", {
	position = "right",
	icon = {
		string = icons.cpu,
		color = colors.magenta,
		padding_left = 12,
		padding_right = 4,
		font = { family = settings.font.text, style = settings.font.style_map["Regular"], size = 17.0 },
	},
	label = {
		string = "--%",
		color = colors.white,
		padding_right = 12,
		font = { family = settings.font.numbers, style = settings.font.style_map["Bold"], size = 14.0 },
	},
	background = {
		color = colors.bg1,
		border_color = colors.magenta,
		border_width = 1,
		height = settings.item.height,
		corner_radius = settings.item.corner_radius,
	},
})

sbar.add("item", { position = "right", width = settings.group_paddings })

cpu:subscribe("cpu_update", function(env)
	local load = tonumber(env.total_load)
	if not load or load < 0 or load > 100 then
		return
	end

	cpu:set({ label = env.total_load .. "%" })
end)

cpu:subscribe("mouse.clicked", function()
	sbar.exec("open -a 'Activity Monitor'")
end)
