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

    # User setup
    pperanich

    # Router functionality
    router

    # Development environment
    rust

    # System utilities
    fileExploration
    networkUtilities

    # Virtualization (useful for mini PC/home server use)
    # docker
    # qemu
  ]);

  nixpkgs.hostPlatform = "x86_64-linux";
  clan.core.networking.targetHost = lib.mkForce "root@10.0.0.1";
  # clan.core.networking.targetHost = lib.mkForce "root@192.168.0.149";
  # clan.core.networking.buildHost = "root@192.168.0.184";

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

  # Open HTTPS for Caddy on LAN (WireGuard is already trusted)
  # Injected into the router firewall's input chain via _internal
  networking.nftables.tables.filterV4.content = lib.mkAfter ''
    chain caddy-input {
      type filter hook input priority -1; policy accept;
      iifname "br-lan" tcp dport 443 accept comment "Caddy HTTPS from LAN"
    }
  '';
  networking.nftables.tables.filterV6.content = lib.mkAfter ''
    chain caddy-input {
      type filter hook input priority -1; policy accept;
      iifname "br-lan" tcp dport 443 accept comment "Caddy HTTPS from LAN"
    }
  '';

  # Caddy reverse proxy for internal services
  # Provides HTTPS via Cloudflare DNS challenge — no public ports exposed
  # Access from LAN (10.0.0.1) and WireGuard VPN
  #
  # Prerequisites:
  #   1. Add cloudflare_api_token to sops/secrets.yaml (Zone:DNS:Edit permission)
  #   2. Build once to get correct Caddy plugin hash (set hash = "" to trigger)
  #
  # Manual Cloudflare DNS records (set once, proxy OFF):
  #   ntopng.prestonperanich.com  → A: 10.0.0.1    AAAA: <wgAddress>
  #   unifi.prestonperanich.com   → A: 10.0.0.1    AAAA: <wgAddress>
  # These point to private IPs — unreachable from the public internet.
  # When adding a new virtualHost below, create matching DNS records.
  sops.secrets.cloudflare-api-token = { };

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
    };
  };

  # External WireGuard peers (non-clan devices)
  # These merge with clan-managed peers in the systemd-networkd .netdev file
  # Phone configs + QR codes: see /tmp/wg-phones/ on the build host
  systemd.network.netdevs."40-pp-wg".wireguardPeers = [
    {
      # Phone 1 (Preston's iPhone)
      PublicKey = "As57FlqVRVhD9E4sKQ+f+5IvaHOOOYDRA4Pe49d8uHU=";
      AllowedIPs = [ "${wgPrefix}::f001/128" ];
      PersistentKeepalive = 25;
    }
    {
      # Phone 2
      PublicKey = "rdwhOOvOQpznSQIE1frgksRjgE+8hTyx28TgIxI7LwM=";
      AllowedIPs = [ "${wgPrefix}::f002/128" ];
      PersistentKeepalive = 25;
    }
  ];

  # Add phone hostnames for convenience
  networking.extraHosts = ''
    ${wgPrefix}::f001 phone1.pp-wg
    ${wgPrefix}::f002 phone2.pp-wg
  '';

  # Minimal hardware config for headless router
  hardware = {
    enableRedistributableFirmware = true;
    # Bluetooth disabled - not needed for router
    bluetooth.enable = false;
  };
}
