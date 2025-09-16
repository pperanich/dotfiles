# Host configuration for peranpl1-ml2
{
  outputs,
  lib,
  ...
}: {
  imports = builtins.attrValues outputs.darwinModules;

  clan.core.networking.targetHost = lib.mkForce "root@peranpl1-ml2";
  clan.core.networking.buildHost = "root@peranpl1-ml2";

  # Enable the modules
  my = {
    core.enable = true;
    users.peranpl1.enable = true;
    features = {
      sketchybar.enable = true;
      yabai.enable = true;
      skhd.enable = true;
      work.enable = true;
    };
  };

  # Host-specific configuration goes here
  networking.hostName = "peranpl1-ml2";
  nixpkgs.hostPlatform = "aarch64-darwin";
}
