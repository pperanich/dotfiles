-- Catppuccin Mocha palette
return {
    -- Base colors (mapped to Catppuccin)
    black = 0xFF11111b,      -- crust
    white = 0xFFcdd6f4,      -- text
    red = 0xFFf38ba8,        -- red
    green = 0xFFa6e3a1,      -- green
    blue = 0xFF89b4fa,       -- blue
    yellow = 0xFFf9e2af,     -- yellow
    orange = 0xFFfab387,     -- peach
    magenta = 0xFFcba6f7,    -- mauve
    pink = 0xFFf5c2e7,       -- pink
    grey = 0xFF6c7086,       -- overlay0
    light_border = 0xFFb4befe, -- lavender
    transparent = 0x00000000,

    -- Extended Catppuccin Mocha palette
    rosewater = 0xFFf5e0dc,
    flamingo = 0xFFf2cdcd,
    mauve = 0xFFcba6f7,
    maroon = 0xFFeba0ac,
    peach = 0xFFfab387,
    teal = 0xFF94e2d5,
    sky = 0xFF89dceb,
    sapphire = 0xFF74c7ec,
    lavender = 0xFFb4befe,
    text = 0xFFcdd6f4,
    subtext1 = 0xFFbac2de,
    subtext0 = 0xFFa6adc8,
    overlay2 = 0xFF9399b2,
    overlay1 = 0xFF7f849c,
    overlay0 = 0xFF6c7086,
    surface2 = 0xFF585b70,
    surface1 = 0xFF45475a,
    surface0 = 0xFF313244,
    base = 0xFF1e1e2e,
    mantle = 0xFF181825,
    crust = 0xFF11111b,

    bar = {
        bg = 0xEB1e1e2e,     -- base with alpha
        border = 0x00000000,
    },

    popup = {
        bg = 0xE6181825,     -- mantle with alpha
        border = 0xFF313244, -- surface0
    },

    bg1 = 0xEB1e1e2e,        -- base with alpha
    bg2 = 0xFF313244,        -- surface0

    with_alpha = function(color, alpha)
        if alpha > 1.0 or alpha < 0.0 then
            return color
        end
        return (color & 0x00FFFFFF) | (math.floor(alpha * 255.0) << 24)
    end,
}
