# This is a placeholder hardware configuration file.
# After installing NixOS on the Beelink ME mini, run:
#   sudo nixos-generate-config --show-hardware-config
# and replace this file with the generated output.
{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "nvme"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
    initrd.kernelModules = [ ];
    kernelModules = [ "kvm-intel" ]; # Change to "kvm-amd" if AMD CPU
    extraModulePackages = [ ];
  };

  # TODO: Replace these with actual disk UUIDs after installation
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/REPLACE-WITH-ACTUAL-UUID";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/REPLACE-WITH-ACTUAL-UUID";
      fsType = "vfat";
      options = [
        "fmask=0022"
        "dmask=0022"
      ];
    };
  };

  swapDevices = [
    # { device = "/dev/disk/by-uuid/REPLACE-WITH-ACTUAL-UUID"; }
  ];

  # Enables DHCP on each ethernet and wireless interface
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  # If AMD CPU, replace above line with:
  # hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
