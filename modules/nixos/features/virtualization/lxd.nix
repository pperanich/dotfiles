# LXD containerization module
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.features.virtualization.lxd;
in {
  options.my.features.virtualization.lxd = {
    enable = lib.mkEnableOption "LXD system containers";
    zfsBackend = lib.mkEnableOption "ZFS storage backend for LXD";
    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to start the LXD daemon on boot";
    };
    preseed = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a preseed file for automatic LXD initialization";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable LXD
    virtualisation.lxd = {
      enable = true;
      zfsSupport = cfg.zfsBackend;
      inherit (cfg) preseed;
    };

    # Add user to LXD group if module is enabled
    # users.groups.lxd.members = config.my.user.groups;

    # Load appropriate kernel modules
    boot.kernelModules = ["overlay"];

    # Auto-start service if configured
    systemd.services.lxd.wantedBy = lib.mkIf cfg.autoStart ["multi-user.target"];

    # Add required networking config for LXD
    networking = {
      firewall = {
        # Allow LXD traffic
        trustedInterfaces = ["lxdbr0"];
        allowedTCPPorts = [8443]; # LXD API server
      };
      nat = {
        enable = true;
        internalInterfaces = ["lxdbr0"];
      };
    };

    # Additional packages
    environment.systemPackages = with pkgs; [
      lxd
    ];
  };
}
