return {
    black = 0xFF000000,
    white = 0xFFFFFFFF,
    red = 0xFFCE3A5B,
    green = 0xFF638989,
    blue = 0xFF1E6E77,
    yellow = 0xFFCC9B70,
    orange = 0xFFCC7B6E,
    magenta = 0xFFBC76C1,
    pink = 0xFFD7448A,
    grey = 0xFF8A8A8A,
    light_border = 0xFFD3CDC5,
    transparent = 0x00000000,

    bar = {
        bg = 0xEB1e1e2e,
        border = 0x00FFFFFF,
    },

    popup = {
        bg = 0x99121212,
        border = 0xFF24273A,
    },

    bg1 = 0xEB1e1e2e,
    bg2 = 0x00000000,

    with_alpha = function(color, alpha)
        if alpha > 1.0 or alpha < 0.0 then
            return color
        end
        return (color & 0x00FFFFFF) | (math.floor(alpha * 255.0) << 24)
    end,
}
