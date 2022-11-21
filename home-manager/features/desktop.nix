{ inputs, pkgs, config, lib, ... }:
{
  home.packages = with pkgs; [
    feh
    libsecret
    firefox
    brave
    slack
    teams
    discord
    zoom-us
    glib
    bitwarden
    vlc
    gimp
    octave
    inkscape
  ] ++ lib.mkIf pkgs.stdenv.hostPlatform.isLinux
    [
      spotify
      spotify-tui
    ];
}
