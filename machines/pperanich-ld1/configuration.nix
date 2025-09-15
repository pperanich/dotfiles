{outputs, ...}: {
  imports =
    builtins.attrValues outputs.nixosModules
    ++ [
      ./hardware-configuration.nix
    ];

  nixpkgs.hostPlatform = "x86_64-linux";

  my = {
    core.enable = true;
    users.peranpl1.enable = true;
    features.tailscale.enable = true;
    features.couchdb.enable = true;
  };

  networking.hostName = "pperanich-ld1";
}
