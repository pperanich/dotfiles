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
        lib.optionals pkgs.stdenv.hostPlatform.isLinux [
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
          # zoom-us # Video conferencing
          # hdfview
          firefox # Web browser
          bitwarden-desktop # Password manager
          vlc # Media player
          protonvpn-gui # VPN client
          ghostty # Fast, native, feature-rich terminal emulator pushing modern features
          gimp # GNU Image Manipulation Program
        ];
    };
}
