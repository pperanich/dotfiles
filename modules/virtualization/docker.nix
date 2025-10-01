{...}: {
  # NixOS system-level Docker configuration
  flake.modules.nixos.docker = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.features.docker;
  in {
    options.features.docker = {
      enableNvidia = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable NVIDIA GPU support for Docker";
      };
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

    config = {
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

      # Ensure required kernel modules are loaded
      boot.kernelModules = ["overlay"];

      # Auto-start service if configured
      systemd.services.docker.wantedBy = lib.mkIf cfg.autoStart ["multi-user.target"];

      # Add essential Docker management packages
      environment.systemPackages = with pkgs; [
        docker-compose
      ];
    };
  };

  # Home Manager user-level Docker tools
  flake.modules.homeManager.docker = {pkgs, ...}: {
    home.packages = with pkgs; [
      # Container management and development tools
      lazydocker
      dive # Explore Docker image layers
      ctop # Container top
      docker-ls # List Docker images and containers

      # Development tools that work with Docker
      kubectl # Kubernetes CLI
      k9s # Kubernetes TUI
    ];
  };
}
