{ inputs, lib, pkgs, config, modulesPath, ... }:
{
  imports = [
    inputs.NixOS-WSL.nixosModules.wsl
    # "${modulesPath}/profiles/minimal.nix"
  ];

  wsl = {
    enable = true;
    wslConf.automount.root = "/mnt";
    defaultUser = "pperanich";
    startMenuLaunchers = true;
    nativeSystemd = true;

    # Enable native Docker support
    docker-native.enable = true;

    # Enable integration with Docker Desktop (needs to be installed)
    docker-desktop.enable = true;

    # interop.register = false;
  };
}
