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
    tailscale

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
    cloudflareCredentials
    caddyDns01

    # VPN (namespace mode — split tunneling for specific services)
    # protonvpn
    backup
  ]);

  my = {
    pperanich = {
      desktop = false;
      passwordHashSecret = "passwords/pperanich";
    };

    # Rex sessions over the tailnet, for admin workstations (tag:admin) only
    rex.loginServer.enable = true;

    # Nextcloud — file sync, calendar, contacts
    # Accessed via local Caddy TLS termination (nextcloud.prestonperanich.com)
    nextcloud = {
      hostName = mkSub "nextcloud";
      datadir = "/tank/appdata/nextcloud";
      listenAddress = "127.0.0.1";
      listenPort = 8088;
      openFirewall = false;
      # Local Caddy terminates TLS on :443 and proxies over loopback
      trustedProxies = [
        "127.0.0.1"
        "::1"
      ];
      extraTrustedDomains = [ "pp-nas1" ];
      extraApps = [
        "calendar"
        "contacts"
        "tasks"
        "notes"
      ];
    };

    # OpenCloud — file sync (side-by-side trial with Nextcloud)
    # Accessed via local Caddy TLS termination (opencloud.prestonperanich.com)
    opencloud = {
      url = "https://${mkSub "opencloud"}";
      stateDir = "/tank/appdata/opencloud";
      address = "127.0.0.1";
      openFirewall = false;
      adminPasswordSecret = "opencloud-admin-pass";
    };

    # Radicale — CalDAV/CardDAV (calendar + contacts)
    # Listens on localhost only; reached via the dav vhost below, where Caddy
    # authenticates and passes the identity via X-Remote-User
    radicale = {
      dataDir = "/tank/appdata/radicale";
      # Caddy authenticates the dav vhost below; module owns the env var name
      basicAuthHashSecret = "radicale-password-hash";
    };

    # scanservjs — web UI for pulling scans from the Canon TR4500 on PP-IoT.
    # Reverse-proxied at scan.prestonperanich.com via local Caddy.
    # Scans land directly on the ZFS pool at /tank/scans.
    scanservjs = {
      address = "127.0.0.1";
      openFirewall = false;
      outputDir = "/tank/scans";
      basicAuthHashSecret = "scanservjs-password-hash";
      scanner = {
        name = "Canon TR4500";
        # Pinned directly to the Kea reservation in pp-router1.configuration.nix
        # (segments.iot.reservations -> pp-printer1 = 10.0.20.50) rather than DDNS.
        url = "http://10.0.20.50/eSCL";
        discovery = false;
      };
    };

    # Paperless — document archive with OCR.
    # Ingests from a subdir of the scanservjs output so plain scans stay put;
    # drop files into /tank/scans/paperless to archive them.
    paperless = {
      address = "127.0.0.1";
      openFirewall = false;
      dataDir = "/tank/appdata/paperless";
      consumptionDir = "/tank/scans/paperless";
      domain = mkSub "paperless";
      passwordFile = config.sops.secrets.paperless-admin-pass.path;
    };

    # Home Assistant — automation for the IoT VLAN
    homeAssistant = {
      address = "127.0.0.1";
      openFirewall = false;
      configDir = "/tank/appdata/hass";
      # Local Caddy terminates TLS on :443 and proxies over loopback
      trustedProxies = [
        "127.0.0.1"
        "::1"
      ];
    };

    # Media servers: all proxied via local Caddy TLS termination
    jellyfin = {
      openFirewall = false;
      enableHardwareAcceleration = true;
      mediaDirectories = [
        "/tank/media/movies"
        "/tank/media/tv"
      ];
    };

    navidrome = {
      address = "127.0.0.1";
      openFirewall = false;
      musicFolder = "/tank/media/music";
    };

    audiobookshelf = {
      address = "127.0.0.1";
      openFirewall = false;
      mediaDirectories = [
        "/tank/media/audiobooks"
        "/tank/media/podcasts"
      ];
    };

    # DocuSeal — document signing. Localhost-only; reached exclusively through
    # the TLS names (docuseal.prestonperanich.com), no raw LAN port.
    docuseal = {
      secretKeyBaseFile = config.sops.secrets.docuseal-secret-key-base.path;
    };

    # Ship service journals to the router's Loki so fleet alerts have log
    # context. IP instead of hostname: log delivery must not depend on DNS.
    logShipping = {
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
        # Databases behind the services above — likelier to fail than the apps
        "postgresql"
        "redis-.*"
      ];
    };

    # Disk health monitoring — scraped only by the router's Prometheus
    smartMonitoring = {
      enable = true;
      listenAddress = "0.0.0.0";
    };

    # Host metrics (CPU/memory/ZFS/systemd) — scraped only by the router's Prometheus
    nodeMetrics = {
      enable = true;
      listenAddress = "0.0.0.0";
      # OpenCloud's debug endpoints occupy the whole 9100-9199 band
      port = 9640;
    };

    # Caddy — local TLS termination for split-horizon routing. The router's
    # Unbound answers these names with this host's IP for LAN clients (direct
    # route, no hairpin); tailnet and public clients resolve to the router, whose Caddy
    # re-proxies here over TLS. Certs via Cloudflare DNS-01, same pattern as
    # pp-router1. See docs/split-horizon-tls.md.
    caddyDns01.enable = true;

    # API token for the DNS-01 solver; the module owns the env var name
    cloudflare.enable = true;

    # Immich photo management
    # Accessed via local Caddy TLS termination (immich.prestonperanich.com)
    immich = {
      address = "127.0.0.1";
      openFirewall = false;
      mediaLocation = "/tank/appdata/immich";
      enableHardwareTranscoding = true;
      enableMachineLearning = false;
    };

    # Borg server for the router, plus the Google Drive tier
    backup = {
      borgServer = {
        enable = true;
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOs9dnM1hBiVwKTc8Xf1bFAnm4IaBQRocJF/7kh/khrS borg@pp-router1"
        ];
        repoName = "pp-router1";
        path = "/tank/backups/borg/pp-router1";
      };
      googleDrive = {
        enable = true;
        passwordSecret = "restic-gdrive-password";
        rcloneConfigSecret = "rclone-gdrive-conf";
        # Alertmanager runs on the router; this outside check still fires if the router is down.
        healthchecksPingUrlSecret = "healthchecks-gdrive-ping-url";
        # Whole trees, read from one atomic snapshot, so no service's state is left out.
        paths = [
          "/tank"
          "/var/lib"
          "/home"
        ];
        zfsSnapshot.datasets = {
          "rpool/tank" = "/tank";
          "rpool/tank/appdata" = "/tank/appdata";
          "rpool/tank/backups" = "/tank/backups";
          "rpool/var" = "/var";
          "rpool/home" = "/home";
        };
        # Regenerable (Immich derivatives) or re-downloadable (films, TV).
        exclude = [
          "/tank/appdata/immich/thumbs"
          "/tank/appdata/immich/encoded-video"
          "/tank/media/movies"
          "/tank/media/tv"
          ".cache"
        ];
        freshnessChecks = [
          {
            # The finished dump only; a failed run leaves a fresh, empty all.in-progress.sql.zstd.
            path = "/tank/backups/postgres";
            name = "all.sql.*";
            maxAgeHours = 26;
          }
        ];
      };
    };
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  # Networking configuration
  networking = {
    hostName = "pp-nas1";
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
    # Exporters are router-only: Prometheus on pp-router1 is the sole scraper.
    # All user-facing HTTP services bind to loopback behind Caddy TLS on :443.
    nftables.enable = true;
    firewall = {
      extraInputRules = ''
        ip saddr 10.0.0.1 tcp dport { 9633, 9640 } accept
      '';
      allowedTCPPorts = [ 443 ];
    };
    # Containers get internet egress only: no new connections to private/ULA/
    # link-local/multicast/CGNAT/Tailscale ranges or to this host's own services,
    # so a compromised container can't reach the rest of the NAS or LAN over
    # IPv4 or IPv6. Traffic between containers on the same bridge is left alone.
    # Separate rules rather than an interface set, since wildcards in sets need
    # a newer nft.
    nftables.tables.container-isolation = {
      family = "inet";
      content = ''
        set private4 {
          type ipv4_addr
          flags interval
          auto-merge
          elements = { 10.0.0.0/8, 100.64.0.0/10, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16 }
        }
        set private6 {
          type ipv6_addr
          flags interval
          auto-merge
          elements = { ::1/128, ::ffff:0:0/96, fc00::/7, fd7a:115c:a1e0::/48, fe80::/10, ff00::/8 }
        }
        chain forward {
          type filter hook forward priority filter - 10; policy accept;
          iifname "docker0" oifname != "docker0" ip daddr @private4 drop
          iifname "br-*" oifname != "br-*" ip daddr @private4 drop
          iifname "podman*" oifname != "podman*" ip daddr @private4 drop
          iifname "docker0" oifname != "docker0" ip6 daddr @private6 drop
          iifname "br-*" oifname != "br-*" ip6 daddr @private6 drop
          iifname "podman*" oifname != "podman*" ip6 daddr @private6 drop
        }
        chain input {
          type filter hook input priority filter - 10; policy accept;
          iifname "docker0" ct state new drop
          iifname "br-*" ct state new drop
          iifname "podman*" ct state new drop
        }
      '';
    };
  };

  # Docker for self-managed compose stacks (definitions live with each app).
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    daemon.settings = {
      # Public resolvers for containers: the isolation table above blocks
      # the LAN resolver. The daemon's own lookups (image pulls) still use
      # the host resolver.
      dns = [
        "1.1.1.1"
        "1.0.0.1"
      ];
      # json-file never rotates; `local` caps each container's logs.
      log-driver = "local";
    };
  };

  security = {
    polkit.enable = true;
  };

  # --- Secrets wiring (sops-nix) ---
  sops = {
    secrets = {
      # radicale-password-hash and opencloud-admin-pass are declared by their
      # own modules, from my.radicale.basicAuthHashSecret /
      # my.opencloud.adminPasswordSecret above.

      # Paperless: initial admin password
      paperless-admin-pass = {
        owner = "paperless";
        mode = "0400";
      };

      # DocuSeal: Rails secret key base (root-owned; service reads it via
      # LoadCredential since it runs under DynamicUser)
      docuseal-secret-key-base = { };

    };
  };

  # ProtonVPN — namespace mode (split tunneling)
  # Only services listed in confinedServices use the VPN; host traffic is unaffected.
  # Generate a WireGuard config at: ProtonVPN Settings → WireGuard → Create config
  # Then add its private key to sops and point interface.privateKeyFile at it.
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

  # Consume dir lives under scanservjs's 0750 output dir
  users.mutableUsers = false;
  users.users.paperless.extraGroups = [ "scanservjs" ];

  services.caddy = {
    globalConfig = ''
      # Certs come via DNS-01 so Caddy never needs the HTTP port; skip the
      # auto-HTTPS redirect listener and keep :80 closed.
      auto_https disable_redirects

      # Trust X-Forwarded-For only from loopback and pp-router1's LAN re-proxy
      # (10.0.0.1/32), never direct LAN or Tailscale end-clients.
      servers {
        trusted_proxies static 127.0.0.1/32 ::1/128 10.0.0.1/32
        trusted_proxies_strict
      }
    '';

    # Rewrite X-Forwarded-For to Caddy's verified {client_ip} so loopback
    # backends (Nextcloud, Home Assistant, etc.) that trust only 127.0.0.1/::1
    # see the real end-client IP rather than router re-proxy 10.0.0.1.
    virtualHosts =
      let
        mkLocalProxy = port: extra: {
          extraConfig = ''
            reverse_proxy 127.0.0.1:${toString port} {
              header_up X-Forwarded-For {client_ip}
            }
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
        "${mkSub "navidrome"}" = mkLocalProxy config.my.navidrome.port "";
        "${mkSub "scan"}" = mkLocalProxy config.my.scanservjs.port (
          lib.optionalString (config.my.scanservjs.basicAuthHashSecret != null) ''
            basic_auth {
              pperanich ${config.my.scanservjs.basicAuthHashPlaceholder}
            }
          ''
        );
        "${mkSub "hass"}" = mkLocalProxy config.my.homeAssistant.port "";
        "${mkSub "immich"}" = mkLocalProxy config.my.immich.port (mkUpload "50G");
        "${mkSub "nextcloud"}" = mkLocalProxy config.my.nextcloud.listenPort (mkUpload "16G");
        "${mkSub "opencloud"}" = mkLocalProxy config.my.opencloud.port (mkUpload "16G");
        "${mkSub "audiobookshelf"}" = mkLocalProxy config.my.audiobookshelf.port (mkUpload "10G");
        "${mkSub "paperless"}" = mkLocalProxy config.my.paperless.port (mkUpload "1G");
        "${mkSub "docuseal"}" = mkLocalProxy config.my.docuseal.port (mkUpload "1G");
        # Radicale: Caddy owns authentication; header_up overrides any
        # client-supplied X-Remote-User, which Radicale trusts blindly
        "${mkSub "dav"}" = {
          extraConfig = ''
            redir /.well-known/caldav / 301
            redir /.well-known/carddav / 301
            basic_auth {
              pperanich ${config.my.radicale.basicAuthHashPlaceholder}
            }
            reverse_proxy 127.0.0.1:${toString config.my.radicale.port} {
              header_up X-Forwarded-For {client_ip}
              header_up X-Remote-User {http.auth.user.id}
            }
          '';
        };
      };
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

  # Keep zfs-auto-snapshot off so sanoid is the sole local ZFS snapshot
  # scheduler on pp-nas1.
  services.zfs.autoSnapshot.enable = lib.mkForce false;

  # Tier 1 local ZFS snapshots across rpool datasets (disko.nix)
  services.sanoid = {
    enable = true;
    templates = {
      appdata = {
        hourly = 24;
        daily = 30;
        monthly = 6;
        autosnap = true;
        autoprune = true;
      };
      bulk = {
        hourly = 0;
        daily = 14;
        monthly = 3;
        autosnap = true;
        autoprune = true;
      };
      home = {
        hourly = 24;
        daily = 14;
        monthly = 3;
        autosnap = true;
        autoprune = true;
      };
    };
    datasets = {
      "rpool/tank/appdata".useTemplate = [ "appdata" ];
      "rpool/tank".useTemplate = [ "bulk" ];
      "rpool/tank/backups".useTemplate = [ "bulk" ];
      "rpool/home".useTemplate = [ "home" ];
    };
  };

  # Nightly logical dumps for all local PostgreSQL databases (Nextcloud, Immich,
  # Paperless) before offsite Restic tiers run. Upstream postgresql-backup.nix
  # already emits the `d '/tank/backups/postgres' 0700 postgres - - -` tmpfiles rule.
  services.postgresqlBackup = {
    enable = true;
    backupAll = true;
    location = "/tank/backups/postgres";
    startAt = "*-*-* 01:15:00";
    compression = "zstd";
  };
}
