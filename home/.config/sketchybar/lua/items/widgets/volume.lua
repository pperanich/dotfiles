local colors = require("lua.colors")
local icons = require("lua.icons")
local settings = require("lua.settings")

local popup_width = 250

-- Volume widget (pink border)
local volume = sbar.add("item", "widgets.volume", {
	position = "right",
	icon = {
		string = icons.volume._66,
		color = colors.pink,
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
		border_color = colors.pink,
		border_width = 1,
		height = settings.item.height,
		corner_radius = settings.item.corner_radius,
	},
	popup = { align = "center" },
})

sbar.add("item", { position = "right", width = settings.group_paddings })

local volume_slider = sbar.add("slider", popup_width, {
	position = "popup." .. volume.name,
	slider = {
		highlight_color = colors.pink,
		background = {
			height = 6,
			corner_radius = 3,
			color = colors.bg2,
		},
		knob = {
			string = "􀀁",
			drawing = true,
		},
	},
	background = { color = colors.bg1, height = 2, y_offset = -20 },
	click_script = 'osascript -e "set volume output volume $PERCENTAGE"',
})

-- Get volume icon based on level
local function get_volume_icon(vol)
	if vol >= 66 then
		return icons.volume._100
	elseif vol >= 33 then
		return icons.volume._66
	elseif vol >= 10 then
		return icons.volume._33
	elseif vol > 0 then
		return icons.volume._10
	else
		return icons.volume._0
	end
end

volume:subscribe("volume_change", function(env)
	local vol = tonumber(env.INFO) or 0

	-- Check for headphones/airpods
	sbar.exec("/opt/homebrew/bin/SwitchAudioSource -t output -c", function(result)
		local device = result and result:sub(1, -2) or ""
		local icon
		if device:find("Headphone", 1, true) or device:find("MOMENTUM", 1, true) then
			icon = icons.sound_out.headphones
		elseif device:find("AirPod", 1, true) then
			icon = icons.sound_out.airpods
		else
			icon = get_volume_icon(vol)
		end
		volume:set({ icon = { string = icon } })
	end)

	local label = string.format("%02d%%", vol)
	volume:set({ label = label })
	volume_slider:set({ slider = { percentage = vol } })
end)

local function volume_collapse_details()
	local drawing = volume:query().popup.drawing == "on"
	if not drawing then
		return
	end
	volume:set({ popup = { drawing = false } })
	sbar.remove("/volume.device\\.*/")
end

local function volume_toggle_details(env)
	if env.BUTTON == "right" then
		sbar.exec("open /System/Library/PreferencePanes/Sound.prefpane")
		return
	end

	local should_draw = volume:query().popup.drawing == "off"
	if should_draw then
		volume:set({ popup = { drawing = true } })
		sbar.exec("SwitchAudioSource -t output -c", function(current)
			local current_device = current and current:sub(1, -2) or ""
			sbar.exec("SwitchAudioSource -a -t output", function(available)
				local counter = 0
				for device in string.gmatch(available, "[^\r\n]+") do
					local color = (current_device == device) and colors.white or colors.grey
					sbar.add("item", "volume.device." .. counter, {
						position = "popup." .. volume.name,
						width = popup_width,
						align = "center",
						label = { string = device, color = color },
						click_script = 'SwitchAudioSource -s "'
							.. device
							.. '" && sketchybar --set /volume.device\\.*/ label.color='
							.. string.format("0x%08X", colors.grey)
							.. " --set $NAME label.color="
							.. string.format("0x%08X", colors.white),
					})
					counter = counter + 1
				end
			end)
		end)
	else
		volume_collapse_details()
	end
end

local function volume_scroll(env)
	local delta = env.INFO.delta
	if not (env.INFO.modifier == "ctrl") then
		delta = delta * 10.0
	end
	sbar.exec('osascript -e "set volume output volume (output volume of (get volume settings) + ' .. delta .. ')"')
end

volume:subscribe("mouse.clicked", volume_toggle_details)
volume:subscribe("mouse.exited.global", volume_collapse_details)
volume:subscribe("mouse.scrolled", volume_scroll)
