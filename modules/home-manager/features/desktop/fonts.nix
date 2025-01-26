# Desktop fonts configuration
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.home.features.desktop;
in {
  config = lib.mkIf (cfg.enable && cfg.fonts.enable) {
    home.packages = with pkgs; [
      nerd-fonts.sauce-code-pro
      nerd-fonts.iosevka
      nerd-fonts.im-writing
      nerd-fonts.overpass
      nerd-fonts.fira-mono
      nerd-fonts.fira-code
      # Add below once the following is closed: https://github.com/NixOS/nixpkgs/issues/270222
      twitter-color-emoji
      sketchybar-app-font
      apple-fonts.sf-pro
      apple-fonts.sf-compact
      apple-fonts.sf-mono
      apple-fonts.sf-arabic
      apple-fonts.ny
    ];

    # required to autoload fonts from packages installed via Home Manager
    fonts.fontconfig.enable = true;
  };
}
