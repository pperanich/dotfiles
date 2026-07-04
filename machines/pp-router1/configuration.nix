{
  inputs,
  config,
  modules,
  pkgs,
  lib,
  ...
}:
let
  # WireGuard controller IPv6 address (derived from clan-managed prefix)
  wgPrefix = config.clan.core.vars.generators.wireguard-network-pp-wg.files.prefix.value;
  wgAddress = "${wgPrefix}::1";
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

    # User setup (headless — no desktop apps/fonts)
    pperanich

    # Router functionality
    router

    # Disk health (local NVMe)
    smartMonitoring

    # Cloudflare DNS sync
    cloudflareDns

    # Caddy + DNS-01 certificates (vhosts in ./caddy.nix)
    caddyDns01

    # Public services (via Cloudflare Tunnel)
    cloudflareTunnel
    vaultwarden
    gitea
    observability

    # Outbound transactional email
    stalwart

    # Development environment
    rust
  ]);

  my.pperanich.desktop = false;

  # Vaultwarden password manager
  my.vaultwarden = {
    enable = true;
    domain = mkSub "vault";
    adminTokenFile = config.sops.secrets.vaultwarden-admin-token.path;
    smtpFrom = "vault@${publicDomain}";
  };

  # Gitea — self-hosted git over LAN + WireGuard
  my.gitea = {
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
  my.stalwart = {
    enable = true;
    hostname = mkSub "mail";
    relayCredentialFile = config.sops.secrets.resend-api-key.path;
  };

  my.observability = {
    enable = true;
    grafana.hostname = mkSub "grafana";
    blackbox.httpTargets = [
      "https://${config.my.observability.grafana.hostname}"
      "https://${mkSub "home"}"
      "https://${config.my.vaultwarden.domain}"
      # End-to-end probe of the public site through the Cloudflare tunnel
      "https://${publicDomain}"
      # Resolves to the NAS via split-horizon — covers the NAS Caddy's
      # independent cert renewal via CertExpiringSoon
      "https://${mkSub "jellyfin"}"
    ];
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
      externalUrl = "https://${mkSub "alerts"}";
      # 10G trunk to the switch — carrier loss here takes down the whole LAN
      carrierInterfaces = [ "enp1s0f1np1" ];
      deadman.pingUrlFile = config.sops.secrets.healthchecks-ping-url.path;
    };
    smartctlTargets = [
      "127.0.0.1:9633"
      "pp-nas1.home.arpa:9633"
    ];
    nodeTargets = [ "pp-nas1.home.arpa:9640" ];
  };

  my.smartMonitoring.enable = true;

  # Cloudflare Tunnel — public service exposure without opening WAN ports
  # tunnelId read from cf-tunnel.json (written by: cf tunnel sync --name homelab --apply)
  my.cloudflareTunnel =
    let
      tunnelMeta = builtins.fromJSON (builtins.readFile ./cf-tunnel.json);
    in
    {
      enable = true;
      inherit (tunnelMeta) tunnelId tunnelName;
      zone = publicDomain;
      credentialsFile = config.sops.secrets.cloudflared-tunnel-credentials.path;
      environmentFile = config.sops.templates."cf-dns.env".path;
      ingress = {
        "${publicDomain}" = "http://localhost:8224"; # Personal site
        "${mkSub "www"}" = "http://localhost:8224"; # Redirect to apex
        "${mkSub "vault"}" = "http://localhost:8223"; # Caddy tunnel listener (blocks /admin)
      };
    };

  nixpkgs.hostPlatform = "x86_64-linux";
  clan.core.networking.targetHost = lib.mkForce "root@pp-router1.home.arpa";
  # clan.core.networking.targetHost = lib.mkForce "root@pp-router1";
  clan.core.networking.buildHost = "root@pp-wsl1.home.arpa";

  # Networking configuration
  networking.hostName = "pp-router1";

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
  };

  services.irqbalance.enable = true;
  systemd.services."serial-getty@ttyS0".enable = true;

  # 10G trunk dropped carrier (2026-07-03) and needed a power cycle: bounce
  # link at 30s down, rebind PCI function at 90s (equivalent of NIC reset).
  systemd.services.trunk-link-watchdog = {
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

  # Router configuration
  my.router = {
    enable = true;

    # WireGuard VPN: open UDP port on WAN and trust the tunnel interface
    firewall = {
      openPorts.udp = [ 51820 ];
      trustedInterfaces = [ "pp-wg" ];
      hairpinNat.enable = true;
      # Open HTTPS for Caddy on LAN (WireGuard is already trusted via @trusted_ifaces)
      extraInputRules = ''
        iifname "br-main" tcp dport 443 accept comment "Caddy HTTPS from LAN"
        iifname "br-main" tcp dport 631 accept comment "CUPS IPP from LAN"
      '';
      extraInputRulesV6 = ''
        iifname "br-main" tcp dport 443 accept comment "Caddy HTTPS from LAN"
        iifname "br-main" tcp dport 631 accept comment "CUPS IPP from LAN"
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
    dns.enable = true;
    dns.privateDomains = [ publicDomain ]; # Allow private IP responses for Caddy subdomains
    dns.extraInterfaces = [ wgAddress ]; # Serve DNS to WireGuard VPN clients
    dns.extraAccessControl = [ "${wgPrefix}::/40 allow" ]; # Allow queries from WireGuard subnet
    dns.ddns.enable = true; # Auto-register DHCP client hostnames in DNS
    dns.extraLocalData = [
      # WSL mirrored networking shares the Windows host's IP
      "pp-wsl1.${domain}. CNAME pp-wd1.${domain}."
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
      "hass"
    ];

    # Clients search home.arpa (LAN hosts via DDNS) then pp-wg (WireGuard
    # overlay, served from /etc/hosts by blocky below)
    dhcp.searchDomains = [
      config.my.router.dhcp.domainName
      "pp-wg"
    ];

    # DNS ad-blocking via Blocky (sits in front of Unbound on port 53)
    # Unbound retreats to localhost:5335 as DNSSEC/DoT backend
    blocky = {
      enable = true;
      # Serve /etc/hosts over DNS: *.pp-wg peer names (clan fleet + external
      # peers) become resolvable by every LAN/VPN client, not just this host
      extraSettings.hostsFile = {
        sources = [ "/etc/hosts" ];
        hostsTTL = "5m";
        loading.refreshPeriod = "5m";
        # Never serve loopback entries (e.g. clan's "127.0.0.2 pp-router1")
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

  # SSH hardening for router
  services.openssh.settings = {
    X11Forwarding = false;
    PermitRootLogin = "prohibit-password"; # Key-only root access
    PasswordAuthentication = false; # Disable password auth entirely
    KbdInteractiveAuthentication = false; # Disable keyboard-interactive
    MaxAuthTries = 3;
    LoginGraceTime = 20;
    ClientAliveInterval = 300;
    ClientAliveCountMax = 2;
    MaxStartups = "10:30:60"; # Rate limit: start:rate:full
  };

  # --- Secrets wiring (sops-nix) ---
  # Vaultwarden: admin token for /admin panel
  sops.secrets.vaultwarden-admin-token = {
    owner = "vaultwarden";
    mode = "0400";
  };

  # Gitea: initial admin password (consumed by gitea-admin-bootstrap.service)
  sops.secrets.gitea-admin-password = {
    owner = "git";
    mode = "0400";
  };

  # Resend: API key for SMTP relay
  sops.secrets.resend-api-key = {
    # stalwart stateVersion 26.05 renamed the service user stalwart-mail -> stalwart
    owner = "stalwart";
    mode = "0400";
  };

  # Cloudflare API token (used by cf-dns, cf-tunnel, and caddy templates)
  sops.secrets.cloudflare-api-token = { };

  # Cloudflare account ID (used by cf-tunnel sync)
  sops.secrets.cloudflare-account-id = { };

  sops.secrets.grafana-admin-password = {
    owner = "grafana";
  };
  sops.secrets.grafana-secret-key = {
    owner = "grafana";
  };
  # Must be readable by unpoller's service user (reads via file:// at runtime)
  sops.secrets.unpoller-password = {
    owner = "unifi-poller";
    mode = "0400";
  };

  # Dead-man's switch ping URL (create a check at healthchecks.io, then:
  # sops set sops/secrets.yaml '["healthchecks-ping-url"]' '"https://hc-ping.com/<uuid>"')
  sops.secrets.healthchecks-ping-url = { };

  # Cloudflare Tunnel: credentials JSON (binary format, separate sops file)
  sops.secrets.cloudflared-tunnel-credentials = {
    sopsFile = lib.my.relativeToRoot "sops/cloudflared-tunnel.json";
    format = "binary";
    mode = "0400";
  };

  # Cloudflare DNS sync: API token env file
  sops.templates."cf-dns.env" = {
    content = ''
      CLOUDFLARE_API_TOKEN=${config.sops.placeholder."cloudflare-api-token"}
      CLOUDFLARE_ACCOUNT_ID=${config.sops.placeholder."cloudflare-account-id"}
    '';
  };
  my.cloudflareDns.environmentFile = config.sops.templates."cf-dns.env".path;

  # External WireGuard peers (non-clan devices like phones, tablets)
  # Managed via wg-external-peers.json — use `wg-add-peer` in devshell to add new devices
  # Private keys stored in sops/secrets.yaml, configs saved to docs/wireguard/
  systemd.network.netdevs."40-pp-wg".wireguardPeers =
    let
      peers = builtins.fromJSON (builtins.readFile ./wg-external-peers.json);
    in
    lib.mapAttrsToList (_name: peer: {
      PublicKey = peer.publicKey;
      AllowedIPs = [ "${wgPrefix}::${peer.addressSuffix}/128" ];
      PersistentKeepalive = 25;
    }) peers;

  # Hostnames for external WireGuard peers
  networking.extraHosts =
    let
      peers = builtins.fromJSON (builtins.readFile ./wg-external-peers.json);
    in
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: peer: "${wgPrefix}::${peer.addressSuffix} ${name}.pp-wg") peers
    );

  # Minimal hardware config for headless router
  hardware = {
    enableRedistributableFirmware = true;
    # Bluetooth disabled - not needed for router
    bluetooth.enable = false;
  };
}
