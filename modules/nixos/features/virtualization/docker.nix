# Docker virtualization module
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.features.virtualization.docker;
in {
  options.my.features.virtualization.docker = {
    enable = lib.mkEnableOption "Docker container runtime";
    enableNvidia = lib.mkEnableOption "NVIDIA GPU support for Docker";
    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to start the Docker daemon on boot";
    };
    storageDriver = lib.mkOption {
      type = lib.types.str;
      default = "overlay2";
      description = "Storage driver to use for Docker";
    };
    extraOptions = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "--insecure-registry registry.local:5000";
      description = "Extra options for Docker daemon";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
      inherit (cfg) enableNvidia;
      daemon.settings =
        {
          storage-driver = cfg.storageDriver;
        }
        // lib.optionalAttrs (cfg.extraOptions != "") {
          # Parse extra options if they exist
          exec-opts = [cfg.extraOptions];
        };
    };

    # Add user to docker group if module is enabled
    # users.groups.docker.members = config.my.user.groups;

    # Ensure required kernel modules are loaded
    boot.kernelModules = ["overlay"];

    # Auto-start service if configured
    systemd.services.docker.wantedBy = lib.mkIf cfg.autoStart ["multi-user.target"];
  };
}
