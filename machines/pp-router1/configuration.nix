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
  # clan.core.networking.targetHost = lib.mkForce "root@10.0.0.1";
  clan.core.networking.targetHost = lib.mkForce "root@192.168.0.149";
  clan.core.networking.buildHost = "root@192.168.0.184";

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

    # Network interfaces
    wan.interface = "enp1s0f0np0"; # SFP+ port 0
    lan = {
      interface = "enp4s0";
      interfaces = [
        "enp4s0"
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
    networks = {
      enable = true;
      segments = {
        # Main network - no VLAN tag, uses primary LAN subnet
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

    # Debug uplink for SSH access during development (disable for production)
    # Automatically adds interface to firewall.trustedInterfaces
    debugUplink = {
      enable = true;
      interface = "enp2s0";
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

  # Minimal hardware config for headless router
  hardware = {
    enableRedistributableFirmware = true;
    # Bluetooth disabled - not needed for router
    bluetooth.enable = false;
  };
}
