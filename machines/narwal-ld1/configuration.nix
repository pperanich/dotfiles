{
  modules,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
  ]
  ++ (with modules.nixos; [
    # Basic development server
    serverBase
    developmentCore
  ]);

  networking.hostName = "narwal-ld1";
  nixpkgs.hostPlatform = "x86_64-linux";
}
