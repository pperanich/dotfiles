local colors = require("lua.colors")
local icons = require("lua.icons")
local settings = require("lua.settings")

-- Battery widget (red border)
local battery = sbar.add("item", "widgets.battery", {
	position = "right",
	icon = {
		string = icons.battery._100,
		color = colors.red,
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
	update_freq = 60,
	popup = { align = "center" },
	background = {
		color = colors.bg1,
		border_color = colors.red,
		border_width = 1,
		height = settings.item.height,
		corner_radius = settings.item.corner_radius,
	},
})

sbar.add("item", { position = "right", width = settings.group_paddings })

local remaining_time = sbar.add("item", {
	position = "popup." .. battery.name,
	icon = {
		string = "Time remaining:",
		width = 100,
		align = "left",
	},
	label = {
		string = "??:??h",
		width = 100,
		align = "right",
	},
})

battery:subscribe({ "routine", "power_source_change", "system_woke" }, function()
	sbar.exec("pmset -g batt", function(batt_info)
		local icon = icons.battery._100
		local label = "?%"

		local found, _, charge = batt_info:find("(%d+)%%")
		if found then
			charge = tonumber(charge)
			label = charge .. "%"
		end

		local charging = batt_info:find("AC Power")

		-- Select icon based on charge level
		if charging then
			icon = icons.battery.charging
		elseif found and charge > 80 then
			icon = icons.battery._100
		elseif found and charge > 60 then
			icon = icons.battery._75
		elseif found and charge > 40 then
			icon = icons.battery._50
		elseif found and charge > 20 then
			icon = icons.battery._25
		else
			icon = icons.battery._0
		end

		battery:set({
			icon = { string = icon },
			label = label,
		})
	end)
end)

battery:subscribe("mouse.clicked", function()
	local drawing = battery:query().popup.drawing
	battery:set({ popup = { drawing = "toggle" } })

	if drawing == "off" then
		sbar.exec("pmset -g batt", function(batt_info)
			local found, _, remaining = batt_info:find(" (%d+:%d+) remaining")
			local label = found and remaining .. "h" or "No estimate"
			remaining_time:set({ label = label })
		end)
	end
end)
