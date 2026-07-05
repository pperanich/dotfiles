{
  inputs,
  config,
  modules,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.my.homelab) mkSub;
in
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

    # Periodic WireGuard endpoint re-resolution (handles WAN IP rotation)
    wireguardReresolve

    # Self-hosted services
    immich
    nextcloud
    opencloud
    radicale
    scanservjs
    paperless
    homeAssistant
    jellyfin
    navidrome
    audiobookshelf
    docuseal

    # Disk health + host metrics (scraped by pp-router1's Prometheus)
    smartMonitoring
    nodeMetrics

    # Journal shipping to the router's Loki (context for SystemdUnitFailed)
    logShipping

    # Caddy + DNS-01 certificates (split-horizon TLS termination)
    caddyDns01

    # VPN (namespace mode — split tunneling for specific services)
    # protonvpn
  ]);

  my.pperanich.desktop = false;

  nixpkgs.hostPlatform = "x86_64-linux";
  clan.core.networking.targetHost = lib.mkForce "root@pp-nas1.home.arpa";
  # clan.core.networking.targetHost = lib.mkForce "root@pp-nas1.pp-wg";
  # clan.core.networking.buildHost = "root@pp-wsl1.pp-wg";

  # Networking configuration
  networking.hostName = "pp-nas1";
  networking = {
    # Bridge the two Ethernet ports so a downstream device on enp2s0 can
    # obtain DHCP from the upstream LAN on enp1s0. The NAS itself gets its
    # address on br0 rather than on either physical NIC.
    useDHCP = false;
    bridges.br0.interfaces = [
      "enp1s0"
      "enp2s0"
    ];
    interfaces = {
      br0.useDHCP = true;
      enp1s0.useDHCP = false;
      enp2s0.useDHCP = false;
    };
  };

  security = {
    polkit.enable = true;
  };

  # Nextcloud — file sync, calendar, contacts
  # Accessed via Caddy reverse proxy on pp-router1 (nextcloud.prestonperanich.com)
  my.nextcloud = {
    hostName = mkSub "nextcloud";
    datadir = "/tank/appdata/nextcloud";
    # Router Caddy (WG/hairpin path) + local Caddy (direct LAN path,
    # dials localhost so both loopback families must be trusted)
    trustedProxies = [
      "10.0.0.1"
      "127.0.0.1"
      "::1"
    ];
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
    url = "https://${mkSub "opencloud"}";
    stateDir = "/tank/appdata/opencloud";
    address = "0.0.0.0";
    openFirewall = true;
  };

  # Radicale — CalDAV/CardDAV (calendar + contacts)
  # Listens on localhost only; reached via the dav vhost below, where Caddy
  # authenticates and passes the identity via X-Remote-User
  my.radicale = {
    dataDir = "/tank/appdata/radicale";
  };

  # Caddy basic-auth bcrypt hash for the dav vhost, injected as an env var.
  # The matching plaintext lives in sops as radicale-password for client setup.
  sops.secrets.radicale-password-hash = { };
  sops.templates."caddy-radicale.env" = {
    content = ''
      RADICALE_PASSWORD_HASH=${config.sops.placeholder."radicale-password-hash"}
    '';
    owner = "caddy";
  };
  systemd.services.caddy.serviceConfig.EnvironmentFile = [
    config.sops.templates."caddy-radicale.env".path
  ];

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

  # scanservjs — web UI for pulling scans from the Canon TR4500 on PP-IoT.
  # Reverse-proxied at scan.prestonperanich.com via Caddy on pp-router1.
  # Scans land directly on the ZFS pool at /tank/scans.
  my.scanservjs = {
    address = "0.0.0.0";
    openFirewall = true;
    outputDir = "/tank/scans";
    scanner = {
      name = "Canon TR4500";
      # FQDN comes from the Kea reservation in pp-router1.configuration.nix
      # (segments.iot.reservations -> pp-printer1) registered via DDNS.
      url = "http://pp-printer1.home.arpa/eSCL";
      discovery = false;
    };
  };

  # Paperless — document archive with OCR.
  # Ingests from a subdir of the scanservjs output so plain scans stay put;
  # drop files into /tank/scans/paperless to archive them.
  my.paperless = {
    address = "0.0.0.0";
    openFirewall = true;
    dataDir = "/tank/appdata/paperless";
    consumptionDir = "/tank/scans/paperless";
    domain = mkSub "paperless";
    passwordFile = config.sops.secrets.paperless-admin-pass.path;
  };
  # Consume dir lives under scanservjs's 0750 output dir
  users.users.paperless.extraGroups = [ "scanservjs" ];

  # Home Assistant — automation for the IoT VLAN
  my.homeAssistant = {
    openFirewall = true;
    configDir = "/tank/appdata/hass";
    # Router Caddy (WG/hairpin path) + local Caddy (direct LAN path,
    # dials localhost so both loopback families must be trusted)
    trustedProxies = [
      "10.0.0.1"
      "127.0.0.1"
      "::1"
    ];
  };

  # Media servers — all proxied via Caddy on pp-router1
  my.jellyfin = {
    openFirewall = true;
    enableHardwareAcceleration = true;
    mediaDirectories = [
      "/tank/media/movies"
      "/tank/media/tv"
    ];
  };

  my.navidrome = {
    address = "0.0.0.0";
    openFirewall = true;
    musicFolder = "/tank/media/music";
  };

  my.audiobookshelf = {
    address = "0.0.0.0";
    openFirewall = true;
    mediaDirectories = [
      "/tank/media/audiobooks"
      "/tank/media/podcasts"
    ];
  };

  # DocuSeal — document signing. Localhost-only; reached exclusively through
  # the TLS names (docuseal.prestonperanich.com), no raw LAN port.
  my.docuseal = {
    secretKeyBaseFile = config.sops.secrets.docuseal-secret-key-base.path;
  };

  # Ship service journals to the router's Loki so fleet alerts have log
  # context. IP instead of hostname: log delivery must not depend on DNS.
  my.logShipping = {
    lokiUrl = "http://10.0.0.1:3100";
    keepUnits = [
      "sshd"
      "smartd"
      "caddy"
      "docuseal"
      "jellyfin"
      "navidrome"
      "audiobookshelf"
      "scanservjs"
      "home-assistant"
      "opencloud"
      "radicale"
      "nginx"
      "phpfpm-nextcloud"
      "nextcloud-setup"
      "immich-server"
      "immich-machine-learning"
      "paperless-.*"
      "borgbackup-job-pp-router1"
      # Databases behind the services above — likelier to fail than the apps
      "postgresql"
      "redis-.*"
    ];
  };

  # Disk health monitoring — scraped only by the router's Prometheus
  my.smartMonitoring = {
    enable = true;
    listenAddress = "0.0.0.0";
  };

  # Host metrics (CPU/memory/ZFS/systemd) — scraped only by the router's Prometheus
  my.nodeMetrics = {
    enable = true;
    listenAddress = "0.0.0.0";
    # OpenCloud's debug endpoints occupy the whole 9100-9199 band
    port = 9640;
  };

  # Exporters are router-only: Prometheus on pp-router1 is the sole scraper.
  # User-facing services stay LAN-open for the direct .home.arpa route.
  networking.nftables.enable = true;
  networking.firewall.extraInputRules = ''
    ip saddr 10.0.0.1 tcp dport { 9633, 9640 } accept
  '';

  # Caddy — local TLS termination for split-horizon routing. The router's
  # Unbound answers these names with this host's IP for LAN clients (direct
  # route, no hairpin); WG/public clients resolve to the router, whose Caddy
  # re-proxies here over TLS. Certs via Cloudflare DNS-01, same pattern as
  # pp-router1. See docs/split-horizon-tls.md.
  my.caddyDns01.enable = true;

  services.caddy = {
    globalConfig = ''
      # nginx (nextcloud) owns :80; certs come via DNS-01 so Caddy never
      # needs the HTTP port — skip the auto-HTTPS redirect listener
      auto_https disable_redirects
    '';

    # Caddy sets X-Forwarded-For/-Proto automatically; only body caps differ
    virtualHosts =
      let
        mkLocalProxy = port: extra: {
          extraConfig = ''
            reverse_proxy localhost:${toString port}
            ${extra}
          '';
        };
        mkUpload = size: ''
          request_body {
            max_size ${size}
          }
        '';
      in
      {
        "${mkSub "jellyfin"}" = mkLocalProxy 8096 "";
        "${mkSub "navidrome"}" = mkLocalProxy 4533 "";
        "${mkSub "scan"}" = mkLocalProxy 8080 "";
        "${mkSub "hass"}" = mkLocalProxy 8123 "";
        "${mkSub "immich"}" = mkLocalProxy 2283 (mkUpload "50G");
        "${mkSub "nextcloud"}" = mkLocalProxy 80 (mkUpload "16G");
        "${mkSub "opencloud"}" = mkLocalProxy 9200 (mkUpload "16G");
        "${mkSub "audiobookshelf"}" = mkLocalProxy 8000 (mkUpload "10G");
        "${mkSub "paperless"}" = mkLocalProxy 28981 (mkUpload "1G");
        "${mkSub "docuseal"}" = mkLocalProxy 3000 (mkUpload "1G");
        # Radicale: Caddy owns authentication; header_up overrides any
        # client-supplied X-Remote-User, which Radicale trusts blindly
        "${mkSub "dav"}" = {
          extraConfig = ''
            redir /.well-known/caldav / 301
            redir /.well-known/carddav / 301
            basic_auth {
              pperanich {$RADICALE_PASSWORD_HASH}
            }
            reverse_proxy localhost:${toString config.my.radicale.port} {
              header_up X-Remote-User {http.auth.user.id}
            }
          '';
        };
      };
  };

  networking.firewall.allowedTCPPorts = [ 443 ];

  # Borg backup to pp-router1: user data only, service dirs stay on the mirror
  clan.core.state.userdata.folders = [
    "/home/pperanich"
    "/tank/scans"
  ];

  # Stamp last successful backup for the node-exporter textfile collector.
  # The unit runs under ProtectSystem=strict, so the textfile dir must be
  # explicitly writable.
  systemd.services."borgbackup-job-pp-router1".serviceConfig.ReadWritePaths = [
    "/var/lib/prometheus-node-exporter-text"
  ];
  services.borgbackup.jobs."pp-router1".postHook = ''
    if [ "$exitStatus" = "0" ]; then
      dir=/var/lib/prometheus-node-exporter-text
      printf 'borg_last_success_timestamp_seconds %s\n' "$(date +%s)" > "$dir/borgbackup.prom.tmp"
      mv "$dir/borgbackup.prom.tmp" "$dir/borgbackup.prom"
    fi
  '';

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
  # Paperless: initial admin password
  sops.secrets.paperless-admin-pass = {
    owner = "paperless";
    mode = "0400";
  };

  # DocuSeal: Rails secret key base (root-owned; service reads it via
  # LoadCredential since it runs under DynamicUser)
  sops.secrets.docuseal-secret-key-base = { };

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
