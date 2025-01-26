# Host configuration for peranpl1-ml2
{outputs, ...}: {
  imports = builtins.attrValues outputs.darwinModules;

  # Enable the modules
  my = {
    core.enable = true;
    users.peranpl1.enable = true;
  };

  # Host-specific configuration goes here
  networking.hostName = "peranpl1-ml2";
  nixpkgs.hostPlatform = "aarch64-darwin";
}
