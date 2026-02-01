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

  # Serial console for debugging (ttyS0 at 115200 baud, 8N1)
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS0,115200n8"
  ];
  systemd.services."serial-getty@ttyS0".enable = true;

  # Debug uplink - DHCP client to existing router for SSH access during development
  # Must use systemd.network since router module enables networkd
  systemd.network.networks."05-debug-uplink" = {
    matchConfig.Name = "enp2s0";
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = true;
    };
    dhcpV4Config = {
      UseDNS = false; # Don't override router's DNS config
      RouteMetric = 1024; # Higher metric = lower priority than WAN (default ~100)
    };
    linkConfig.RequiredForOnline = "no"; # Don't block boot if unplugged
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

    # Trust the debug uplink interface for SSH access during development
    firewall.trustedInterfaces = [ "enp2s0" ];

    # WiFi Access Point configuration
    hostapd = {
      enable = true;
      countryCode = "US";

      # Fast roaming disabled - requires hostapd compiled with 802.11r/k/v support
      # TODO: Enable when using a custom hostapd package with these features
      roaming = {
        enable = false;
        # mobilityDomain = "a1b2"; # Must be same across all APs
        # ieee80211k = true; # Radio Resource Management
        # ieee80211v = true; # BSS Transition Management
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
