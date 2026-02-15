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
  domain = config.features.router.dhcp.domainName;
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
    cfDns

    # Development environment
    rust

    # System utilities
    fileExploration
    networkUtilities

    # Virtualization (useful for mini PC/home server use)
    # docker
    # qemu
  ]);

  features.pperanich.desktop = false;

  nixpkgs.hostPlatform = "x86_64-linux";
  clan.core.networking.targetHost = lib.mkForce "root@pp-router.pp-wg";
  # clan.core.networking.buildHost = "root@pp-wsl1.pp-wg";

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
  features.router = {
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
    ];
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
  services.cf-dns = {
    enable = true;
    zone = "prestonperanich.com";
    records = [
      # ntopng — network monitoring
      {
        type = "A";
        name = "ntopng.prestonperanich.com";
        content = "10.0.0.1";
      }
      {
        type = "AAAA";
        name = "ntopng.prestonperanich.com";
        content = wgAddress;
      }
      # unifi — Ubiquiti controller
      {
        type = "A";
        name = "unifi.prestonperanich.com";
        content = "10.0.0.1";
      }
      {
        type = "AAAA";
        name = "unifi.prestonperanich.com";
        content = wgAddress;
      }
      # immich — photo/video management on pp-nas1
      {
        type = "A";
        name = "immich.prestonperanich.com";
        content = "10.0.0.1";
      }
      {
        type = "AAAA";
        name = "immich.prestonperanich.com";
        content = wgAddress;
      }
      # nextcloud — file sync & collaboration on pp-nas1
      {
        type = "A";
        name = "nextcloud.prestonperanich.com";
        content = "10.0.0.1";
      }
      {
        type = "AAAA";
        name = "nextcloud.prestonperanich.com";
        content = wgAddress;
      }
      # opencloud — file sync on pp-nas1 (trial alongside nextcloud)
      {
        type = "A";
        name = "opencloud.prestonperanich.com";
        content = "10.0.0.1";
      }
      {
        type = "AAAA";
        name = "opencloud.prestonperanich.com";
        content = wgAddress;
      }
      # home — dashboard on pp-router1
      {
        type = "A";
        name = "home.prestonperanich.com";
        content = "10.0.0.1";
      }
      {
        type = "AAAA";
        name = "home.prestonperanich.com";
        content = wgAddress;
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
        Services = {
          style = "row";
          columns = 3;
        };
      };
    };
    services = [
      {
        "Network" = [
          {
            "Unifi" = {
              icon = "unifi";
              href = "https://unifi.prestonperanich.com";
              description = "Network controller";
            };
          }
          {
            "ntopng" = {
              icon = "ntopng";
              href = "https://ntopng.prestonperanich.com";
              description = "Network monitoring";
            };
          }
        ];
      }
      {
        "Services" = [
          {
            "Immich" = {
              icon = "immich";
              href = "https://immich.prestonperanich.com";
              description = "Photo & video backup";
            };
          }
          {
            "Nextcloud" = {
              icon = "nextcloud";
              href = "https://nextcloud.prestonperanich.com";
              description = "File sync & collaboration";
            };
          }
          {
            "OpenCloud" = {
              icon = "open-cloud";
              href = "https://opencloud.prestonperanich.com";
              description = "File sync (trial)";
            };
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
  # DNS records are managed declaratively above via services.cf-dns.
  # When adding a new virtualHost below, add matching records above.

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
      hash = "sha256-dnhEjopeA0UiI+XVYHYpsjcEI6Y1Hacbi28hVKYQURg="; # Build once to get correct hash — nix will print it on failure
    };

    environmentFile = config.sops.templates."caddy.env".path;

    globalConfig = ''
      acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
    '';

    virtualHosts = {
      # Homepage dashboard (runs on this router)
      "home.prestonperanich.com" = {
        listenAddresses = [
          "10.0.0.1"
          wgAddress # WireGuard VPN
        ];
        extraConfig = ''
          reverse_proxy localhost:8082
        '';
      };

      "ntopng.prestonperanich.com" = {
        listenAddresses = [
          "10.0.0.1"
          wgAddress # WireGuard VPN
        ];
        extraConfig = ''
          reverse_proxy localhost:3000
        '';
      };

      "unifi.prestonperanich.com" = {
        listenAddresses = [
          "10.0.0.1"
          wgAddress # WireGuard VPN
        ];
        extraConfig = ''
          reverse_proxy https://localhost:8443 {
            transport http {
              tls_insecure_skip_verify
            }
          }
        '';
      };

      # Immich — photo/video management on pp-nas1
      "immich.prestonperanich.com" = {
        listenAddresses = [
          "10.0.0.1"
          wgAddress # WireGuard VPN
        ];
        extraConfig = ''
          reverse_proxy http://10.0.0.106:2283 {
            # Large photo/video uploads
            header_up X-Forwarded-Proto {scheme}
          }
          request_body {
            max_size 50G
          }
        '';
      };

      # Nextcloud — file sync & collaboration on pp-nas1
      "nextcloud.prestonperanich.com" = {
        listenAddresses = [
          "10.0.0.1"
          wgAddress # WireGuard VPN
        ];
        extraConfig = ''
          reverse_proxy http://10.0.0.106:80 {
            header_up X-Forwarded-Proto {scheme}
            header_up X-Forwarded-For {remote_host}
          }
          request_body {
            max_size 16G
          }
        '';
      };

      # OpenCloud — file sync trial on pp-nas1
      "opencloud.prestonperanich.com" = {
        listenAddresses = [
          "10.0.0.1"
          wgAddress # WireGuard VPN
        ];
        extraConfig = ''
          reverse_proxy http://10.0.0.106:9200 {
            header_up X-Forwarded-Proto {scheme}
          }
          request_body {
            max_size 16G
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
