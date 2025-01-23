{
  pkgs,
  inputs,
  outputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    inputs.NixOS-WSL.nixosModules.wsl
    ../common/core
    ../common/users/pperanich
    ../common/optional/wsl.nix
    ../common/optional/tailscale.nix
    ../common/optional/couchdb.nix
  ];

  networking = {
    hostName = "pperanich-wsl1";
    useDHCP = true;
    interfaces.eth0 = {
      useDHCP = true;
      wakeOnLan.enable = true;
    };
  };

  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_zen;
    binfmt.emulatedSystems = ["aarch64-linux" "i686-linux"];
  };

  programs = {
    dconf.enable = true;
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    config.common.default = "*";
  };

  services.openssh.ports = [2222];

  system.stateVersion = "24.11";
}
