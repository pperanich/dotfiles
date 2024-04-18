{ inputs, pkgs, config, lib, ... }:
let
  inherit (config.home) homeDirectory;
  inherit (config.lib.meta) mkMutableSymlink;
in
{
  home = {
    sessionVariables = {
      TERMINFO_DIRS = "${pkgs.alacritty.terminfo.outPath}/share/terminfo:${pkgs.wezterm.terminfo.outPath}/share/terminfo;";
    };
    packages = with pkgs; [
      feh
      libsecret
      zoom-us
      glib
      gimp
      inkscape
      alacritty
      zotero
      spotify
      # spotify-tui
      brave
      wireshark
      reaper
      vlc
      # postman
      # kicad
    ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      hdfview
      firefox
      bitwarden
      vlc
      protonvpn-gui
    ] ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
      logseq
      teams
      m-cli # useful macOS CLI commands
      ollama
      nixcasks.docker
      nixcasks.shottr
      nixcasks.tailscale
      nixcasks.moonlight
      # docker-desktop
    ] ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
      discord
      slack
    ];
    sessionPath = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin [ "${homeDirectory}/.docker/bin" ];
  };

  xdg.configFile."alacritty".source = mkMutableSymlink "alacritty";
}

