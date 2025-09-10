{pkgs, ...}: {
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = ["noatime"];
    };
  };

  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_rpi3;
    # initrd.kernelModules = [ "vc4" "bcm2835_dma" "i2c_bcm2835" "bcm2835-v4l2" "xhci_pci" "usbhid" "usb_storage" ];
    loader.grub.enable = false;
    # Enables the generation of /boot/extlinux/extlinux.conf
    loader.generic-extlinux-compatible.enable = true;
    kernelParams = [
      "cma=256M"
    ];
  };

  hardware.enableRedistributableFirmware = true;
  services.pulseaudio.enable = true;
}
