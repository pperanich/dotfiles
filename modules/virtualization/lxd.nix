{...}: {
  # NixOS system-level LXD configuration
  flake.modules.nixos.lxd = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.features.lxd;
  in {
    options.features.lxd = {
      zfsBackend = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable ZFS storage backend for LXD";
      };
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

    config = {
      # Enable LXD
      virtualisation.lxd = {
        enable = true;
        zfsSupport = cfg.zfsBackend;
        inherit (cfg) preseed;
      };

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
  };

  # Home Manager user-level LXD tools
  flake.modules.homeManager.lxd = {pkgs, ...}: {
    home.packages = with pkgs; [
      # LXD management tools
      distrobox # Use any Linux distribution inside a container

      # General container utilities that work with LXD
      dive # Explore container layers
    ];
  };
}
