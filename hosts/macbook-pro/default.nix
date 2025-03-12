{
  inputs,
  outputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports =
    builtins.attrValues outputs.nixosModules
    ++ [
      ./hardware-configuration.nix
      # Include the T2 security chip module from nixos-hardware
      inputs.hardware.nixosModules.apple-t2
    ];

  nixpkgs.hostPlatform = "x86_64-linux";

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

  # Core system configuration
  my = {
    core.enable = true;
    users.pperanich.enable = true; # Adjust this to your username

    # Desktop environment configuration
    desktop = {
      # Enable display manager with Sway as default
      display-manager = {
        enable = true;
        manager = "gdm";
        defaultSession = "sway";
        autoLogin = {
          enable = false;
          user = "pperanich"; # Change to your desired user
        };
      };

      # Enable desktop environments
      sway.enable = true;
      kde.enable = true;
    };
  };

  # Networking configuration
  networking = {
    hostName = "macbook-pro";
    wireless.enable = false; # Disable wpa_supplicant
    networkmanager.enable = true; # Use NetworkManager instead
  };

  # T2 Mac specific hardware configuration
  hardware = {
    graphics = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };

    # Enable sound via pipewire
    bluetooth.enable = true;

    # Apple-specific configuration
    facetimehd.enable = true; # Enable FaceTime HD camera if available
  };

  services.pulseaudio.enable = false;

  # Enable sound via pipewire
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Additional services
  services = {
    # Enable SSH
    openssh.enable = true;

    # Enable printing
    printing.enable = true;

    # Enable Bluetooth
    blueman.enable = true;

    # Touchpad support
    libinput = {
      enable = true;
      touchpad = {
        naturalScrolling = true;
        tapping = true;
        disableWhileTyping = true;
      };
    };

    # Thermal management
    thermald.enable = true;

    # Power management
    tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      };
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
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;

    # T2 Mac specific kernel parameters
    kernelParams = [
      "intel_iommu=on"
      "iommu=pt"
      "pcie_ports=compat"
      "pcie_aspm.policy=powersupersave"
    ];

    # Enable keyboard in early boot
    initrd.availableKernelModules = ["applespi" "spi_pxa2xx_platform"];

    # Enable APFS support (for accessing macOS partitions)
    extraModulePackages = with config.boot.kernelPackages; [
      apfs
    ];
  };
}
