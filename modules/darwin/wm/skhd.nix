{ config, lib, pkgs, ... }:

let
  cfg = config.my.darwin.windowManager.skhd;
in
{
  config = lib.mkIf cfg.enable {
    services.skhd = {
      enable = true;
      package = pkgs.skhd;
      skhdConfig = ''
        # Focus window
        alt - h : yabai -m window --focus west
        alt - j : yabai -m window --focus south
        alt - k : yabai -m window --focus north
        alt - l : yabai -m window --focus east

        # Swap window
        shift + alt - h : yabai -m window --swap west
        shift + alt - j : yabai -m window --swap south
        shift + alt - k : yabai -m window --swap north
        shift + alt - l : yabai -m window --swap east

        # Move window
        shift + cmd - h : yabai -m window --warp west
        shift + cmd - j : yabai -m window --warp south
        shift + cmd - k : yabai -m window --warp north
        shift + cmd - l : yabai -m window --warp east

        # Balance size of windows
        shift + alt - 0 : yabai -m space --balance

        # Make window native fullscreen
        alt - f         : yabai -m window --toggle zoom-fullscreen
        shift + alt - f : yabai -m window --toggle native-fullscreen

        # Toggle window split type
        alt - e : yabai -m window --toggle split

        # Float / Unfloat window
        shift + alt - space : yabai -m window --toggle float

        # Restart Yabai
        shift + alt - r : yabai --restart-service
      '';
    };
  };

  # For skhd debugging
  launchd.user.agents.skhd.serviceConfig.StandardErrorPath = "/tmp/skhd.err.log";
  launchd.user.agents.skhd.serviceConfig.StandardOutPath = "/tmp/skhd.out.log";
}
