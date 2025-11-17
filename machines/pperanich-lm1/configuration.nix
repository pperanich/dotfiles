{
  inputs,
  modules,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    # Include common Intel CPU optimizations
    inputs.hardware.nixosModules.common-cpu-intel
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

    # Virtualization (useful for mini PC/home server use)
    # docker
    # qemu
  ]);

  nixpkgs.hostPlatform = "x86_64-linux";
  clan.core.networking.targetHost = lib.mkForce "root@pperanich-lm1";
  clan.core.networking.buildHost = "root@pperanich-lm1";

  # Networking configuration
  networking.hostName = "pperanich-lm1";

  # Enable the login manager
  services.displayManager.cosmic-greeter.enable = true;
  # Enable the COSMIC DE itself
  services.desktopManager.cosmic.enable = true;
  # Enable XWayland support in COSMIC
  services.desktopManager.cosmic.xwayland.enable = true;

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
        vaapiVdpau
        libvdpau-va-gl
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
  ];

  # Boot configuration
  boot = {
    initrd.systemd.enable = true;
    binfmt.emulatedSystems = [ "aarch64-linux" ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    audio.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = true;
  };
}
