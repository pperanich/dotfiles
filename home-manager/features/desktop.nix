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
    zoom-us
    glib
    gimp
    inkscape
    alacritty
    hdfview
    zotero
    spotify
    spotify-tui
    # brave
    wireshark
    reaper
    # protonvpn-gui
    vlc
    # postman
    # kicad
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    firefox
    bitwarden
    vlc
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    # logseq
    teams
    m-cli # useful macOS CLI commands
    ollama
    # shottr
    # docker-desktop
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
    discord
    slack
  ];

  xdg.configFile."alacritty".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/alacritty";
  home.sessionPath = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin [ "${homeDirectory}/.docker/bin" ];
}

