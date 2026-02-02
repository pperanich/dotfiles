{
  inputs,
  modules,
  pkgs,
  lib,
  ...
}:
let
  # WiFi hardware configuration for mt7915e dual-band card
  # MAC addresses from: /sys/class/net/<iface>/address
  # Note: facter.json only stores first byte of MAC (known limitation)
  wifi = {
    radio24 = {
      mac = "00:0a:52:09:61:ce"; # phy0 - 2.4GHz band
      name = "wlan24";
    };
    radio5 = {
      mac = "00:0a:52:09:61:cf"; # phy1 - 5GHz band
      name = "wlan5";
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
  clan.core.networking.targetHost = lib.mkForce "root@192.168.0.152";
  clan.core.networking.buildHost = "root@192.168.0.184";

  # Networking configuration
  networking.hostName = "pp-router1";

  # Serial console for debugging (ttyS0 at 115200 baud, 8N1)
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS0,115200n8"
  ];
  systemd.services."serial-getty@ttyS0".enable = true;

  # Stable WiFi interface names using MAC addresses
  # mt7915e creates two interfaces on the same PCI device, NixOS only auto-renames one
  systemd.network.links = {
    "10-wlan24" = {
      matchConfig.MACAddress = wifi.radio24.mac;
      linkConfig.Name = wifi.radio24.name;
    };
    "10-wlan5" = {
      matchConfig.MACAddress = wifi.radio5.mac;
      linkConfig.Name = wifi.radio5.name;
    };
  };

  # Router configuration
  features.router = {
    enable = true;
    hostname = "pp-router1";

    # Network interfaces - using SFP+ ports for router functionality
    wan.interface = "enp1s0f0np0"; # 10GbE SFP+ port 0
    lan = {
      interface = "enp1s0f1np1"; # 10GbE SFP+ port 1
      interfaces = [
        "enp1s0f1np1" # Wired LAN (SFP+)
        wifi.radio24.name # 2.4GHz WiFi
        wifi.radio5.name # 5GHz WiFi
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

    # Unified network segmentation (VLAN + WiFi)
    # Each network segment gets its own VLAN, subnet, and WiFi SSID
    networks = {
      enable = true;
      segments = {
        # Main network - no VLAN tag, uses primary LAN subnet
        main = {
          subnet = "10.0.0";
          isolation = "none"; # Full access to everything
          wifi = {
            enable = true;
            ssid = "PP-Net";
            security = "wpa3-transition"; # WPA3 + WPA2 compatibility
            passwordSecret = "wifi_passphrase";
          };
        };
        # IoT network - isolated with controlled access
        iot = {
          vlan = 20;
          subnet = "10.0.20";
          isolation = "internet"; # Internet only, no inter-VLAN
          allowAccessFrom = [ "main" ]; # Main network can access IoT devices
          wifi = {
            enable = true;
            ssid = "PP-IoT";
            security = "wpa2"; # WPA2 for IoT device compatibility
            passwordSecret = "wifi_passphrase_iot";
          };
        };
        # Guest network - fully isolated
        guest = {
          vlan = 30;
          subnet = "10.0.30";
          isolation = "full"; # Internet only, no inter-network access
          wifi = {
            enable = true;
            ssid = "PP-Guest";
            security = "wpa2"; # WPA2 for guest device compatibility
            passwordSecret = "wifi_passphrase_guest";
            clientIsolation = true; # Prevent guests from seeing each other
          };
        };
      };
    };

    # Debug uplink for SSH access during development (disable for production)
    # Automatically adds interface to firewall.trustedInterfaces
    debugUplink = {
      enable = true;
      interface = "enp2s0";
    };

    # WiFi Access Point configuration
    # SSID/bridge/additionalBSS are auto-generated from networks.segments
    hostapd = {
      enable = true;
      useNetworks = true; # Auto-configure from networks.segments with wifi.enable
      countryCode = "US";

      # Fast roaming (802.11r/k/v) for seamless handoff between radios
      roaming = {
        enable = true;
        mobilityDomain = "a1b2"; # Must be same across all APs
        ieee80211k = true; # Radio Resource Management (neighbor reports)
        ieee80211v = true; # BSS Transition Management
      };

      # Radios only need hardware-specific settings now
      # SSID, bridge, and additionalBSS are auto-populated from networks
      radios = {
        # 2.4GHz radio - better range, slower speeds
        radio24 = {
          interface = wifi.radio24.name;
          band = "2.4GHz";
          channel = 6; # Common 2.4GHz channel
          ieee80211n = true;
          htCapab = "[HT40+][SHORT-GI-40]";
        };

        # 5GHz radio - shorter range, faster speeds
        radio5 = {
          interface = wifi.radio5.name;
          band = "5GHz";
          channel = 36; # DFS-free channel
          ieee80211n = true;
          ieee80211ac = true; # Wi-Fi 5
          ieee80211ax = true; # Wi-Fi 6
          vhtOperChwidth = 1; # 80MHz channel width
          vhtOperCentrFreqSeg0Idx = 42; # Center frequency for 80MHz
        };
      };
    };

    # Static IP reservations (customize as needed)
    machines = [
      # {
      #   name = "desktop";
      #   ip = 10;
      #   mac = "AA:BB:CC:DD:EE:FF";
      #   portForwards = [
      #     { port = 22; protocol = "tcp"; }
      #   ];
      # }
    ];
  };

  # Router-appropriate packages (no desktop environment)
  environment.systemPackages = with pkgs; [
    # System utilities
    wget
    git
    htop
    btop
    neofetch

    # Network debugging
    tcpdump
    iperf3
    mtr
    nmap
    ethtool

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
