{
  inputs,
  config,
  modules,
  pkgs,
  lib,
  ...
}:
let
  routerIp = config.my.router.lan.address;
  domain = config.my.router.dhcp.domainName;
  inherit (lib.my.homelab) publicDomain mkSub;
in
{
  imports = [
    ./disko.nix
    ./caddy.nix
    ./printing.nix
    ./homepage.nix
    inputs.nixos-facter-modules.nixosModules.facter
  ]
  ++ (with modules.nixos; [
    # Core system configuration
    base
    sops
    tailscale

    # User setup (headless — no desktop apps/fonts)
    pperanich

    # Router functionality
    router

    # Disk health (local NVMe)
    smartMonitoring

    # Shared Cloudflare API credentials (token env file for the Cloudflare modules below)
    cloudflareCredentials

    # Cloudflare DNS sync
    cloudflareDns

    # Caddy + DNS-01 certificates (vhosts in ./caddy.nix)
    caddyDns01

    # Public services (via Cloudflare Tunnel)
    cloudflareTunnel
    vaultwarden
    gitea
    observability

    # Self-hosted Tailscale control plane (gray-cloud DDNS + Caddy :9443)
    headscale
    headplane

    # Outbound transactional email
    stalwart

    # Router-to-NAS Borg and the Google Drive tier
    backup
  ]);

  my = {
    pperanich = {
      desktop = false;
      passwordHashSecret = "passwords/pperanich";
    };

    # Rex sessions over the tailnet, for admin workstations (tag:admin) only
    rex.loginServer.enable = true;

    headscale.enable = true;

    # Headscale web UI (LAN + tailnet via Caddy, API-key login)
    headplane = {
      enable = true;
      domain = mkSub "headplane";
      cookieSecretSecret = "headplane-cookie-secret";
    };

    # Custom router nftables already opens UDP 41641 on WAN
    tailscale = {
      openFirewall = false;
      expectedIpv4 = config.my.headscale.routerTailscaleIpv4;
      expectedIpv6 = config.my.headscale.routerTailscaleIpv6;
    };

    # Vaultwarden password manager
    vaultwarden = {
      enable = true;
      domain = mkSub "vault";
      adminTokenFile = config.sops.secrets.vaultwarden-admin-token.path;
      smtpFrom = "vault@${publicDomain}";
    };

    # Gitea: self-hosted git over LAN + Tailscale
    gitea = {
      enable = true;
      domain = mkSub "gitea";
      mail = {
        enable = true;
        from = "gitea@${publicDomain}";
      };
      admin = {
        username = "pperanich";
        email = "pperanich@gmail.com";
        passwordFile = config.sops.secrets.gitea-admin-password.path;
      };
    };

    # Stalwart — outbound transactional email relay via Resend
    stalwart = {
      enable = true;
      hostname = mkSub "mail";
      relayCredentialFile = config.sops.secrets.resend-api-key.path;
    };

    observability = {
      enable = true;
      grafana.hostname = mkSub "grafana";
      # Accept journal pushes from fleet hosts on LAN IP only (never IoT/Guest/WAN)
      loki.listenAddress = "10.0.0.1";
      blackbox.httpTargets = [
        "https://${config.my.observability.grafana.hostname}"
        "https://${mkSub "home"}"
        "https://${config.my.vaultwarden.domain}"
        # End-to-end probe of the public site through the Cloudflare tunnel
        "https://${publicDomain}"
        # Self-hosted Headscale control plane (:9443 TLS + /health)
        "https://${config.my.headscale.domain}:${toString config.my.headscale.publicPort}/health"
      ]
      # Router-terminated vhosts: every name carries an independently renewed
      # DNS-01 cert, so each needs its own probe for CertExpiringSoon
      ++ map (sub: "https://${mkSub sub}") [
        "gitea"
        "vault-admin"
        "ntopng"
        "unifi"
        "headplane"
      ]
      # NAS vhosts: resolve to the NAS via split-horizon, exercising the NAS
      # Caddy's per-name certs and the service behind each one
      ++ map (sub: "https://${mkSub sub}") [
        "jellyfin"
        "immich"
        "nextcloud"
        "opencloud"
        "navidrome"
        "audiobookshelf"
        "paperless"
        "hass"
        "docuseal"
      ];
      blackbox.authHttpTargets = [ "https://${mkSub "scan"}" ];
      # One probe through the router Caddy → NAS Caddy leg (the tailnet
      # client path). Regular probes resolve via split-horizon straight to
      # the NAS and never exercise it.
      blackbox.proxyCanary = {
        url = "https://[${config.my.headscale.routerTailscaleIpv6}]/web/";
        serverName = mkSub "jellyfin";
      };
      dropMonitor = {
        enable = true;
        interfaces = [
          "br-lan"
          "br-main"
        ];
      };
      unpoller = {
        enable = true;
        passwordFile = config.sops.secrets.unpoller-password.path;
      };
      alerts = {
        email = {
          # Plus-addressing: Gmail delivers to pperanich@gmail.com but keeps
          # the +alerts tag in the To: header for filtering
          to = "pperanich+alerts@gmail.com";
          from = "alerts@${publicDomain}";
        };
        externalUrl = "https://${config.my.observability.grafana.hostname}/alerting/list";
        # 10G trunk to the switch — carrier loss here takes down the whole LAN
        carrierInterfaces = [ "enp1s0f1np1" ];
        deadman.pingUrlFile = config.sops.secrets.healthchecks-ping-url.path;
      };
      smartctlTargets = [
        "127.0.0.1:9633"
        "pp-nas1:9633"
      ];
      nodeTargets = [ "pp-nas1:9640" ];
    };

    smartMonitoring.enable = true;

    # Cloudflare Tunnel — public service exposure without opening WAN ports
    # tunnelId read from cf-tunnel.json (written by: cf tunnel sync --name homelab --apply)
    cloudflareTunnel =
      let
        tunnelMeta = builtins.fromJSON (builtins.readFile ./cf-tunnel.json);
      in
      {
        enable = true;
        inherit (tunnelMeta) tunnelId tunnelName;
        zone = publicDomain;
        credentialsFile = config.sops.secrets.cloudflared-tunnel-credentials.path;
        ingress = {
          "${publicDomain}" = "http://localhost:8224"; # Personal site
          "${mkSub "www"}" = "http://localhost:8224"; # Redirect to apex
          "${mkSub "vault"}" = "http://localhost:8223"; # Caddy tunnel listener (blocks /admin)
        };
      };

    # Router configuration
    router = {
      enable = true;

      # WAN & VPN firewall rules:
      # - TCP 9443: Headscale TS2021 control plane via Caddy TLS
      # - UDP 41641: Tailscale direct WireGuard peer hole-punching
      # Note: tailscale0 is intentionally NOT in trustedInterfaces (zero-trust:
      # explicit per-port input rules below, no router LAN subnet forwarding).
      firewall = {
        openPorts = {
          tcp = [ config.my.headscale.publicPort ];
          udp = [ 41641 ];
        };
        hairpinNat.enable = true;
        # Open HTTPS for Caddy on LAN
        extraInputRules = ''
          iifname "br-main" tcp dport 443 accept comment "Caddy HTTPS from LAN"
          iifname "br-main" tcp dport 631 accept comment "CUPS IPP from LAN"
          iifname "br-main" ip saddr 10.0.0.105 tcp dport 3100 accept comment "Loki ingest from pp-nas1"
          iifname "tailscale0" tcp dport { 22, 443 } accept comment "SSH and Caddy HTTPS from Tailscale"
          iifname "tailscale0" tcp dport ${toString config.my.rex.loginServer.port} accept comment "Rex login server from Tailscale"
          iifname "tailscale0" udp dport 53 accept comment "DNS UDP from Tailscale"
          iifname "tailscale0" tcp dport 53 accept comment "DNS TCP from Tailscale"
        '';
        extraInputRulesV6 = ''
          iifname "br-main" tcp dport 443 accept comment "Caddy HTTPS from LAN"
          iifname "br-main" tcp dport 631 accept comment "CUPS IPP from LAN"
          iifname "tailscale0" tcp dport { 22, 443 } accept comment "SSH and Caddy HTTPS from Tailscale"
          iifname "tailscale0" tcp dport ${toString config.my.rex.loginServer.port} accept comment "Rex login server from Tailscale"
          iifname "tailscale0" udp dport 53 accept comment "DNS UDP from Tailscale"
          iifname "tailscale0" tcp dport 53 accept comment "DNS TCP from Tailscale"
        '';
      };

      # Network interfaces
      wan.interface = "enp4s0";
      lan = {
        interfaces = [
          "enp1s0f0np0"
          "enp1s0f1np1"
          "enp2s0"
          # External Unifi AP connects here via trunk port
        ];
        subnet = "10.0.0";
        dhcpRange = {
          start = 100;
          end = 200;
        };
      };

      ipv6 = {
        enable = true;
        ulaPrefix = "fd12:3456:789a:bcde";
      };

      # Enable services
      dhcp.enable = true;
      dns = {
        enable = true;
        privateDomains = [ publicDomain ]; # Allow private IP responses for Caddy subdomains
        extraInterfaces = [
          config.my.headscale.routerTailscaleIpv4 # Tailscale IPv4 split-DNS
          config.my.headscale.routerTailscaleIpv6 # Tailscale ULA IPv6 split-DNS
        ];
        extraAccessControl = [
          "100.64.0.0/10 allow"
          "fd7a:115c:a1e0::/48 allow"
        ];
        ddns.enable = true; # Auto-register DHCP client hostnames in DNS
        extraLocalData = [
          # WSL mirrored networking shares the Windows host's IP
          "pp-wsl1.${domain}. CNAME pp-wd1.${domain}."
          # Split-horizon for Headscale so LAN clients reach 10.0.0.1:9443 directly
          "${config.my.headscale.domain}. A ${routerIp}"
        ]
        # Split-horizon: LAN clients resolve NAS-hosted services to the NAS
        # itself (direct route, TLS terminates at its Caddy) instead of the
        # public records pointing here. Unbound's transparent local-zone
        # returns NODATA for AAAA on these names, so v6 won't pull clients
        # back to the router. See docs/split-horizon-tls.md.
        ++ map (sub: "${mkSub sub}. A 10.0.0.105") [
          "jellyfin"
          "immich"
          "nextcloud"
          "opencloud"
          "navidrome"
          "audiobookshelf"
          "scan"
          "paperless"
          "docuseal"
          "dav"
          "hass"
        ]
        # Router-terminated vhosts: public DNS is AAAA-only (the tailnet ULA) so
        # off-net tailnet clients aren't poisoned by an unroutable A. LAN
        # clients need a v4 answer though — an AAAA-only name backed by a ULA is
        # unresolvable under getaddrinfo's AI_ADDRCONFIG (no global v6), so give
        # them a split-horizon A pointing at this router's Caddy.
        ++ map (sub: "${mkSub sub}. A ${routerIp}") [
          "home"
          "grafana"
          "vault-admin"
          "gitea"
          "ntopng"
          "unifi"
          "headplane"
        ];
      };

      # Clients search home.arpa (LAN hosts via DDNS) then the tailnet domain
      dhcp.searchDomains = [
        config.my.router.dhcp.domainName
        config.my.headscale.baseDomain
      ];

      # DNS ad-blocking via Blocky (sits in front of Unbound on port 53)
      # Unbound retreats to localhost:5335 as DNSSEC/DoT backend
      blocky = {
        enable = true;
        # Serve /etc/hosts over DNS so its names resolve for every LAN/tailnet
        # client, not just this host
        extraSettings.hostsFile = {
          sources = [ "/etc/hosts" ];
          hostsTTL = "5m";
          loading.refreshPeriod = "5m";
          # Never serve loopback entries (e.g. "127.0.0.2 pp-router1")
          # to LAN clients
          filterLoopback = true;
        };
        # Per-VLAN blocking (override auto-derived defaults for explicit control)
        clientGroupsBlock = {
          default = [
            "ads"
            "malware"
          ];
          "10.0.20.0/24" = [
            "ads"
            "malware"
            "telemetry"
          ]; # IoT: aggressive
          "10.0.30.0/24" = [
            "ads"
            "malware"
          ]; # Guest: standard
        };
      };

      mdns = {
        enable = true; # Enables .local device discovery (AirPlay, Chromecast, printers)
        # Reflector off. Avahi listens on br-iot (so cups-browsed can discover
        # the Canon TR4500's announce locally) but does NOT relay the printer's
        # mDNS onto br-main. Two reasons:
        #   1. Apple's mDNSResponder applies a same-subnet check on A records
        #      (RFC 6762 §11); a reflected `A=10.0.20.50` arriving on br-main
        #      gets dropped, so off-subnet relay buys Macs nothing useful.
        #   2. Reflecting would leak every PP-IoT mDNS service (printer admin
        #      pages, _canon-chmp, _pdl-datastream, future IoT cameras, etc.)
        #      into PP-Net, eroding VLAN segmentation.
        # Cross-VLAN AirPrint is solved at L7 by the cupsd broker below: it
        # publishes `Canon_TR4500_series @ pp-router1` on br-main with an
        # on-subnet A=10.0.0.1, which Apple accepts cleanly.
        reflector = false;
      };

      # Network monitoring with ntopng
      # Access at http://10.0.0.1:3000 (default: admin/admin)
      monitoring.enable = true;

      # Unifi controller for managing Ubiquiti access points
      # Access at https://10.0.0.1:8443
      unifi.enable = true;

      # Network segmentation with VLANs
      # WiFi handled by external Unifi AP connected via trunk port.
      #
      # AP-side expectations (mirror router's bridge VLAN config — see
      # modules/router/vlans.nix near the "BridgeVLAN" comment block):
      #   Main  → AP "untagged" / Default network. The router egresses VLAN 10
      #           UNTAGGED for the segment matching `lan.subnet`. The PS-Net
      #           SSID must NOT be bound to a VLAN-tagged UniFi network — if
      #           it is, the AP tags frames as VLAN 10 and they no longer
      #           bridge with the router's untagged egress, silently breaking
      #           wired→Wi-Fi multicast (mDNS/AirPrint discovery).
      #   IoT   → AP tagged VLAN 20  (PS-IoT)
      #   Guest → AP tagged VLAN 30  (PS-Guest)
      #
      # Note: Media VLAN removed — Chromecast SDK rejects devices on different subnets,
      # so TVs must be on the main LAN for casting to work. AirPlay works cross-VLAN
      # but Chromecast does not (Google's SDK enforces same-subnet check).
      networks = {
        enable = true;
        segments = {
          # Main network - VLAN 1 (native/untagged via PVID)
          # TVs and media devices live here for Chromecast compatibility.
          # Tagging the main LAN prevents Kea's raw (PF_PACKET) socket on
          # br-lan from capturing VLAN-tagged DHCP discovers meant for other
          # networks — br-lan becomes a pure L2 trunk with no DHCP listener.
          main = {
            vlan = 10;
            subnet = "10.0.0";
            isolation = "none"; # Full access to everything
            # Pin nas1 to a stable lease so its DNS record stops drifting
            # (it was floating across DHCP leases, breaking hostname deploys).
            reservations = [
              {
                hostname = "pp-nas1";
                mac = "b2:96:cc:f4:c8:bc";
                ip = 105;
              }
            ];
          };
          # IoT network - isolated with controlled access
          iot = {
            vlan = 20;
            subnet = "10.0.20";
            isolation = "internet"; # Internet only, no inter-VLAN
            allowAccessFrom = [ "main" ]; # Main network can access IoT devices
            mdns = true; # Reflect Bonjour so cups-browsed (on router) sees the printer's announces
            reservations = [
              {
                hostname = "pp-printer1";
                mac = "f8:a2:6d:00:6c:b2";
                ip = 50;
              }
            ];
          };
          # Guest network - fully isolated
          guest = {
            vlan = 30;
            subnet = "10.0.30";
            isolation = "full"; # Internet only, no inter-network access
          };
        };
      };

      # Note: WiFi handled by external Unifi AP (MT7915E removed due to driver issues)
      # AP connects via trunk port and is managed by the Unifi controller above
    };

    # Shared Cloudflare API credentials: cf-dns, cf-tunnel and Caddy
    # all read the env file this builds. Env var names live in the module.
    cloudflare = {
      enable = true;
      accountIdSecret = "cloudflare-account-id"; # cf tunnel sync-dns needs it
    };

    # Borg client to the NAS, plus the Google Drive tier
    backup = {
      autoDetectSqlite = true;
      borgClient = {
        enable = true;
        passphraseSecret = "borg-router-passphrase";
        sshKeySecret = "borg-router-ssh-key";
        serverHostKey = "pp-nas1.home.arpa ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEgsuBDxHDx8irZVlgID0eevgFTCpbRFKPZRyWFcvgQO";
        repo = "ssh://borg@pp-nas1.home.arpa/tank/backups/borg/pp-router1";
        paths = [
          "/var/backups/sqlite"
          "/var/lib/vaultwarden"
          "/var/lib/gitea"
          "/var/lib/headscale"
          "/var/lib/unifi/data/backup"
        ];
        exclude = [
          "/var/lib/vaultwarden/db.sqlite3*"
          "/var/lib/gitea/data/gitea.db*"
          "/var/lib/headscale/db.sqlite*"
        ];
      };
      # Offsite copy of the same data; Borg stays the LAN copy for restores while the router is down.
      googleDrive = {
        enable = true;
        passwordSecret = "restic-gdrive-password";
        rcloneConfigSecret = "rclone-gdrive-conf";
        # Prometheus and Alertmanager run on this host, so an outside check also watches its backup.
        healthchecksPingUrlSecret = "healthchecks-gdrive-ping-url";
        inherit (config.my.backup.borgClient) paths exclude;
      };
    };
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  # Networking configuration
  networking.hostName = "pp-router1";
  users.mutableUsers = false;

  # Local time for logs and alert email timestamps
  time.timeZone = "America/New_York";

  # Serial console for debugging (ttyS0 at 115200 baud, 8N1)
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS0,115200n8"
  ];

  # TCP/Network stack tuning for performance
  # BBR handles lossy links better than CUBIC
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_slow_start_after_idle" = 0;
    # Allow Caddy and Blocky to bind pp-router1's Tailscale IPs (100.64.0.1 /
    # fd7a:115c:a1e0::1) at boot before tailscaled brings up tailscale0
    "net.ipv4.ip_nonlocal_bind" = 1;
    "net.ipv6.ip_nonlocal_bind" = 1;
  };

  services = {
    irqbalance.enable = true;

    # The pinned build already on the router (flake.nix, nixpkgs-mongodb): nixpkgs' MongoDB is
    # unfree, never cached, and takes hours to compile on this N150.
    unifi.mongodbPackage =
      (import inputs.nixpkgs-mongodb {
        inherit (pkgs.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      }).mongodb;

    # Gray-cloud DDNS for Headscale control plane (Cloudflare proxy/tunnel
    # strips TS2021 `Upgrade: tailscale-control-protocol` headers).
    cloudflare-dyndns = {
      enable = true;
      apiTokenFile = config.sops.secrets.${config.my.cloudflare.apiTokenSecret}.path;
      domains = [ config.my.headscale.domain ];
      proxied = false;
      ipv4 = true;
      ipv6 = false;
    };

    # SSH hardening for router
    openssh.settings = {
      X11Forwarding = false;
      PermitRootLogin = "no";
      PasswordAuthentication = false; # Disable password auth entirely
      KbdInteractiveAuthentication = false; # Disable keyboard-interactive
      MaxAuthTries = 3;
      LoginGraceTime = 20;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
      MaxStartups = "10:30:60"; # Rate limit: start:rate:full
    };
  };
  systemd = {
    services = {
      "serial-getty@ttyS0".enable = true;

      # Activation restarts networkd and blocky; a DDNS run in that gap fails and aborts the deploy.
      cloudflare-dyndns.serviceConfig = {
        Restart = "on-failure";
        RestartSec = 30;
      };

      # 10G trunk dropped carrier (2026-07-03) and needed a power cycle: bounce
      # link at 30s down, rebind PCI function at 90s (equivalent of NIC reset).
      trunk-link-watchdog = {
        description = "Auto-recover the 10G LAN trunk after sustained carrier loss";
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.iproute2 ];
        serviceConfig = {
          Restart = "always";
          RestartSec = 10;
        };
        script = ''
          IFACE=enp1s0f1np1
          PCI=0000:01:00.1
          DOWN=0
          while sleep 5; do
            if [ "$(cat /sys/class/net/$IFACE/carrier 2>/dev/null)" = 1 ]; then
              DOWN=0
              continue
            fi
            DOWN=$((DOWN + 5))
            if [ "$DOWN" -eq 30 ]; then
              echo "carrier down 30s, bouncing $IFACE"
              ip link set "$IFACE" down
              sleep 2
              ip link set "$IFACE" up
            elif [ "$DOWN" -ge 90 ]; then
              echo "carrier still down after link bounce, rebinding $PCI"
              echo "$PCI" > /sys/bus/pci/drivers/i40e/unbind
              sleep 2
              echo "$PCI" > /sys/bus/pci/drivers/i40e/bind
              DOWN=0
            fi
          done
        '';
      };
    };
  };

  # Router-appropriate packages (no desktop environment)
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

  # --- Secrets wiring (sops-nix) ---
  sops = {
    secrets = {
      # Vaultwarden: admin token for /admin panel
      vaultwarden-admin-token = {
        owner = "vaultwarden";
        mode = "0400";
        restartUnits = [ "vaultwarden.service" ]; # the token env file is built at service start
      };

      # Gitea: initial admin password (consumed by gitea-admin-bootstrap.service)
      gitea-admin-password = {
        owner = "git";
        mode = "0400";
      };

      # Resend: API key for SMTP relay
      resend-api-key = {
        # stalwart stateVersion 26.05 renamed the service user stalwart-mail -> stalwart
        owner = "stalwart";
        mode = "0400";
        restartUnits = [ "stalwart.service" ];
      };

      # Cloudflare API token and account ID are declared by
      # modules/services/cloudflare-credentials.nix (my.cloudflare below)

      grafana-admin-password = {
        owner = "grafana";
      };
      grafana-secret-key = {
        owner = "grafana";
      };
      # Must be readable by unpoller's service user (reads via file:// at runtime)
      unpoller-password = {
        owner = "unifi-poller";
        mode = "0400";
        restartUnits = [ "unifi-poller.service" ]; # it reads the file only at startup
      };

      # Dead-man's switch ping URL (create a check at healthchecks.io, then:
      # sops set sops/secrets.yaml '["healthchecks-ping-url"]' '"https://hc-ping.com/<uuid>"')
      healthchecks-ping-url = { };

      # Cloudflare Tunnel: credentials JSON (binary format, separate sops file)
      cloudflared-tunnel-credentials = {
        sopsFile = lib.my.relativeToRoot "sops/cloudflared-tunnel.json";
        format = "binary";
        mode = "0400";
      };
    };
  };

  # Minimal hardware config for headless router
  hardware = {
    enableRedistributableFirmware = true;
    # Bluetooth disabled - not needed for router
    bluetooth.enable = false;
  };
}
