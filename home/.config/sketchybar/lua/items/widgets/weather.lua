local colors = require("lua.colors")
local settings = require("lua.settings")

-- Configuration from environment variables
-- WEATHER_LATLON format: "lat,lon" e.g., "37.7749,-122.4194"
local latlon = os.getenv("WEATHER_LATLON")
local update_freq = tonumber(os.getenv("WEATHER_UPDATE_FREQ")) or 1800

-- NWS API requires User-Agent header
local user_agent = "sketchybar-weather/1.0"

-- Store current coordinates for click handler
local current_lat, current_lon = nil, nil

local function open_weather_com()
    if current_lat and current_lon then
        sbar.exec(string.format("open 'https://weather.com/weather/today/l/%s,%s'", current_lat, current_lon))
    else
        sbar.exec("open 'https://weather.com'")
    end
end

-- Weather condition to SF Symbol mapping based on NWS icon keywords
local function get_weather_icon(forecast_short)
    local text = forecast_short:lower()

    if text:match("thunder") or text:match("storm") then
        return "􀇟 "
    elseif text:match("snow") or text:match("blizzard") then
        return "􀇥 "
    elseif text:match("sleet") or text:match("freezing") or text:match("ice") then
        return "􀇑 "
    elseif text:match("rain") or text:match("shower") or text:match("drizzle") then
        return "􀇇 "
    elseif text:match("fog") or text:match("mist") or text:match("haze") then
        return "􀇋 "
    elseif text:match("cloudy") or text:match("overcast") then
        return "􀇃 "
    elseif text:match("partly") then
        return "􀇕 "
    elseif text:match("sunny") or text:match("clear") then
        return "􀆮 "
    else
        return "􀇕 "
    end
end

local weather_high = sbar.add("item", "widgets.weather1", {
    position = "right",
    update_freq = update_freq,
    padding_left = -8,
    width = 0,
    icon = {
        padding_right = 0,
        padding_left = 0,
        font = {
            style = settings.font.style_map["Bold"],
            size = 9.0,
        },
        color = colors.orange,
        string = "􀄨",  -- up arrow
    },
    label = {
        font = {
            family = settings.font.numbers,
            style = settings.font.style_map["Bold"],
            size = 9.0,
        },
        color = colors.orange,
        string = "??°",
    },
    y_offset = 4,
})

local weather_low = sbar.add("item", "widgets.weather2", {
    position = "right",
    padding_left = -8,
    icon = {
        padding_right = 0,
        padding_left = 0,
        font = {
            style = settings.font.style_map["Bold"],
            size = 9.0,
        },
        string = "􀄩",  -- down arrow
        color = colors.blue,
    },
    label = {
        font = {
            family = settings.font.numbers,
            style = settings.font.style_map["Bold"],
            size = 9.0,
        },
        color = colors.blue,
        string = "??°",
    },
    y_offset = -4,
})

local weather_padding = sbar.add("item", "widgets.weather.padding", {
    position = "right",
    label = { drawing = false },
    icon = {
        padding_left = 12,
        padding_right = 12,
    },
})

local weather_current = sbar.add("item", "widgets.weather3", {
    position = "right",
    icon = {
        string = "􀇕 ",
        padding_left = 12,
        padding_right = 0,
        font = {
            style = settings.font.style_map["Regular"],
            size = 17.0,
        },
    },
    label = {
        font = { family = settings.font.numbers },
        string = "??°",
        padding_right = 12,
    },
})

-- Background around the weather items
local weather_bracket = sbar.add("bracket", "widgets.weather.bracket", {
    weather_current.name,
    weather_padding.name,
    weather_high.name,
    weather_low.name,
}, {
    background = {
        color = colors.bg1,
        border_color = colors.transparent,
        border_width = 1,
        height = 30,
        corner_radius = 15,
    },
})

sbar.add("item", { position = "right", width = settings.group_paddings })

-- Function to fetch weather once we have coordinates
local function fetch_weather(lat, lon)
    -- Store coordinates for click handler
    current_lat, current_lon = lat, lon

    weather_current:set({ label = { string = "..." } })

    -- Step 1: Get the grid point info from coordinates
    local points_cmd = string.format(
        "curl -s -A '%s' 'https://api.weather.gov/points/%s,%s'",
        user_agent,
        lat,
        lon
    )

    sbar.exec(points_cmd, function(points_res)
        if not points_res or not points_res.properties or not points_res.properties.forecast then
            weather_current:set({ label = { string = "ERR" }, icon = { string = "⚠️ " } })
            return
        end

        local forecast_url = points_res.properties.forecast

        -- Step 2: Get the forecast
        local forecast_cmd = string.format("curl -s -A '%s' '%s'", user_agent, forecast_url)

        sbar.exec(forecast_cmd, function(forecast_res)
            if not forecast_res or not forecast_res.properties or not forecast_res.properties.periods then
                weather_current:set({ label = { string = "ERR" }, icon = { string = "⚠️ " } })
                return
            end

            local periods = forecast_res.properties.periods
            local current = periods[1]
            local today_high, today_low

            -- Find today's high and low from the periods
            for _, period in ipairs(periods) do
                if period.isDaytime and not today_high then
                    today_high = period.temperature
                elseif not period.isDaytime and not today_low then
                    today_low = period.temperature
                end
                if today_high and today_low then
                    break
                end
            end

            -- Update current temperature and icon
            if current and current.temperature then
                weather_current:set({
                    label = { string = current.temperature .. "°" },
                    icon = { string = get_weather_icon(current.shortForecast or "") },
                })
            end

            -- Update high/low
            if today_high then
                weather_high:set({ label = { string = string.format("%4s", today_high .. "°") } })
            end
            if today_low then
                weather_low:set({ label = { string = string.format("%4s", today_low .. "°") } })
            end
        end)
    end)
end

weather_high:subscribe({ "forced", "routine", "system_woke" }, function(_)
    if latlon and latlon ~= "" then
        -- Use provided coordinates
        local lat, lon = latlon:match("([^,]+),([^,]+)")
        if lat and lon then
            fetch_weather(lat, lon)
        else
            print("[weather] Invalid WEATHER_LATLON format, expected 'lat,lon'")
        end
    else
        -- Auto-detect location via IP geolocation
        sbar.exec("curl -s 'https://ipinfo.io/loc'", function(loc)
            if loc and loc ~= "" then
                local lat, lon = loc:match("([^,]+),([^,]+)")
                if lat and lon then
                    fetch_weather(lat:gsub("%s+", ""), lon:gsub("%s+", ""))
                end
            else
                print("[weather] Could not auto-detect location")
                weather_current:set({ label = { string = "ERR" }, icon = { string = "⚠️ " } })
            end
        end)
    end
end)

-- Click handlers to open weather.com
weather_current:subscribe("mouse.clicked", open_weather_com)
weather_high:subscribe("mouse.clicked", open_weather_com)
weather_low:subscribe("mouse.clicked", open_weather_com)
weather_padding:subscribe("mouse.clicked", open_weather_com)
