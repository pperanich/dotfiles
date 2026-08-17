{ modules, ... }:
{
  imports = with modules.darwin; [
    base
    sops
    example
  ];

  networking.hostName = "example-darwin";
  nixpkgs.hostPlatform = "aarch64-darwin";
}
