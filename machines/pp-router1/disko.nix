# ---
# schema = "single-disk"
# [placeholders]
# mainDisk = "/dev/disk/by-id/PLACEHOLDER_DISK_ID"
# ---
# PLACEHOLDER: Update mainDisk above after running:
#   ls -la /dev/disk/by-id/
# on the actual hardware to find the correct disk identifier.
{
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    enable = true;
  };
  disko.devices = {
    disk = {
      main = {
        name = "main-pp-router1";
        device = "/dev/disk/by-id/nvme-ORICO_RN006218";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            "boot" = {
              size = "1M";
              type = "EF02"; # for grub MBR
              priority = 1;
            };
            ESP = {
              type = "EF00";
              size = "500M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
