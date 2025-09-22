{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.disko.nixosModules.disko
    ./disko-config.nix
    ./hardware-configuration.nix
    inputs.jetpack-nixos.nixosModules.default
    # NVIDIA Jetson Xavier - AI/ML development server
    inputs.self.nixosModules.serverBase
    inputs.self.nixosModules.pythonDevelopment
    inputs.self.nixosModules.kubernetesServer
    inputs.self.nixosModules.graphics
  ];

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
    hostName = "pperanich-xavier1";
    wireless = {
      enable = true;
      userControlled.enable = true;
      networks."VirusInfectedWifi".psk = "vacinate";
    };
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
  };

  hardware = {
    graphics = {
      enable = true;
      forceDriver = "nvidia"; # Force NVIDIA for Jetson device
    };
    nvidia-jetpack = {
      enable = true;
      som = "xavier-agx";
      carrierBoard = "devkit";
    };
  };

  # services.nvpmodel.profileNumber = 0;

  # Avoid kernel crashes
  boot.kernelParams = ["initcall_blacklist=tegra_se_module_init"];

  # hardware.opengl.enable = true;

  time.timeZone = "America/New_York";
}
