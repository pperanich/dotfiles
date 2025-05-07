# Podman virtualization module
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.features.virtualization.podman;
in {
  options.my.features.virtualization.podman = {
    enable = lib.mkEnableOption "Podman container runtime";
    dockerCompat = lib.mkEnableOption "Docker-compatible socket for Podman";
    defaultNetwork.settings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Configuration for the default Podman network";
      example = {
        subnet = "10.88.0.0/16";
        gateway = "10.88.0.1";
      };
    };
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      example = "[ pkgs.podman-compose ]";
      description = "Additional packages to install with Podman";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.podman = {
      enable = true;

      # Enable Docker compatibility if requested
      dockerCompat = cfg.dockerCompat;

      # Dual-stack networking
      defaultNetwork.settings =
        {
          dns_enabled = true;
        }
        // cfg.defaultNetwork.settings;

      # Enable cgroup v2 support
      extraPackages = cfg.extraPackages;
    };

    # Add related packages
    environment.systemPackages = with pkgs;
      [
        podman-compose
      ]
      ++ cfg.extraPackages;

    # Ensure rootless operation is configured properly
    boot.kernelModules = ["overlay"];

    # Recommended settings for better rootless operation
    security.unprivilegedUsernsClone = lib.mkDefault true;
    # boot.kernel.sysctl."kernel.unprivileged_userns_clone" = lib.mkDefault 1;
  };
}
