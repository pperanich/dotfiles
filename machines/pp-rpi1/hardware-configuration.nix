_: {
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };

  # Keep the local SD root filesystem definition here and let nixos-hardware
  # own the Raspberry Pi 3 boot/kernel defaults.
  swapDevices = [ ];
}
