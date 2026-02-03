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
  # clan.core.networking.targetHost = lib.mkForce "root@10.0.0.1";
  clan.core.networking.targetHost = lib.mkForce "root@192.168.0.149";
  # clan.core.networking.buildHost = "root@10.0.0.1";

  # Networking configuration
  networking.hostName = "pp-router1";

  # Serial console for debugging (ttyS0 at 115200 baud, 8N1)
  # PCIe ASPM disabled for MT7915 performance (research shows latency issues with default policy)
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS0,115200n8"
    "pcie_aspm=off" # Disable ASPM entirely for WiFi performance
  ];

  # IRQ balancing - distributes MT7915 interrupts across all CPU cores
  # Without this, all 3.6M+ IRQs go to a single core (CPU3), causing bottleneck
  services.irqbalance.enable = true;
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

    # Network interfaces - using SFP+ ports for router functionality
    wan.interface = "enp2s0"; # 10GbE SFP+ port 0
    lan = {
      interface = "enp1s0f1np1";
      interfaces = [
        "enp1s0f1np1"
        wifi.radio24.name
        wifi.radio5.name
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
      interface = "enp5s0";
    };

    # WiFi Access Point - SSIDs auto-generated from networks.segments
    hostapd = {
      enable = true;
      useNetworks = true;

      roaming = {
        enable = true;
        bandSteering.enable = true;
      };

      radios = {
        # 2.4GHz - 20MHz only (congested), ax disabled (Apple compatibility)
        radio24 = {
          interface = wifi.radio24.name;
          band = "2.4GHz";
          channel = 0;
          ieee80211ax = false;
          htCapab = "[LDPC][SHORT-GI-20][TX-STBC][RX-STBC1][MAX-AMSDU-7935]";
        };

        # 5GHz - WiFi 6, 80MHz
        radio5 = {
          interface = wifi.radio5.name;
          band = "5GHz";
          channel = 0; # ACS
          ieee80211ac = true;
          ieee80211ax = true;
          # MT7915E capabilities
          htCapab = "[LDPC][HT40+][HT40-][SHORT-GI-20][SHORT-GI-40][TX-STBC][RX-STBC1][MAX-AMSDU-7935]";
          vhtCapab = "[RXLDPC][SHORT-GI-80][TX-STBC-2BY1][SU-BEAMFORMER][SU-BEAMFORMEE][RX-STBC-1][MAX-MPDU-11454][MAX-A-MPDU-LEN-EXP7]";
        };
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

    # WiFi debugging
    iw
    hostapd

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
