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
      # Wired LAN only (WiFi disabled - using client mode instead)
      interface = "enp5s0"; # Primary wired LAN interface
      interfaces = [
        "enp5s0" # Wired LAN
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

    # WiFi Access Point configuration - DISABLED for now, using WiFi client mode
    hostapd.enable = false;

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

  # WiFi client mode - connect to existing router's WiFi
  networking.wireless = {
    enable = true;
    # Use wlan0 (2.4GHz) for client connection - better range
    interfaces = [ "wlan0" ];
    # Allow imperative network configuration alongside declarative
    allowAuxiliaryImperativeNetworks = true;
    userControlled.enable = true; # Allow users to manage networks
    networks = {
      "VirusInfectedWifi" = {
        psk = "@WIFI_PSK@";
      };
    };
    secretsFile = config.sops.templates."wpa-secrets".path;
    extraConfig = ''
      country=US
    '';
  };

  # Template to create wpa_supplicant secrets file from sops
  sops.templates."wpa-secrets" = {
    content = ''
      WIFI_PSK=${config.sops.placeholder.wifi_passphrase}
    '';
    owner = "root";
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
