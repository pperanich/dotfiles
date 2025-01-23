# Host configuration for peranpl1-ml2
{ inputs, outputs, ... }:
{
  # imports = builtins.attrValues outputs.nixosModules
  #   ++ builtins.attrValues outputs.commonModules
  #   ++ builtins.attrValues outputs.darwinModules
  #   ++ [../../modules/common/users/peranpl1];
  imports = builtins.attrValues outputs.darwinModules;

  # Enable the modules
  modules = {
    core.enable = true;
    users.peranpl1.enable = true;
  };

  # Host-specific configuration goes here
  networking.hostName = "peranpl1-ml2";
  nixpkgs.hostPlatform = "aarch64-darwin";
}