{ inputs, pkgs, config, lib, ... }:
let
  inherit (config.lib.meta) mkMutableSymlink;
in
{
  home.packages = with pkgs; [ ];

  xdg.configFile = {
    "spacebar".source = mkMutableSymlink "spacebar";
    "sketchybar".source = mkMutableSymlink "sketchybar";
    "yabai".source = mkMutableSymlink "yabai";
    "skhd".source = mkMutableSymlink "skhd";
  };
}
