# NixOS Podman system service configuration
# Handles virtualisation.podman, kernel modules, user namespaces
_: {
  # NixOS system configuration for Podman
  flake.modules.nixos.containerDevelopment = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.features.containers;
  in {
    options.features.containers = {
      runtime = lib.mkOption {
        type = lib.types.enum ["podman" "docker"];
        default = "podman";
        description = "Container runtime to use (podman or docker)";
      };

      dockerCompat = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Docker-compatible socket for the container runtime";
      };

      defaultNetwork.settings = lib.mkOption {
        type = lib.types.attrs;
        default = {};
        description = "Configuration for the default container network";
        example = {
          subnet = "10.88.0.0/16";
          gateway = "10.88.0.1";
        };
      };

      extraPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [];
        example = "[ pkgs.podman-compose ]";
        description = "Additional container-related packages to install system-wide";
      };
    };

    config = lib.mkIf (cfg.runtime == "podman") {
      # Configure Podman container runtime
      virtualisation.podman = {
        enable = true;
        inherit (cfg) dockerCompat;

        # Dual-stack networking with DNS enabled
        defaultNetwork.settings =
          {
            dns_enabled = true;
          }
          // cfg.defaultNetwork.settings;
      };

      # Kernel modules and settings for container operation
      boot.kernelModules = ["overlay"];

      # Enable rootless containers
      security.unprivilegedUsernsClone = lib.mkDefault true;

      # User namespace configuration for Podman
      users.users.root.subUidRanges = [
        {
          startUid = 100000;
          count = 65536;
        }
      ];
      users.users.root.subGidRanges = [
        {
          startGid = 100000;
          count = 65536;
        }
      ];
    };
  };
}
