{
  inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./nat-adapter.nix
    # Include the T2 security chip module from nixos-hardware
    inputs.hardware.nixosModules.apple-t2
    inputs.hardware.nixosModules.common-cpu-intel
    # Core system configuration
    inputs.self.modules.nixos.base
    inputs.self.modules.homeManager.base

    # User setup
    inputs.self.modules.nixos.pperanich
    inputs.self.modules.homeManager.pperanich

    # Desktop environment
    inputs.self.modules.homeManager.fonts
    inputs.self.modules.homeManager.desktopApplications
    inputs.self.modules.homeManager.zsh

    # Development environment
    inputs.self.modules.homeManager.nvim
    inputs.self.modules.homeManager.emacs
    inputs.self.modules.homeManager.vscode
    inputs.self.modules.nixos.rust
    inputs.self.modules.homeManager.rust
    inputs.self.modules.homeManager.tex

    # System utilities
    inputs.self.modules.nixos.fileExploration
    inputs.self.modules.homeManager.fileExploration
    inputs.self.modules.nixos.networkUtilities
    inputs.self.modules.homeManager.networkUtilities

    # Virtualization (useful for development)
    inputs.self.modules.nixos.docker
    inputs.self.modules.homeManager.docker
    inputs.self.modules.nixos.qemu
    inputs.self.modules.homeManager.qemu
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Networking configuration
  networking = {
    hostName = "pperanich-ll1";
    # wireless.enable = true;
    # wireless.userControlled.enable = true;
    networkmanager.enable = true; # Use NetworkManager instead
    # wireless.networks."VirusInfectedWifi".psk = "vacinate";
    # wireless.networks."#DCA Free WiFi" = {};
    # useDHCP = true;
  };

  systemd = {
    services.tiny-dfr = {
      wantedBy = [
        "post-resume.target"
        "dev-tiny_dfr_display.device"
        "dev-tiny_dfr_backlight.device"
        "dev-tiny_dfr_display_backlight.device"
      ];
      after = [ "post-resume.target" ];
    };
  };

  powerManagement = {
    enable = true;
    powertop.enable = true;
    cpuFreqGovernor = "powersave";

    # Add sleep-specific settings
    # scsiLinkPolicy = "med_power_with_dipm"; # Better SCSI/SATA power management
    # powerDownCommands = ''
    #   # Turn off all USB devices except those needed for waking
    #   echo 'auto' > /sys/bus/usb/devices/*/power/control || true
    #   # Force PCIe power management
    #   for i in /sys/bus/pci/devices/*/power/control; do echo 'auto' > $i || true; done
    # '';
    # resumeCommands = ''
    #   # Turn USB devices back on
    #   echo 'on' > /sys/bus/usb/devices/*/power/control || true
    #   # Reset PCIe power management
    #   for i in /sys/bus/pci/devices/*/power/control; do echo 'on' > $i || true; done
    # '';
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
      kernelChannel = "latest";
    };
    graphics = {
      enable = true;
      enable32Bit = true;

      extraPackages = with pkgs; [
        vaapiVdpau
        libvdpau-va-gl
      ];
    };
  };

  # Additional services
  services = {
    # Enable SSH
    openssh.enable = true;

    # Enable printing
    printing.enable = true;

    thermald.enable = true;
    power-profiles-daemon.enable = false;
    auto-cpufreq = {
      enable = true;
      settings = {
        battery = {
          governor = "powersave";
          turbo = "never";
        };
        charger = {
          governor = "powersave";
          turbo = "auto";
        };
      };
    };

    # Configure systemd hibernate service
    logind = {
      # extraConfig = ''
      #   HandlePowerKey=suspend
      #   HandleLidSwitch=suspend
      #   HandleLidSwitchDocked=ignore
      #   IdleAction=suspend
      #   IdleActionSec=30min
      #   SuspendKeyIgnoreInhibited=yes
      #   SuspendDelaySec=0
      # '';
      lidSwitch = "suspend";
      lidSwitchDocked = "ignore";
      lidSwitchExternalPower = "suspend";
    };

    # tlp = {
    #   enable = true;
    #   settings = {
    #     CPU_SCALING_GOVERNOR_ON_AC = "performance";
    #     CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
    #
    #     CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
    #     CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
    #
    #     CPU_MIN_PERF_ON_AC = 0;
    #     CPU_MAX_PERF_ON_AC = 100;
    #     CPU_MIN_PERF_ON_BAT = 0;
    #     CPU_MAX_PERF_ON_BAT = 20;
    #
    #     # Optional helps save long term battery health
    #     # START_CHARGE_THRESH_BAT0 = 40; # 40 and below it starts to charge
    #     # STOP_CHARGE_THRESH_BAT0 = 80; # 80 and above it stops charging
    #   };
    # };

    # Enable Touchpad support
    # libinput = {
    #   enable = true;
    #   touchpad = {
    #     naturalScrolling = true;
    #     tapping = true;
    #     disableWhileTyping = true;
    #   };
    # };
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

    # MacBook-specific utilities
    brightnessctl # Backlight control
    powertop # Power consumption analyzer

    # Graphics drivers
    mesa
    vulkan-loader
    vulkan-tools

    # Firmware updates
    fwupd
  ];

  # Boot configuration
  boot = {
    initrd.systemd.enable = true;
    binfmt.emulatedSystems = [ "aarch64-linux" ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    # Enable APFS support (for accessing macOS partitions)
    extraModulePackages = with config.boot.kernelPackages; [
      # apfs
    ];

    # Add kernel parameters for better hibernation support
    kernelParams = [
      "usbcore.autosuspend=-1"
      "mem_sleep_default=s2idle"
      # "acpi_osi=Darwin"           # Better ACPI compatibility for MacBooks
      # "acpi_force"                # Force ACPI
      # "acpi_enforce_resources=lax" # More lenient ACPI resource checking
      # "mem_sleep_default=deep"     # Enable deep sleep states
      # "pcie_aspm=force"           # Force PCIe Active State Power Management
      # "pcie_port_pm=force"        # Force PCIe port power management
      # "nvme.noacpi=1"             # Disable ACPI for NVMe - can help with sleep
      # "intel_idle.max_cstate=4"   # Limit C-states for better stability
    ];
  };
  systemd.services = {
    tune-usb-autosuspend = {
      description = "Disable USB autosuspend";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
      };
      unitConfig.RequiresMountsFor = "/sys";
      script = ''
        echo -1 > /sys/module/usbcore/parameters/autosuspend
      '';
    };
  };
}
