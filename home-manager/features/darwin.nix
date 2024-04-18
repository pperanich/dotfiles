{ inputs, pkgs, config, lib, ... }:
let
  inherit (config.home) homeDirectory;
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  home.packages = with pkgs; [ ];

  xdg.configFile = {
    "spacebar".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/spacebar";
    "sketchybar".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/sketchybar";
    "yabai".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/yabai";
    "skhd".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/skhd";
  };
}
