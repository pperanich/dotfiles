{
  inputs,
  modules,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./disko.nix
    inputs.nixos-facter-modules.nixosModules.facter
  ]
  ++ (with modules.nixos; [
    # Core system configuration
    base
    sops

    # User setup (headless — no desktop apps/fonts)
    pperanich

    # Development environment
    rust

    # System utilities
    fileExploration
    networkUtilities

    # Self-hosted services
    immich
    nextcloud

    # Virtualization (useful for mini PC/home server use)
    # docker
    # qemu
  ]);

  features.pperanich.desktop = false;

  nixpkgs.hostPlatform = "x86_64-linux";
  clan.core.networking.targetHost = lib.mkForce "root@192.168.0.161";
  clan.core.networking.buildHost = "root@192.168.0.184";

  # Networking configuration
  networking.hostName = "pp-nas1";

  security = {
    polkit.enable = true;
  };

  # Nextcloud — file sync, calendar, contacts
  # Accessed via Caddy reverse proxy on pp-router1 (nextcloud.prestonperanich.com)
  features.nextcloud = {
    hostName = "nextcloud.prestonperanich.com";
    datadir = "/tank/appdata/nextcloud";
    trustedProxies = [ "10.0.0.1" ];
    extraTrustedDomains = [ "192.168.0.161" ];
    extraApps = [
      "calendar"
      "contacts"
      "tasks"
      "notes"
    ];
  };

  # Immich photo management
  # Accessed via Caddy reverse proxy on pp-router1 (immich.prestonperanich.com)
  features.immich = {
    address = "0.0.0.0";
    openFirewall = true;
    mediaLocation = "/tank/appdata/immich";
    enableHardwareTranscoding = true;
    enableMachineLearning = false;
  };

  hardware = {
    enableRedistributableFirmware = true;
    bluetooth.enable = false;
  };

  # Package configuration
  environment.systemPackages = with pkgs; [
    # System utilities
    wget
    git
    htop
    btop
    neofetch
    dmidecode
    pciutils
    lm_sensors

    # Network debugging
    tcpdump
    iperf3
    mtr
    nmap
    ethtool
    conntrack-tools

    # Firmware updates
    fwupd
    linux-firmware
  ];
}
