local colors = require("lua.colors")
local icons = require("lua.icons")
local settings = require("lua.settings")

local popup_width = 250

-- WiFi widget (yellow border)
local wifi = sbar.add("item", "widgets.wifi", {
    position = "right",
    update_freq = 10,
    icon = {
        string = icons.wifi.disconnected,
        color = colors.yellow,
        padding_left = 12,
        padding_right = 4,
        font = { family = settings.font.text, style = settings.font.style_map["Regular"], size = 17.0 },
    },
    label = {
        string = "Off",
        color = colors.white,
        padding_right = 12,
        font = { family = settings.font.text, style = settings.font.style_map["Bold"], size = 14.0 },
    },
    background = {
        color = colors.bg1,
        border_color = colors.yellow,
        border_width = 1,
        height = 30,
        corner_radius = 15,
    },
    popup = { align = "center", height = 30 },
})

sbar.add("item", { position = "right", width = settings.group_paddings })

-- Popup items
local ssid = sbar.add("item", {
    position = "popup." .. wifi.name,
    icon = {
        font = { style = settings.font.style_map["Bold"] },
        string = icons.wifi.router,
    },
    width = popup_width,
    align = "center",
    label = {
        font = { size = 15, style = settings.font.style_map["Bold"] },
        max_chars = 18,
        string = "????????????",
    },
    background = {
        height = 2,
        color = colors.grey,
        y_offset = -15,
    },
})

local hostname = sbar.add("item", {
    position = "popup." .. wifi.name,
    icon = {
        align = "left",
        string = "Hostname:",
        width = popup_width / 2,
    },
    label = {
        max_chars = 20,
        string = "????????????",
        width = popup_width / 2,
        align = "right",
    },
})

local ip = sbar.add("item", {
    position = "popup." .. wifi.name,
    icon = {
        align = "left",
        string = "IP:",
        width = popup_width / 2,
    },
    label = {
        string = "???.???.???.???",
        width = popup_width / 2,
        align = "right",
    },
})

local mask = sbar.add("item", {
    position = "popup." .. wifi.name,
    icon = {
        align = "left",
        string = "Subnet mask:",
        width = popup_width / 2,
    },
    label = {
        string = "???.???.???.???",
        width = popup_width / 2,
        align = "right",
    },
})

local router = sbar.add("item", {
    position = "popup." .. wifi.name,
    icon = {
        align = "left",
        string = "Router:",
        width = popup_width / 2,
    },
    label = {
        string = "???.???.???.???",
        width = popup_width / 2,
        align = "right",
    },
})

-- Update WiFi and VPN status
local function update_wifi_status()
    -- Check for VPN by looking for utun interfaces with UP flag and private IP
    -- UP flag = 0x1, so flags like 8051 have UP, 8050 does not
    sbar.exec("ifconfig | grep -A1 'utun.*<UP,' | grep -E 'inet (10\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.|192\\.168\\.)' | head -1", function(vpn_ip)
        local has_vpn = vpn_ip and vpn_ip ~= ""

        -- Check WiFi connection
        sbar.exec("ipconfig getifaddr en0", function(ip_result)
            local connected = ip_result and ip_result ~= ""

            if has_vpn and connected then
                wifi:set({
                    icon = { string = "􀎡" },  -- lock.shield.fill
                    label = "VPN",
                })
            elseif connected then
                wifi:set({
                    icon = { string = icons.wifi.connected },
                    label = "On",
                })
            else
                wifi:set({
                    icon = { string = icons.wifi.disconnected },
                    label = "Off",
                })
            end
        end)
    end)
end

wifi:subscribe({ "wifi_change", "system_woke", "routine", "forced" }, update_wifi_status)

local function hide_details()
    wifi:set({ popup = { drawing = false } })
end

local function toggle_details()
    local should_draw = wifi:query().popup.drawing == "off"
    if should_draw then
        wifi:set({ popup = { drawing = true } })
        sbar.exec("networksetup -getcomputername", function(result)
            hostname:set({ label = result })
        end)
        sbar.exec("ipconfig getifaddr en0", function(result)
            ip:set({ label = result })
        end)
        sbar.exec("ipconfig getsummary en0 | awk -F ' SSID : '  '/ SSID : / {print $2}'", function(result)
            if result and result:match("redacted") then
                ssid:set({ label = "Run: sudo ipconfig setverbose 1" })
            else
                ssid:set({ label = result })
            end
        end)
        sbar.exec("networksetup -getinfo Wi-Fi | awk -F 'Subnet mask: ' '/^Subnet mask: / {print $2}'", function(result)
            mask:set({ label = result })
        end)
        sbar.exec("networksetup -getinfo Wi-Fi | awk -F 'Router: ' '/^Router: / {print $2}'", function(result)
            router:set({ label = result })
        end)
    else
        hide_details()
    end
end

wifi:subscribe("mouse.clicked", toggle_details)
wifi:subscribe("mouse.exited.global", hide_details)

local function copy_label_to_clipboard(env)
    local label = sbar.query(env.NAME).label.value
    sbar.exec('echo "' .. label .. '" | pbcopy')
    sbar.set(env.NAME, { label = { string = icons.clipboard, align = "center" } })
    sbar.delay(1, function()
        sbar.set(env.NAME, { label = { string = label, align = "right" } })
    end)
end

ssid:subscribe("mouse.clicked", copy_label_to_clipboard)
hostname:subscribe("mouse.clicked", copy_label_to_clipboard)
ip:subscribe("mouse.clicked", copy_label_to_clipboard)
mask:subscribe("mouse.clicked", copy_label_to_clipboard)
router:subscribe("mouse.clicked", copy_label_to_clipboard)
