{
  inputs,
  modules,
  pkgs,
  lib,
  config,
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
  clan.core.networking.targetHost = lib.mkForce "root@192.168.0.233";
  clan.core.networking.buildHost = "root@192.168.0.184";

  # Networking configuration
  networking.hostName = "pp-router1";

  # Router configuration
  features.router = {
    enable = true;
    hostname = "pp-router1";

    # Network interfaces
    wan.interface = "enp2s0";
    lan = {
      # Use bridge mode to combine wired LAN + WiFi
      interface = "enp5s0"; # Primary wired LAN interface
      interfaces = [
        "enp5s0" # Wired LAN
        "wlan0" # 2.4GHz WiFi
        "wlp4s0" # 5GHz WiFi
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

    # WiFi Access Point configuration
    hostapd = {
      enable = true;
      countryCode = "US";

      # Enable fast roaming for future multi-AP setup
      roaming = {
        enable = true;
        mobilityDomain = "a1b2"; # Must be same across all APs
        ieee80211k = true; # Radio Resource Management
        ieee80211v = true; # BSS Transition Management
      };

      radios = {
        # 2.4GHz radio - better range, slower speeds
        radio24 = {
          interface = "wlan0";
          band = "2.4GHz";
          ssid = "VirusInfectedWifi";
          wpaPassphraseFile = config.sops.secrets.wifi_passphrase.path;
          wpaKeyMgmt = "SAE WPA-PSK"; # WPA3 + WPA2 transition mode
          channel = 6; # Common 2.4GHz channel
          bridge = "br-lan";
          ieee80211n = true;
          htCapab = "[HT40+][SHORT-GI-40]";
        };

        # 5GHz radio - shorter range, faster speeds
        radio5 = {
          interface = "wlp4s0";
          band = "5GHz";
          ssid = "VirusInfectedWifi"; # Same SSID for seamless roaming
          wpaPassphraseFile = config.sops.secrets.wifi_passphrase.path;
          wpaKeyMgmt = "SAE WPA-PSK"; # WPA3 + WPA2 transition mode
          channel = 36; # DFS-free channel
          bridge = "br-lan";
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

  services = {
    # Enable the login manager
    displayManager.cosmic-greeter.enable = true;
    # Enable the COSMIC DE itself
    desktopManager.cosmic.enable = true;
    # Enable XWayland support in COSMIC
    desktopManager.cosmic.xwayland.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };

  security = {
    polkit.enable = true;
  };

  hardware = {
    enableRedistributableFirmware = true;
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      package = pkgs.bluez;
    };
    graphics = {
      enable = true;
      enable32Bit = true;

      extraPackages = with pkgs; [
        intel-vaapi-driver
        libvdpau-va-gl
        libva-vdpau-driver
        intel-media-driver
      ];
    };
  };

  # Allow unfree packages (needed for some firmware)
  nixpkgs.config.allowUnfree = true;

  # Package configuration
  environment.systemPackages = with pkgs; [
    # Basic system utilities
    wget
    git
    htop
    neofetch

    # IDE
    code-cursor

    # Graphics drivers
    mesa
    vulkan-loader
    vulkan-tools

    # Firmware updates
    fwupd
    linux-firmware

    ghostty

    stdenv
  ];

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    audio.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = true;
  };
}
