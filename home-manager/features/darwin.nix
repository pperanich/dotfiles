{ inputs, pkgs, config, lib, ... }:
let
  inherit (config.home) homeDirectory;
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  home.packages = with pkgs; [];

  xdg.configFile."spacebar".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/spacebar";
  xdg.configFile."sketchybar".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/sketchybar";
  xdg.configFile."yabai".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/yabai";
  xdg.configFile."skhd".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/skhd";
}
