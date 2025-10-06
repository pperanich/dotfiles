{
  inputs,
  modules,
  lib,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    inputs.nixos-wsl.nixosModules.default
  ]
  ++ (with modules.nixos; [
    # Core system configuration
    base
    sops

    # User setup
    pperanich

    # Development environment (minimal for WSL)
    rust

    # System utilities
    fileExploration
    networkUtilities
  ]);

  clan.core.networking.targetHost = lib.mkForce "root@pperanich-wsl1";
  clan.core.networking.buildHost = "root@pperanich-wsl1";

  nixpkgs.hostPlatform = "x86_64-linux";

  wsl = {
    enable = true;
    defaultUser = "pperanich";
    docker-desktop.enable = true;
    interop.register = true;
    startMenuLaunchers = true;
    usbip.enable = true;
    wslConf.network.generateResolvConf = true;
  };

  networking = {
    hostName = "pperanich-wsl1";
    interfaces.eth0 = {
      useDHCP = true;
      wakeOnLan.enable = true;
    };
    interfaces.eth1 = {
      useDHCP = true;
      wakeOnLan.enable = true;
    };
    interfaces.eth2 = {
      useDHCP = true;
      wakeOnLan.enable = true;
    };
    interfaces.eth3 = {
      useDHCP = true;
      wakeOnLan.enable = true;
    };
  };

  programs = {
    dconf.enable = true;
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    config.shared.default = "*";
  };

  services.openssh.ports = [ 2222 ];
  services.resolved.enable = false;
}
