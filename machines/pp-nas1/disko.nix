# ---
# schema = "single-disk"
# [placeholders]
# mainDisk = "/dev/disk/by-id/mmc-DV4064_0x3bf0b832"
# ---
# This file was automatically generated!
# CHANGING this configuration requires wiping and reinstalling the machine
{
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    enable = true;
  };
  disko.devices = {
    disk = {
      main = {
        name = "main-c78230ac5f2a424b80c6f7882218af72";
        device = "/dev/disk/by-id/mmc-DV4064_0x3bf0b832";
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

### I want to move to the following once we have disk info from the machine.
#
## disko.nix
# { ... }:
#
# {
#   disko.devices = {
#     disk = {
#       nvme0 = {
#         type = "disk";
#         device = "/dev/nvme0n1";
#         content = {
#           type = "gpt";
#           partitions = {
#             ESP = {
#               size = "1G";
#               type = "EF00";
#               content = {
#                 type = "filesystem";
#                 format = "vfat";
#                 mountpoint = "/boot";
#                 mountOptions = [ "umask=0077" ];
#               };
#             };
#
#             zfs = {
#               size = "100%";
#               content = {
#                 type = "zfs";
#                 pool = "rpool";
#               };
#             };
#           };
#         };
#       };
#
#       nvme1 = {
#         type = "disk";
#         device = "/dev/nvme1n1";
#         content = {
#           type = "gpt";
#           partitions = {
#             ESP = {
#               size = "1G";
#               type = "EF00";
#               content = {
#                 type = "filesystem";
#                 format = "vfat";
#                 mountpoint = "/boot2";
#                 mountOptions = [ "umask=0077" ];
#               };
#             };
#
#             zfs = {
#               size = "100%";
#               content = {
#                 type = "zfs";
#                 pool = "rpool";
#               };
#             };
#           };
#         };
#       };
#     };
#
#     zpool = {
#       rpool = {
#         type = "zpool";
#         mode = "mirror";
#
#         # These apply to datasets by default (you can override per-dataset).
#         rootFsOptions = {
#           compression = "zstd";
#           atime = "off";
#           xattr = "sa";
#           acltype = "posixacl";
#           normalization = "formD";
#           "com.sun:auto-snapshot" = "false";
#         };
#
#         datasets = {
#           # Root dataset
#           root = {
#             type = "zfs_fs";
#             mountpoint = "/";
#             options = {
#               canmount = "noauto";
#             };
#           };
#
#           # This is what NixOS expects for ZFS root layouts.
#           "root/nixos" = {
#             type = "zfs_fs";
#             mountpoint = "/";
#             options = {
#               canmount = "noauto";
#             };
#           };
#
#           nix = {
#             type = "zfs_fs";
#             mountpoint = "/nix";
#             options = { "com.sun:auto-snapshot" = "false"; };
#           };
#
#           var = {
#             type = "zfs_fs";
#             mountpoint = "/var";
#           };
#
#           home = {
#             type = "zfs_fs";
#             mountpoint = "/home";
#           };
#
#           tank = {
#             type = "zfs_fs";
#             mountpoint = "/tank";
#             options = { "com.sun:auto-snapshot" = "true"; };
#           };
#
#           "tank/appdata" = {
#             type = "zfs_fs";
#             mountpoint = "/tank/appdata";
#             options = { "com.sun:auto-snapshot" = "true"; };
#           };
#         };
#       };
#     };
#   };
# }
#
#
# inside disko.devices.zpool.rpool.datasets = { ... };
#
# "root/nixos" = {
#   type = "zfs_fs";
#   mountpoint = "/";
#   options = {
#     canmount = "noauto";
#     # Optional: limit root dataset itself (often small)
#     quota = "50G";
#   };
# };
#
# nix = {
#   type = "zfs_fs";
#   mountpoint = "/nix";
#   options = {
#     # This is the one that tends to grow on NixOS
#     quota = "250G";  # example cap
#     "com.sun:auto-snapshot" = "false";
#   };
# };
#
# var = {
#   type = "zfs_fs";
#   mountpoint = "/var";
#   options = {
#     quota = "100G"; # example cap
#   };
# };
#
# tank = {
#   type = "zfs_fs";
#   mountpoint = "/tank";
#   options = {
#     # Protect data space from being squeezed by OS datasets
#     reservation = "1500G";  # example "guaranteed" space for data
#     "com.sun:auto-snapshot" = "true";
#   };
# };
#
