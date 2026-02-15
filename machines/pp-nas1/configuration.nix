{
  inputs,
  config,
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
    opencloud
    radicale

    # Virtualization (useful for mini PC/home server use)
    # docker
    # qemu
  ]);

  features.pperanich.desktop = false;

  nixpkgs.hostPlatform = "x86_64-linux";
  clan.core.networking.targetHost = lib.mkForce "root@pp-nas1.pp-wg";
  clan.core.networking.buildHost = "root@pp-wsl1.pp-wg";

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
    extraTrustedDomains = [ "pp-nas1.home.arpa" ];
    extraApps = [
      "calendar"
      "contacts"
      "tasks"
      "notes"
    ];
  };

  # OpenCloud — file sync (side-by-side trial with Nextcloud)
  # Accessed via Caddy reverse proxy on pp-router1 (opencloud.prestonperanich.com)
  features.opencloud = {
    url = "https://opencloud.prestonperanich.com";
    stateDir = "/tank/appdata/opencloud";
    address = "0.0.0.0";
    openFirewall = true;
  };

  # Radicale — CalDAV/CardDAV for OpenCloud (calendar + contacts)
  # Listens on localhost only; proxied through Caddy alongside OpenCloud
  features.radicale = {
    dataDir = "/tank/appdata/radicale";
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

  # --- Secrets wiring (sops-nix) ---
  # Nextcloud: admin password file
  sops.secrets.nextcloud-admin-pass = {
    owner = "nextcloud";
    mode = "0400";
  };
  features.nextcloud.adminPasswordFile = config.sops.secrets.nextcloud-admin-pass.path;

  # OpenCloud: admin password via environment file template
  sops.secrets.opencloud-admin-pass = {
    owner = "opencloud";
    mode = "0400";
  };
  sops.templates."opencloud.env" = {
    content = ''
      IDM_ADMIN_PASSWORD=${config.sops.placeholder."opencloud-admin-pass"}
    '';
    owner = "opencloud";
  };
  features.opencloud.environmentFile = config.sops.templates."opencloud.env".path;

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
