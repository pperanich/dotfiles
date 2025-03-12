# This file will be replaced during installation by nixos-generate-config
# Current file contains example configuration for a MacBook Pro T2
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # MacBook Pro 2019 hardware configuration
  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usbhid"
        "usb_storage"
        "sd_mod"
        "spi_pxa2xx_platform"
        "applespi"
      ];
      kernelModules = [];
    };
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];
  };

  # Standard filesystem configuration for MacBook Pro
  fileSystems."/" = {
    device = "/dev/disk1s1"; # The NixOS volume (APFS container)
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk0s1"; # The EFI partition shared with macOS
    fsType = "vfat";
    options = ["umask=0077"]; # Secure permissions for boot
  };

  # No swap partition in this configuration
  swapDevices = [];

  # Hardware-specific settings for MacBook Pro
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
