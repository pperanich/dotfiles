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
      displayManager.sddm.wayland.enable = true;
      desktopManager.plasma6.enable = true;
    };

    environment.systemPackages = with pkgs; [
      polonium
    ];
  };
}
