{ pkgs, config, lib, ... }:
{
  home.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "SourceCodePro" "Iosevka" "IBMPlexMono" "Overpass" "FiraMono" "FiraCode" ]; })

    # Add below once the following is closed: https://github.com/NixOS/nixpkgs/issues/270222
    twitter-color-emoji
    sketchybar-app-font
    apple-fonts
  ];

  # required to autoload fonts from packages installed via Home Manager
  fonts.fontconfig.enable = true;
}
