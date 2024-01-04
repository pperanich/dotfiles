{ pkgs, lib, inputs, outputs, config, ... }:
{
  services = {
    sketchybar = {
      enable = true;
      package = pkgs.sketchybar;
    };
  };
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
