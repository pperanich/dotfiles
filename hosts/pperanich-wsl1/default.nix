{
  inputs,
  outputs,
  ...
}: {
  imports =
    builtins.attrValues outputs.nixosModules
    ++ [
      ./hardware-configuration.nix
      inputs.nixos-wsl.nixosModules.default
    ];

  nixpkgs.hostPlatform = "x86_64-linux";

  my = {
    core.enable = true;
    users.pperanich.enable = true;
    features.virtualization = {
      docker.enable = true;
      podman.enable = true;
      qemu = {
        enable = true;
        enableVirtManager = true;
      };
    };
  };

  wsl = {
    enable = true;
    defaultUser = "pperanich";
    docker-desktop.enable = true;
    interop.register = true;
    startMenuLaunchers = true;
  };

  networking = {
    hostName = "pperanich-wsl1";
    interfaces.eth0 = {
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

  services.openssh.ports = [2222];
}
