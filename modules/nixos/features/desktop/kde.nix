{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.my.desktop.kde;
in {
  options.my.desktop.kde = {
    enable = mkEnableOption "Enable KDE Plasma desktop environment";
  };

  config = mkIf cfg.enable {
    # Enable the KDE Plasma desktop environment
    services = {
      xserver.enable = true;
      displayManager.sddm.enable = true;
      desktopManager.plasma6.enable = true;
    };

    # Install KDE applications and utilities
    environment.systemPackages = with pkgs; [
      # KDE applications
      # kate
      # konsole
      # dolphin
      # ark
      # okular
      # gwenview
      # plasma-browser-integration
      #
      # # KDE utilities
      # kdeconnect
      # kdeplasma-addons
      # plasma-nm
      # plasma-pa
      #
      # # Additional utilities
      # kdeFrameworks.kconfig
      # kdeFrameworks.kcmutils
    ];

    # Enable Qt platform integration
    # qt.platformTheme = "kde";
  };
}
