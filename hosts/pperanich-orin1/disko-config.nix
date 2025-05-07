{ lib, ... }:
let
  # Merge all of the configurations for a disk.
  mkDisk =
    _name:
    {
      interface,
      model,
      serial,
      modelSerialSeparator,
      contentConfigs,
    }:
    {
      device = "/dev/disk/by-id/${interface}-${model}${modelSerialSeparator}${serial}";
      type = "disk";
      # Recursively merged all the configs for a disk.
      # NOTE: Because we use foldr, later configs override earlier configs.
      content = lib.foldr lib.recursiveUpdate { } contentConfigs;
    };

  # Configuration for our boot
  bootConfig = {
    type = "gpt";
    partitions.ESP = {
      size = "1G";
      type = "EF00"; # EFI System
      content = {
        format = "vfat";
        mountpoint = "/boot";
        type = "filesystem";
      };
    };
  };

  # Configuration for rpool disks.
  rootConfig = {
    type = "gpt";
    partitions.root = {
      size = "100%";
      content = {
        type = "filesystem";
        format = "ext4";
        mountpoint = "/";
      };
    };
  };

# nvme-KINGSTON_SFYRD2000G_50026B7686FA5698
  nvmeDrives =
    let
      common = {
        interface = "nvme";
        model = "SFYRD2000G";
        modelSerialSeparator = "_";
      };
      disks.main = {
        serial = "50026B7686FA5698";
        contentConfigs = [
          bootConfig
          rootConfig
        ];
      };
    in
    lib.mapAttrs (lib.const (lib.recursiveUpdate common)) disks;
in
{
  config.disko.devices.disk = lib.mapAttrs mkDisk nvmeDrives;
}
