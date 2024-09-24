{ pkgs, ... }:
{
  services = {
    sketchybar = {
      enable = true;
      package = pkgs.sketchybar;
    };
  };

  # environment.systemPackages = [ pkgs.nixcasks.switchaudio-osx ];
  homebrew = {
    brews = [
      "switchaudio-osx"
    ];
  };

  system.defaults.NSGlobalDomain._HIHideMenuBar = true;

  # For spacebar debugging
  launchd.user.agents.sketchybar.serviceConfig.StandardErrorPath = "/tmp/sketchybar.err.log";
  launchd.user.agents.sketchybar.serviceConfig.StandardOutPath = "/tmp/sketchybar.out.log";
}
