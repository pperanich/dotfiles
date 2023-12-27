{ inputs, pkgs, config, lib, ... }:
let
  inherit (config.home) homeDirectory;
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  home.sessionVariables = {
    TERMINFO_DIRS = "${pkgs.alacritty.terminfo.outPath}/share/terminfo:${pkgs.wezterm.terminfo.outPath}/share/terminfo;";
  };
  home.packages = with pkgs; [
    feh
    libsecret
    slack
    discord
    zoom-us
    glib
    gimp
    inkscape
    alacritty
    logseq
    hdfview
    zotero
    spotify
    spotify-tui
    brave
    wireshark
    reaper
    protonvpn-gui
    vlc
    # postman
    # kicad
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    firefox
    bitwarden
    vlc
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    teams
    m-cli # useful macOS CLI commands
    shottr
    docker-desktop
  ];

  xdg.configFile."alacritty".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/alacritty";
}

