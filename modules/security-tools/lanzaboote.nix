# Secure boot configuration using lanzaboote
# Based on reference implementation from mic92-dotfiles
_: {
  flake.modules.nixos.securityTools = {lib, ...}: {
    boot.loader.efi.canTouchEfiVariables = false;
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/secureboot";
    };
  };
}
