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
        manager = "sddm";
        defaultSession = "plasma";
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
    hostName = "pperanich-ll1";
    wireless.enable = true;
    wireless.userControlled.enable = true;
    useDHCP = true;
  };

  # Additional services
  services = {
    # Enable SSH
    openssh.enable = true;

    # Enable printing
    printing.enable = true;
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
    
    # Enable APFS support (for accessing macOS partitions)
    extraModulePackages = with config.boot.kernelPackages; [
      apfs
    ];
  };
}
