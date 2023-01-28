{ inputs, pkgs, config, lib, ... }:
let
  inherit (config.home) homeDirectory;
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  home.packages = with pkgs; [
    feh
    libsecret
    slack
    teams
    discord
    zoom-us
    glib
    gimp
    inkscape
    alacritty
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      spotify
      octave
      spotify-tui
      firefox
      brave
      bitwarden
      vlc
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    m-cli # useful macOS CLI commands
  ];

  xdg.configFile."alacritty".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/alacritty";
}
