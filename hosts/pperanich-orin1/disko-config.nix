# disko-config.nix
{
  disko.devices = {
    disk = {
      # You can name this disk entry descriptively, e.g., "primaryNvme"
      # The original script would generate a key "main".
      # Let's use a more common disko style name.
      kingston_nvme_main = {
        device = "/dev/disk/by-id/nvme-KINGSTON_SFYRD2000G_50026B7686FA5698"; # Derived from your script's logic
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              name = "ESP"; # Optional, disko often infers from attribute name
              size = "1G";
              type = "EF00"; # EFI System Partition
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              name = "root"; # Optional
              size = "100%"; # Takes the rest of the disk
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
      # If you had other disks defined in nvmeDrives, they would appear here too.
    };
    # If you had other device types like lvm, zfs, etc., they'd be here.
    # nodev = {
    #   # Example for filesystems not directly on a partition defined above
    #   # but on a device created by disko (like an LVM LV or ZFS dataset)
    # };
  };
}
