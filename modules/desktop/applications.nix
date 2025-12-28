# Desktop applications configuration
_: {
  flake.modules.homeManager.desktopApplications =
    {
      lib,
      pkgs,
      ...
    }:
    {
      # Common desktop packages
      home.packages =
        with pkgs;
        [
          feh # Fast image viewer
          libsecret # Secret service API library
          glib # Low-level core library for GNOME
          inkscape # Vector graphics editor
          alacritty # GPU-accelerated terminal emulator
          brave # Privacy-focused web browser
          wireshark # Network protocol analyzer
          discord # Chat and voice communication
          # reaper        # Digital audio workstation
          # vlc # Media player
          # postman
          # kicad
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          # zoom-us # Video conferencing
          # hdfview
          firefox # Web browser
          bitwarden-desktop # Password manager
          vlc # Media player
          protonvpn-gui # VPN client
          ghostty # Fast, native, feature-rich terminal emulator pushing modern features
          gimp # GNU Image Manipulation Program
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
          # logseq # Knowledge management tool
          m-cli # useful macOS CLI commands
          ollama # Local LLM runner
          ghostty-bin # Fast, native, feature-rich terminal emulator pushing modern features
          # nixcasks.docker # Container platform
          # nixcasks.ghostty # Fast, native, feature-rich terminal emulator pushing modern features
          # nixcasks.shottr # Screenshot tool
          # nixcasks.tailscale
          # nixcasks.moonlight # Game streaming client
          # docker-desktop
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
          slack # Team communication platform
        ]
        ++ lib.optionals (!(pkgs.stdenv.hostPlatform.isAarch64 && pkgs.stdenv.hostPlatform.isLinux)) [
          zotero # Reference manager
          # spotify # Music streaming client
        ];
    };
}
