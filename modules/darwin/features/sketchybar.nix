{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.features.sketchybar;
in {
  options.my.features.sketchybar = {
    enable = lib.mkEnableOption "Sketchy Bar status bar.";
  };

  config = lib.mkIf cfg.enable {
    services = {
      sketchybar = {
        enable = true;
        package = pkgs.sketchybar;
      };
    };

    environment.systemPackages = [pkgs.switchaudio-osx];

    system.defaults.NSGlobalDomain._HIHideMenuBar = true;

    # For spacebar debugging
    launchd.user.agents.sketchybar.serviceConfig.StandardErrorPath = "/tmp/sketchybar.err.log";
    launchd.user.agents.sketchybar.serviceConfig.StandardOutPath = "/tmp/sketchybar.out.log";
  };
}
