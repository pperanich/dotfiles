# Desktop environment features
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.home.features.desktop;
in {
  imports = [
    ./fonts.nix
  ];

  options.my.home.features.desktop = {
    enable = lib.mkEnableOption "desktop environment features";

    # Sub-feature toggles
    fonts = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.enable;
        description = "Whether to enable font configuration";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Common desktop packages
    home.packages = with pkgs; [
      # Image viewers and manipulation
      feh
      gimp

      # Document viewers
      zathura
      evince

      # Media players
      vlc
      mpv

      # Screenshots and recording
      flameshot
      # obs-studio
    ];

    # Common desktop settings
  };
}
