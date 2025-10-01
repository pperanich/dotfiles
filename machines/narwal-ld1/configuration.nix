{ inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    # Basic development server
    inputs.self.nixosModules.serverBase
    inputs.self.nixosModules.developmentCore
  ];

  networking.hostName = "narwal-ld1";
  nixpkgs.hostPlatform = "x86_64-linux";
}
