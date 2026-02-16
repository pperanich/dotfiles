{
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    mirroredBoots = [
      {
        devices = [ "nodev" ];
        path = "/boot";
      }
      {
        devices = [ "nodev" ];
        path = "/boot2";
      }
    ];
  };

  disko.devices = {
    disk = {
      nvme0 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WD_BLACK_SN7100_2TB_252726800510";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          };
        };
      };

      nvme1 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WD_BLACK_SN7100_2TB_252726802070";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot2";
                mountOptions = [ "umask=0077" ];
              };
            };

            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          };
        };
      };
    };

    zpool = {
      rpool = {
        type = "zpool";
        mode = "mirror";

        rootFsOptions = {
          compression = "zstd";
          atime = "off";
          xattr = "sa";
          acltype = "posixacl";
          normalization = "formD";
          "com.sun:auto-snapshot" = "false";
        };

        datasets = {
          # Parent container — not mounted directly
          root = {
            type = "zfs_fs";
            options = {
              canmount = "off";
              mountpoint = "none";
            };
          };

          # Actual root filesystem
          "root/nixos" = {
            type = "zfs_fs";
            mountpoint = "/";
            options = {
              canmount = "noauto";
              quota = "50G";
            };
          };

          nix = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              quota = "250G";
              "com.sun:auto-snapshot" = "false";
            };
          };

          var = {
            type = "zfs_fs";
            mountpoint = "/var";
            options = {
              quota = "100G";
            };
          };

          home = {
            type = "zfs_fs";
            mountpoint = "/home";
          };

          tank = {
            type = "zfs_fs";
            mountpoint = "/tank";
            options = {
              reservation = "1500G";
              "com.sun:auto-snapshot" = "true";
            };
          };

          "tank/appdata" = {
            type = "zfs_fs";
            mountpoint = "/tank/appdata";
            options = {
              "com.sun:auto-snapshot" = "true";
            };
          };
        };
      };
    };
  };
}
