{
  pkgs,
  inputs,
  outputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    inputs.NixOS-WSL.nixosModules.wsl
    ../shared/core
    ../shared/users/pperanich
    ../shared/optional/wsl.nix
    ../shared/optional/tailscale.nix
    ../shared/optional/couchdb.nix
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
    config.shared.default = "*";
  };

  services.openssh.ports = [2222];

  system.stateVersion = "24.11";
}
