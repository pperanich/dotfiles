# A machine is a list of modules plus the handful of settings only this host
# cares about. `modules` is a specialArg holding flake.modules.
{ modules, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ]
  ++ (with modules.nixos; [
    base
    sops
    example
  ]);

  networking.hostName = "example-nixos";
  nixpkgs.hostPlatform = "x86_64-linux";

  time.timeZone = "America/New_York";
}
