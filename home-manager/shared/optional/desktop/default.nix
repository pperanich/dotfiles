{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (config.home) homeDirectory;
in {
  imports = [
    ./fonts.nix
  ];
  home = {
    sessionVariables = {
      TERMINFO_DIRS = "${pkgs.alacritty.terminfo.outPath}/share/terminfo:${pkgs.wezterm.terminfo.outPath}/share/terminfo;";
    };
    packages = with pkgs;
      [
        feh # Fast image viewer
        libsecret # Secret service API library
        glib # Low-level core library for GNOME
        gimp # GNU Image Manipulation Program
        inkscape # Vector graphics editor
        alacritty # GPU-accelerated terminal emulator
        zotero # Reference manager
        spotify # Music streaming client
        # spotify-tui
        brave # Privacy-focused web browser
        wireshark # Network protocol analyzer
        # reaper        # Digital audio workstation
        vlc # Media player
        # postman
        # kicad
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        zoom-us # Video conferencing
        # hdfview
        firefox # Web browser
        bitwarden # Password manager
        vlc # Media player
        protonvpn-gui # VPN client
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        logseq # Knowledge management tool
        m-cli # useful macOS CLI commands
        ollama # Local LLM runner
        nixcasks.docker # Container platform
        nixcasks.shottr # Screenshot tool
        # nixcasks.tailscale
        nixcasks.moonlight # Game streaming client
        # docker-desktop
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
        discord # Chat and voice communication
        slack # Team communication platform
      ];
    sessionPath = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin ["${homeDirectory}/.docker/bin"];
  };
}
