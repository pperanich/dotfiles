{
  inputs,
  modules,
  pkgs,
  lib,
  config,
  ...
}:
let
  t2-apple-audio-dsp = builtins.fetchGit {
    url = "https://github.com/lemmyg/t2-apple-audio-dsp";
    rev = "3f9ad7b738ffad22b713a4d5e11fbfdddefcddb9";
  };
in
{
  imports = [
    ./hardware-configuration.nix
    # Include the T2 security chip module from nixos-hardware
    inputs.hardware.nixosModules.apple-t2
    inputs.hardware.nixosModules.common-cpu-intel
    "${t2-apple-audio-dsp}/nixos/pipewire_sink_conf.nix"
  ]
  ++ (with modules.nixos; [
    # Core system configuration
    base
    sops

    # User setup
    pperanich

    # Development environment
    rust

    # System utilities
    fileExploration
    networkUtilities

    # # Virtualization (useful for development)
    # docker
    # qemu
  ]);

  # T2Linux-specific Nix settings
  nix.settings = {
    trusted-substituters = [
      "https://t2linux.cachix.org"
    ];
    trusted-public-keys = [
      "t2linux.cachix.org-1:P733c5Gt1qTcxsm+Bae0renWnT8OLs0u9+yfaK2Bejw="
    ];
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  nixpkgs.hostPlatform = "x86_64-linux";
  clan.core.networking.targetHost = lib.mkForce "root@192.168.0.181";
  clan.core.networking.buildHost = "root@192.168.0.184";

  services = {
    # Enable the login manager
    displayManager.cosmic-greeter.enable = true;
    # Enable the COSMIC DE itself
    desktopManager.cosmic = {
      enable = true;
      # Enable XWayland support in COSMIC
      xwayland.enable = true;
    };
  };

  # programs.waybar.enable = true;

  # Networking configuration
  networking.hostName = "pp-ll1";

  # systemd = {
  #   services.tiny-dfr = {
  #     wantedBy = [
  #       "post-resume.target"
  #       "dev-tiny_dfr_display.device"
  #       "dev-tiny_dfr_backlight.device"
  #       "dev-tiny_dfr_display_backlight.device"
  #     ];
  #     after = [ "post-resume.target" ];
  #   };
  # };

  powerManagement = {
    enable = true;
    # powertop.enable = true;
    # cpuFreqGovernor = "powersave";
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
    apple.touchBar = {
      enable = true;
      settings = {
        FontTemplate = "Hurmit Nerd Font";
      };
    };
    enableRedistributableFirmware = true;
    apple-t2 = {
      enableIGPU = true;
      firmware.enable = true;
      kernelChannel = "stable";
    };
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      package = pkgs.bluez;
    };
    graphics = {
      enable = true;
      enable32Bit = true;

      extraPackages = with pkgs; [
        libvdpau-va-gl
        libva-vdpau-driver
      ];
    };
  };

  # Additional services
  # services = {
  #   thermald.enable = true;
  #   power-profiles-daemon.enable = false;
  #   auto-cpufreq = {
  #     enable = true;
  #     settings = {
  #       battery = {
  #         governor = "powersave";
  #         turbo = "never";
  #       };
  #       charger = {
  #         governor = "powersave";
  #         turbo = "auto";
  #       };
  #     };
  #   };
  #
  #   # Configure systemd hibernate service
  #   logind = {
  #     lidSwitch = "suspend";
  #     lidSwitchDocked = "ignore";
  #     lidSwitchExternalPower = "suspend";
  #   };
  # };

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

    # MacBook-specific utilities
    brightnessctl # Backlight control
    powertop # Power consumption analyzer

    # Graphics drivers
    mesa
    vulkan-loader
    vulkan-tools

    # Firmware updates
    fwupd
    linux-firmware

    ghostty

    ladspaPlugins
    calf
    lsp-plugins

    system76-power
    power-profiles-daemon
  ];

  # Boot configuration
  boot = {
    initrd.systemd.enable = true;
    binfmt.emulatedSystems = [ "aarch64-linux" ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    # Add kernel parameters for better hibernation support
    kernelParams = [
      "usbcore.autosuspend=-1"
      "mem_sleep_default=s2idle"
      # Suppress Bluetooth advertising packet warnings
      "bluetooth.disable_ertm=1"
    ];
  };

  # systemd.services = {
  #   tune-usb-autosuspend = {
  #     description = "Disable USB autosuspend";
  #     wantedBy = [ "multi-user.target" ];
  #     serviceConfig = {
  #       Type = "oneshot";
  #     };
  #     unitConfig.RequiresMountsFor = "/sys";
  #     script = ''
  #       echo -1 > /sys/module/usbcore/parameters/autosuspend
  #     '';
  #   };
  # };

  systemd.user.services.pipewire.environment = {
    LADSPA_PATH = "${pkgs.ladspaPlugins}/lib/ladspa";
    LV2_PATH = lib.mkForce "${config.system.path}/lib/lv2";
  };

  hardware.system76.power-daemon.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    audio.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = true;
  };
}
