{
  inputs,
  outputs,
  pkgs,
  ...
}: {
  imports =
    builtins.attrValues outputs.nixosModules
    ++ [
      inputs.disko.nixosModules.disko
      ./disko-config.nix
      ./hardware-configuration.nix
      inputs.jetpack-nixos.nixosModules.default
    ];

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
    hostName = "pperanich-orin1";
    wireless.enable = true;
    wireless.userControlled.enable = true;
    wireless.networks."VirusInfectedWifi".psk = "vacinate";
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
    # kernelPackages = pkgs.linuxPackages_latest;
    # kernelPackages = pkgs.linuxPackages;
    # kernelPackages = pkgs.linuxPackages_5_15;
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  hardware.nvidia-jetpack = {
    enable = true;
    som = "orin-agx";
    carrierBoard = "devkit";
  };

  # services.nvpmodel.profileNumber = 0;

  # Avoid kernel crashes
  boot.kernelParams = [ "initcall_blacklist=tegra_se_module_init" ];

  # hardware.opengl.enable = true;

  time.timeZone = "America/New_York";
}
