{
  inputs,
  modules,
  lib,
  pkgs,
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

    # User setup (headless — no desktop apps/fonts)
    pperanich

    # Development environment (minimal for WSL)
    rust

    # System utilities
    fileExploration
    networkUtilities
  ]);

  clan.core = {
    networking = {
      targetHost = lib.mkForce "root@pp-wsl1.pp-wg";
    };
    enableRecommendedDefaults = false;
    deployment.requireExplicitUpdate = true;
  };

  features.pperanich.desktop = false;

  nixpkgs.hostPlatform = "x86_64-linux";

  hardware.graphics = {
    enable = true;
    enable32Bit = true;

    extraPackages = with pkgs; [
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };

  environment.systemPackages = with pkgs; [
    stdenv
    f2fs-tools
  ];

  wsl = {
    enable = true;
    defaultUser = "pperanich";
    docker-desktop.enable = true;
    interop.register = true;
    startMenuLaunchers = true;
    usbip.enable = true;
    wslConf.network.generateHosts = false;
    wslConf.network.generateResolvConf = true;
  };

  networking = {
    hostName = "pp-wsl1";
    interfaces = {
      # eth0 = {
      #   useDHCP = true;
      #   wakeOnLan.enable = true;
      # };
      # eth1 = {
      #   useDHCP = true;
      #   wakeOnLan.enable = true;
      # };
      # eth2 = {
      #   useDHCP = true;
      #   wakeOnLan.enable = true;
      # };
      # eth3 = {
      #   useDHCP = true;
      #   wakeOnLan.enable = true;
      # };
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

  # services.resolved.enable = false;
}
