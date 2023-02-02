{ pkgs, lib, inputs, outputs, config, ...}:
{
  services = {
    yabai = {
      enable = true;
      enableScriptingAddition = false;
      package = pkgs.yabai;
      config = {
        mouse_follows_focus = "off";
        focus_follows_mouse = "autofocus";
        window_placement = "second_child";
        window_topmost = "off";
        window_opacity = "off";
        window_opacity_duration = 0.0;
        window_shadow = "on";
        active_window_opacity = 1.0;
        normal_window_opacity = 0.90;
        split_ratio = 0.50;
        auto_balance = "off";
        active_window_border_color = "0xff775759";
        normal_window_border_color = "0xff555555";
        # Mouse support;
        mouse_modifier = "alt";
        mouse_action_1 = "move";
        mouse_action_2 = "resize";
        # general space settings;
        layout = "bsp";
        bottom_padding = 0;
        left_padding = 0;
        right_padding = 0;
        window_gap = 0;
        # spacebar padding on top screen
        # external_bar = "all:26:0";
      };
      extraConfig = ''
        # float system preferences
        yabai -m rule --add app='^System Information$' manage=off
        yabai -m rule --add app='^System Preferences$' manage=off
        yabai -m rule --add title='Preferences$' manage=off
        # float settings windows
        yabai -m rule --add title='Settings$' manage=off
      '';
    };
  };

  # For yabai debugging
  launchd.user.agents.yabai.serviceConfig.StandardErrorPath = "/tmp/yabai.err.log";
  launchd.user.agents.yabai.serviceConfig.StandardOutPath = "/tmp/yabai.out.log";
}
