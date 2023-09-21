{ pkgs, config, lib, ... }:
{
  home.packages = [
    (pkgs.nerdfonts.override { fonts = [ "SourceCodePro" "Iosevka" "IBMPlexMono" "Overpass" "FiraMono" "FiraCode"]; })
  ];

  # required to autoload fonts from packages installed via Home Manager
  fonts.fontconfig.enable = true;
}
