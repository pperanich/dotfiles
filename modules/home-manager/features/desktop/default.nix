# Desktop environment features
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.home.features.desktop;
in {
  imports = [
    ./fonts.nix
  ];

  options.my.home.features.desktop = {
    enable = lib.mkEnableOption "desktop environment features";

    # Sub-feature toggles
    fonts = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.enable;
        description = "Whether to enable font configuration";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Common desktop packages
    home.packages = with pkgs;
      [
        feh # Fast image viewer
        libsecret # Secret service API library
        glib # Low-level core library for GNOME
        gimp # GNU Image Manipulation Program
        inkscape # Vector graphics editor
        alacritty # GPU-accelerated terminal emulator
        brave # Privacy-focused web browser
        wireshark # Network protocol analyzer
        # reaper        # Digital audio workstation
        # vlc # Media player
        # postman
        # kicad
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        # zoom-us # Video conferencing
        # hdfview
        firefox # Web browser
        bitwarden # Password manager
        vlc # Media player
        protonvpn-gui # VPN client
        ghostty # Fast, native, feature-rich terminal emulator pushing modern features
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        # logseq # Knowledge management tool
        m-cli # useful macOS CLI commands
        ollama # Local LLM runner
        nixcasks.docker # Container platform
        nixcasks.ghostty # Fast, native, feature-rich terminal emulator pushing modern features
        nixcasks.shottr # Screenshot tool
        # nixcasks.tailscale
        nixcasks.moonlight # Game streaming client
        # docker-desktop
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
        discord # Chat and voice communication
        slack # Team communication platform
      ]
      ++ lib.optionals (!(pkgs.stdenv.hostPlatform.isAarch64 && pkgs.stdenv.hostPlatform.isLinux)) [
        zotero # Reference manager
        spotify # Music streaming client
      ];
  };
}
