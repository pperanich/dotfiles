local colors = require("lua.colors")
local settings = require("lua.settings")

-- Configuration from environment variables
local latlon = os.getenv("WEATHER_LATLON")
local update_freq = tonumber(os.getenv("WEATHER_UPDATE_FREQ")) or 900  -- 15 minutes

-- NWS API requires User-Agent header
local user_agent = "sketchybar-weather/1.0"

-- Store current coordinates for click handler
local current_lat, current_lon = nil, nil

-- Weather condition to SF Symbol mapping
local function get_weather_icon(forecast_short)
    local text = forecast_short:lower()

    if text:match("thunder") or text:match("storm") then
        return "􀇟"  -- cloud.bolt.fill
    elseif text:match("snow") or text:match("blizzard") then
        return "􀇥"  -- cloud.snow.fill
    elseif text:match("sleet") or text:match("freezing") or text:match("ice") then
        return "􀇑"  -- cloud.sleet.fill
    elseif text:match("rain") or text:match("shower") or text:match("drizzle") then
        return "􀇇"  -- cloud.rain.fill
    elseif text:match("fog") or text:match("mist") or text:match("haze") then
        return "􀇋"  -- cloud.fog.fill
    elseif text:match("cloudy") or text:match("overcast") then
        return "􀇃"  -- cloud.fill
    elseif text:match("partly") then
        return "􀇕"  -- cloud.sun.fill
    elseif text:match("sunny") or text:match("clear") then
        return "􀆮"  -- sun.max.fill
    else
        return "􀇕"  -- cloud.sun.fill (default)
    end
end

-- Weather widget (orange border)
local weather = sbar.add("item", "widgets.weather", {
    position = "right",
    update_freq = update_freq,
    icon = {
        string = "􀇕",
        color = colors.orange,
        padding_left = 12,
        padding_right = 4,
        font = { family = settings.font.text, style = settings.font.style_map["Regular"], size = 17.0 },
    },
    label = {
        string = "--°F",
        color = colors.white,
        padding_right = 12,
        font = { family = settings.font.numbers, style = settings.font.style_map["Bold"], size = 14.0 },
    },
    background = {
        color = colors.bg1,
        border_color = colors.orange,
        border_width = 1,
        height = 30,
        corner_radius = 15,
    },
})

sbar.add("item", { position = "right", width = settings.group_paddings })

-- Function to fetch weather once we have coordinates
local function fetch_weather(lat, lon)
    current_lat, current_lon = lat, lon

    local points_cmd = string.format(
        "curl -sk -A '%s' 'https://api.weather.gov/points/%s,%s'",
        user_agent,
        lat,
        lon
    )

    sbar.exec(points_cmd, function(points_res)
        if not points_res or not points_res.properties or not points_res.properties.forecastHourly then
            weather:set({ label = "ERR" })
            return
        end

        -- Use hourly forecast for more accurate current temperature
        local forecast_url = points_res.properties.forecastHourly
        local forecast_cmd = string.format("curl -sk -A '%s' '%s'", user_agent, forecast_url)

        sbar.exec(forecast_cmd, function(forecast_res)
            if not forecast_res or not forecast_res.properties or not forecast_res.properties.periods then
                weather:set({ label = "ERR" })
                return
            end

            local current = forecast_res.properties.periods[1]
            if current and current.temperature then
                weather:set({
                    icon = { string = get_weather_icon(current.shortForecast or "") },
                    label = current.temperature .. "°F",
                })
            end
        end)
    end)
end

weather:subscribe({ "forced", "routine", "system_woke" }, function()
    if latlon and latlon ~= "" then
        local lat, lon = latlon:match("([^,]+),([^,]+)")
        if lat and lon then
            fetch_weather(lat, lon)
        end
    else
        sbar.exec("curl -sk 'https://ipinfo.io/loc'", function(loc)
            if loc and loc ~= "" then
                local lat, lon = loc:match("([^,]+),([^,]+)")
                if lat and lon then
                    fetch_weather(lat:gsub("%s+", ""), lon:gsub("%s+", ""))
                end
            end
        end)
    end
end)

-- Click to open weather.com
weather:subscribe("mouse.clicked", function()
    if current_lat and current_lon then
        sbar.exec(string.format("open 'https://weather.com/weather/today/l/%s,%s'", current_lat, current_lon))
    else
        sbar.exec("open 'https://weather.com'")
    end
end)
