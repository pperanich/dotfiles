{ config, lib, pkgs, ... }:

let
  cfg = config.my.darwin.windowManager.yabai;
in
{
  config = lib.mkIf cfg.enable {
    services.yabai = {
      enable = true;
      package = pkgs.yabai;
      enableScriptingAddition = true;
      config = {
        # Layout
        layout = "bsp";
        auto_balance = "on";
        split_ratio = 0.50;
        window_placement = "second_child";

        # Padding
        top_padding = 12;
        bottom_padding = 12;
        left_padding = 12;
        right_padding = 12;
        window_gap = 12;

        # Mouse
        mouse_follows_focus = "on";
        focus_follows_mouse = "autoraise";
        mouse_modifier = "fn";
        mouse_action1 = "move";
        mouse_action2 = "resize";

        # Window modifications
        window_topmost = "on";
        window_shadow = "float";
        window_opacity = "off";
        active_window_opacity = 1.0;
        normal_window_opacity = 0.9;

        # Rules
        window_rules = [
          "app='System Settings' manage=off"
          "app='Calculator' manage=off"
          "app='Software Update' manage=off"
          "app='System Information' manage=off"
        ];
      };

      extraConfig = ''
        # Rules
        yabai -m rule --add app="^System Settings$" manage=off
        yabai -m rule --add app="^Calculator$" manage=off
        yabai -m rule --add app="^Software Update$" manage=off
        yabai -m rule --add app="^System Information$" manage=off
      '';
    };
  };

  # For yabai debugging
  launchd.user.agents.yabai.serviceConfig.StandardErrorPath = "/tmp/yabai.err.log";
  launchd.user.agents.yabai.serviceConfig.StandardOutPath = "/tmp/yabai.out.log";
}
