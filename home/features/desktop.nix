{ inputes, pkgs, config, lib, ... }:
{
  home.packages = with pkgs; [
    feh
    libsecret
    firefox
    slack
    teams
    discord
    zoom-us
    glib
    bitwarden
    spotify
    vlc
    gimp
  ];
}
