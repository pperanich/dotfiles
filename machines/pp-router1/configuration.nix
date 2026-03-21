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
  routerIp = config.my.router.lan.address;
  nasHost = "pp-nas1.${config.my.router.dhcp.domainName}";
  domain = config.my.router.dhcp.domainName;

  # Generate A + AAAA record pairs pointing subdomains to the router (LAN + WireGuard)
  mkDnsRecords =
    subdomains:
    lib.concatMap (sub: [
      {
        type = "A";
        name = "${sub}.prestonperanich.com";
        content = routerIp;
      }
      {
        type = "AAAA";
        name = "${sub}.prestonperanich.com";
        content = wgAddress;
      }
    ]) subdomains;

  # Caddy vhost listening on LAN + WireGuard with custom config
  mkVhost = extraConfig: {
    listenAddresses = [
      routerIp
      wgAddress
    ];
    inherit extraConfig;
  };

  # Simple reverse proxy vhost (LAN + WireGuard)
  mkProxy =
    backend:
    mkVhost ''
      reverse_proxy ${backend}
    '';

  # Homepage dashboard service entry
  mkDashboardService =
    {
      name,
      icon,
      sub,
      desc,
      path ? "",
    }:
    {
      ${name} = {
        inherit icon;
        href = "https://${sub}.prestonperanich.com${path}";
        description = desc;
      };
    };
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

    # Router functionality
    router

    # Cloudflare DNS sync
    cloudflareDns

    # Public services (via Cloudflare Tunnel)
    cloudflareTunnel
    vaultwarden

    # Outbound transactional email
    stalwart

    # Development environment
    rust
  ]);

  my.pperanich.desktop = false;

  # Vaultwarden password manager
  my.vaultwarden = {
    enable = true;
    domain = "vault.prestonperanich.com";
    adminTokenFile = config.sops.secrets.vaultwarden-admin-token.path;
    smtpFrom = "vault@prestonperanich.com";
  };

  # Stalwart — outbound transactional email relay via Resend
  my.stalwart = {
    enable = true;
    hostname = "mail.prestonperanich.com";
    relayCredentialFile = config.sops.secrets.resend-api-key.path;
  };

  # Cloudflare Tunnel — public service exposure without opening WAN ports
  # tunnelId read from cf-tunnel.json (written by: cf tunnel sync --name homelab --apply)
  my.cloudflareTunnel =
    let
      tunnelMeta = builtins.fromJSON (builtins.readFile ./cf-tunnel.json);
    in
    {
      enable = true;
      inherit (tunnelMeta) tunnelId;
      credentialsFile = config.sops.secrets.cloudflared-tunnel-credentials.path;
      ingress = {
        "prestonperanich.com" = "http://localhost:8224"; # Personal site
        "www.prestonperanich.com" = "http://localhost:8224"; # Redirect to apex
        "vault.prestonperanich.com" = "http://localhost:8223"; # Caddy tunnel listener (blocks /admin)
      };
    };

  nixpkgs.hostPlatform = "x86_64-linux";
  clan.core.networking.targetHost = lib.mkForce "root@pp-router1.home.arpa";
  # clan.core.networking.targetHost = lib.mkForce "root@pp-router1";
  clan.core.networking.buildHost = "root@pp-wsl1.home.arpa";

  # Networking configuration
  networking.hostName = "pp-router1";

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
        iifname "br-lan" tcp dport 443 accept comment "Caddy HTTPS from LAN"
      '';
      extraInputRulesV6 = ''
        iifname "br-lan" tcp dport 443 accept comment "Caddy HTTPS from LAN"
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
    dns.privateDomains = [ "prestonperanich.com" ]; # Allow private IP responses for Caddy subdomains
    dns.extraInterfaces = [ wgAddress ]; # Serve DNS to WireGuard VPN clients
    dns.extraAccessControl = [ "${wgPrefix}::/40 allow" ]; # Allow queries from WireGuard subnet
    dns.ddns.enable = true; # Auto-register DHCP client hostnames in DNS
    dns.extraLocalData = [
      # WSL mirrored networking shares the Windows host's IP
      "pp-wsl1.${domain}. CNAME pp-wd1.${domain}."
      # vault served locally (public access via Cloudflare Tunnel CNAME)
      # "vault.prestonperanich.com. A ${routerIp}"
      # "vault.prestonperanich.com. AAAA ${wgAddress}"
      # vault-admin — internal only, no public DNS
    ];

    # DNS ad-blocking via Blocky (sits in front of Unbound on port 53)
    # Unbound retreats to localhost:5335 as DNSSEC/DoT backend
    blocky = {
      enable = true;
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

    mdns.enable = true; # Enables .local device discovery (AirPlay, Chromecast, printers)

    # Network monitoring with ntopng
    # Access at http://10.0.0.1:3000 (default: admin/admin)
    monitoring.enable = true;

    # Unifi controller for managing Ubiquiti access points
    # Access at https://10.0.0.1:8443
    unifi.enable = true;

    # Network segmentation with VLANs
    # WiFi handled by external Unifi AP connected via trunk port
    # Configure Unifi AP to tag traffic: Main=untagged, IoT=VLAN20, Guest=VLAN30
    # Note: Media VLAN removed — Chromecast SDK rejects devices on different subnets,
    # so TVs must be on the main LAN for casting to work. AirPlay works cross-VLAN
    # but Chromecast does not (Google's SDK enforces same-subnet check).
    networks = {
      enable = true;
      segments = {
        # Main network - no VLAN tag, uses primary LAN subnet
        # TVs and media devices live here for Chromecast compatibility
        main = {
          subnet = "10.0.0";
          isolation = "none"; # Full access to everything
        };
        # IoT network - isolated with controlled access
        iot = {
          vlan = 20;
          subnet = "10.0.20";
          isolation = "internet"; # Internet only, no inter-VLAN
          allowAccessFrom = [ "main" ]; # Main network can access IoT devices
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

  # Declarative Cloudflare DNS records for internal services
  # Records point to private IPs — unreachable from the public internet.
  # LAN clients resolve via Unbound (10.0.0.1), VPN clients via public DNS + WireGuard.
  # Synced every 12h via systemd timer. Manual: systemctl start cf-dns-sync
  my.cloudflareDns = {
    enable = true;
    zone = "prestonperanich.com";
    records =
      mkDnsRecords [
        "feedme" # temporary address for feedme backend
        "ntopng" # network monitoring
        "unifi" # Ubiquiti controller
        "immich" # photo/video management (pp-nas1)
        "nextcloud" # file sync & collaboration (pp-nas1)
        "opencloud" # file sync trial (pp-nas1)
        "jellyfin" # media server (pp-nas1)
        "navidrome" # music server (pp-nas1)
        "audiobookshelf" # audiobooks & podcasts (pp-nas1)
        "home" # dashboard (pp-router1)
        "vault-admin" # vaultwarden admin panel (pp-router1)
      ]
      ++ [
        # Mail deliverability (SPF + DKIM + DMARC)
        {
          type = "TXT";
          name = "prestonperanich.com";
          # TODO: Update with Resend-provided SPF after domain verification
          content = "v=spf1 include:_spf.resend.com ~all";
        }
        {
          type = "TXT";
          name = "_dmarc.prestonperanich.com";
          content = "v=DMARC1; p=none; rua=mailto:dmarc@prestonperanich.com";
        }
      ];
  };

  # Homepage dashboard — landing page for all internal services
  services.homepage-dashboard = {
    enable = true;
    # Internal-only — not exposed to WAN, Caddy handles access control
    allowedHosts = "*";
    settings = {
      title = "Homelab";
      favicon = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/homepage.png";
      headerStyle = "clean";
      layout = {
        Network = {
          style = "row";
          columns = 3;
        };
        Media = {
          style = "row";
          columns = 3;
        };
        Services = {
          style = "row";
          columns = 3;
        };
      };
    };
    services = [
      {
        "Network" = map mkDashboardService [
          {
            name = "Unifi";
            icon = "unifi";
            sub = "unifi";
            desc = "Network controller";
          }
          {
            name = "ntopng";
            icon = "ntopng";
            sub = "ntopng";
            desc = "Network monitoring";
          }
        ];
      }
      {
        "Media" = map mkDashboardService [
          {
            name = "Jellyfin";
            icon = "jellyfin";
            sub = "jellyfin";
            desc = "Movies, TV & music streaming";
          }
          {
            name = "Navidrome";
            icon = "navidrome";
            sub = "navidrome";
            desc = "Music server";
          }
          {
            name = "Audiobookshelf";
            icon = "audiobookshelf";
            sub = "audiobookshelf";
            desc = "Audiobooks & podcasts";
          }
        ];
      }
      {
        "Services" = map mkDashboardService [
          {
            name = "Immich";
            icon = "immich";
            sub = "immich";
            desc = "Photo & video backup";
          }
          {
            name = "Nextcloud";
            icon = "nextcloud";
            sub = "nextcloud";
            desc = "File sync & collaboration";
          }
          {
            name = "OpenCloud";
            icon = "open-cloud";
            sub = "opencloud";
            desc = "File sync";
          }
          {
            name = "Vaultwarden";
            icon = "vaultwarden";
            sub = "vault";
            desc = "Password manager";
          }
          {
            name = "Vaultwarden Admin";
            icon = "vaultwarden";
            sub = "vault-admin";
            path = "/admin";
            desc = "Admin panel (internal only)";
          }
        ];
      }
    ];
    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          disk = "/";
        };
      }
      {
        search = {
          provider = "duckduckgo";
          target = "_blank";
        };
      }
    ];
  };

  # Caddy reverse proxy for internal services
  # Provides HTTPS via Cloudflare DNS challenge — no public ports exposed
  # Access from LAN (10.0.0.1) and WireGuard VPN
  #
  # Prerequisites:
  #   1. Add cloudflare_api_token to sops/secrets.yaml (Zone:DNS:Edit + Zone:Zone:Read)
  #   2. Build once to get correct Caddy plugin hash (set hash = "" to trigger)
  #
  # DNS records are managed declaratively above via my.cloudflareDns.
  # When adding a new virtualHost below, add matching records above.

  # --- Secrets wiring (sops-nix) ---
  # Vaultwarden: admin token for /admin panel
  sops.secrets.vaultwarden-admin-token = {
    owner = "vaultwarden";
    mode = "0400";
  };

  # Resend: API key for SMTP relay
  sops.secrets.resend-api-key = {
    owner = "stalwart-mail";
    mode = "0400";
  };

  # Cloudflare API token (used by cf-dns and caddy templates)
  sops.secrets.cloudflare-api-token = { };

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
    '';
  };
  my.cloudflareDns.environmentFile = config.sops.templates."cf-dns.env".path;

  # Caddy: Cloudflare API token for DNS challenge
  sops.templates."caddy.env" = {
    content = ''
      CLOUDFLARE_API_TOKEN=${config.sops.placeholder."cloudflare-api-token"}
    '';
    owner = "caddy";
  };

  services.caddy = {
    enable = true;

    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.2" ];
      hash = "sha256-Gb1nC5fZfj7IodQmKmEPGygIHNYhKWV1L0JJiqnVtbs="; # Build once to get correct hash — nix will print it on failure
    };

    environmentFile = config.sops.templates."caddy.env".path;

    globalConfig = ''
      acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
    '';

    virtualHosts = {
      # --- Personal site (static, built by bun2nix) ---
      "prestonperanich.com" = mkVhost ''
        root * ${pkgs.personal-site}
        file_server
      '';
      "www.prestonperanich.com" = mkVhost ''
        redir https://prestonperanich.com{uri} permanent
      '';

      "feedme.prestonperanich.com" = mkVhost ''
        reverse_proxy http://pp-ml1.${config.my.router.dhcp.domainName}:3000 {
          header_up X-Forwarded-Proto {scheme}
        }
        request_body {
          max_size 16G
        }
      '';

      # --- Simple reverse proxies (router-local services) ---
      "home.prestonperanich.com" = mkProxy "localhost:8082";
      "ntopng.prestonperanich.com" = mkProxy "localhost:3000";
      "vault.prestonperanich.com" = mkProxy "localhost:${toString config.my.vaultwarden.port}";
      "vault-admin.prestonperanich.com" = mkProxy "localhost:${toString config.my.vaultwarden.port}";

      # Unifi controller (self-signed cert)
      "unifi.prestonperanich.com" = mkVhost ''
        reverse_proxy https://localhost:8443 {
          transport http {
            tls_insecure_skip_verify
          }
        }
      '';

      # --- NAS services (pp-nas1) with upload limits ---
      "immich.prestonperanich.com" = mkVhost ''
        reverse_proxy http://${nasHost}:2283 {
          header_up X-Forwarded-Proto {scheme}
        }
        request_body {
          max_size 50G
        }
      '';

      "nextcloud.prestonperanich.com" = mkVhost ''
        reverse_proxy http://${nasHost}:80 {
          header_up X-Forwarded-Proto {scheme}
          header_up X-Forwarded-For {remote_host}
        }
        request_body {
          max_size 16G
        }
      '';

      "opencloud.prestonperanich.com" = mkVhost ''
        reverse_proxy http://${nasHost}:9200 {
          header_up X-Forwarded-Proto {scheme}
        }
        request_body {
          max_size 16G
        }
      '';

      # --- Cloudflare Tunnel listeners (localhost only) ---
      # Personal site (public via tunnel)
      "http://:8224" = {
        listenAddresses = [ "127.0.0.1" ];
        extraConfig = ''
          root * ${pkgs.personal-site}
          file_server
        '';
      };

      # Vaultwarden (public via tunnel, blocks /admin)
      "http://:8223" = {
        listenAddresses = [ "127.0.0.1" ];
        extraConfig = ''
          # Block /admin from public access (Cloudflare Tunnel)
          handle /admin* {
            respond "Forbidden" 403
          }
          handle {
            reverse_proxy localhost:${toString config.my.vaultwarden.port}
          }
        '';
      };
    };
  };

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
