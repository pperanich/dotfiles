{ inputs, pkgs, config, lib, ... }:
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
    octave
    inkscape
  ];
  # ++ lib.mkIf pkgs.stdenv.hostPlatform.isLinux
  #   [
  #     spotify
  #     spotify-tui
  #     firefox
  #     brave
  #     bitwarden
  #     vlc
  #   ];
}
