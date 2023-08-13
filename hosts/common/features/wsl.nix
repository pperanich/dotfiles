{ lib, pkgs, config, modulesPath, ... }:
{
  imports = [
    inputs.NixOS-WSL.nixosModules.wsl
    # "${modulesPath}/profiles/minimal.nix"
  ];

  wsl = {
    enable = true;
    automountPath = "/mnt";
    defaultUser = config.home.username;
    startMenuLaunchers = true;
    nativeSystemd = true;

    # Enable native Docker support
    docker-native.enable = true;

    # Enable integration with Docker Desktop (needs to be installed)
    docker-desktop.enable = true;
  };
}