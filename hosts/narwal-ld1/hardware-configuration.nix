{...}: {
  imports = [
    # inputs.hardware.nixosModules.shared-cpu-amd
    # inputs.hardware.nixosModules.shared-ssd
  ];

  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };
  boot.loader.systemd-boot.enable = true;
}
