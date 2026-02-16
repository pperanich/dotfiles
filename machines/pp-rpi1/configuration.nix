# Host configuration for pp-rpi1 (Raspberry Pi 5)
{
  inputs,
  lib,
  modules,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    # Raspberry Pi 5 hardware support from nixos-hardware
    inputs.hardware.nixosModules.raspberry-pi-5
  ]
  ++ (with modules.nixos; [
    # Core system configuration
    base
    sops

    # User setup (headless — no desktop apps/fonts)
    pperanich
  ]);

  features.pperanich.desktop = false;

  nixpkgs.hostPlatform = "aarch64-linux";
  clan.core.networking.targetHost = lib.mkForce "root@pp-rpi1";
  clan.core.networking.buildHost = "root@pp-rpi1";

  # Enable Bluetooth
  hardware.bluetooth.enable = true;

  environment.systemPackages = with pkgs; [
    libraspberrypi
    raspberrypi-utils
  ];

  # Networking configuration
  networking.hostName = "pp-rpi1";
}
