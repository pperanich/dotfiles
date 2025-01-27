{outputs, ...}: {
  imports =
    builtins.attrValues outputs.nixosModules
    ++ [
      ./hardware-configuration.nix
    ];

  my = {
    core.enable = true;
    users.peranpl1.enable = true;
  };

  networking.hostName = "narwhal-ld1";
  nixpkgs.hostPlatform = "x86_64-linux";
}
