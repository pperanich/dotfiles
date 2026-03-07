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

    # Self-hosted services
    immich
    nextcloud
    opencloud
    radicale

    # VPN (namespace mode — split tunneling for specific services)
    # protonvpn
  ]);

  my.pperanich.desktop = false;

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
  my.nextcloud = {
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
  my.opencloud = {
    url = "https://opencloud.prestonperanich.com";
    stateDir = "/tank/appdata/opencloud";
    address = "0.0.0.0";
    openFirewall = true;
  };

  # Radicale — CalDAV/CardDAV for OpenCloud (calendar + contacts)
  # Listens on localhost only; proxied through Caddy alongside OpenCloud
  my.radicale = {
    dataDir = "/tank/appdata/radicale";
  };

  # ProtonVPN — namespace mode (split tunneling)
  # Only services listed in confinedServices use the VPN; host traffic is unaffected.
  # Generate a WireGuard config at: ProtonVPN Settings → WireGuard → Create config
  # Then run `clan vars generate pp-nas1` — you'll be prompted for the private key.
  # my.protonvpn = {
  #   enable = true;
  #   mode = "namespace";
  #   verify.enable = true;
  #
  #   # From your ProtonVPN WireGuard config (Settings → WireGuard → Create config)
  #   endpoint.ip = "TODO"; # Server IP (e.g., "193.148.18.68")
  #   endpoint.publicKey = "TODO"; # Server public key
  #   interface.ip = "10.2.0.2/32"; # Usually this default; check your config
  #
  #   # Add confined services here later, e.g.:
  #   # namespace.confinedServices.transmission = {
  #   #   serviceUnit = "transmission";
  #   #   socketProxy."0.0.0.0:9091" = "127.0.0.1:9091";
  #   # };
  # };

  # Immich photo management
  # Accessed via Caddy reverse proxy on pp-router1 (immich.prestonperanich.com)
  my.immich = {
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
  my.nextcloud.adminPasswordFile = config.sops.secrets.nextcloud-admin-pass.path;

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
  my.opencloud.environmentFile = config.sops.templates."opencloud.env".path;

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
