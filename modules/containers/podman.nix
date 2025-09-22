{...}: {
  # NixOS system-level Podman configuration
  flake.modules.nixos.podman = { config, lib, pkgs, ... }: let
    cfg = config.features.podman;
  in {
    options.features.podman = {
      dockerCompat = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Docker-compatible socket for Podman";
      };
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

    config = {
      virtualisation.podman = {
        enable = true;

        # Enable Docker compatibility if requested
        inherit (cfg) dockerCompat;

        # Dual-stack networking with DNS support
        defaultNetwork.settings = {
          dns_enabled = true;
        } // cfg.defaultNetwork.settings;

        # Additional packages from configuration
        inherit (cfg) extraPackages;
      };

      # Add essential container management packages
      environment.systemPackages = with pkgs; [
        podman-compose
      ] ++ cfg.extraPackages;

      # Ensure rootless operation is configured properly
      boot.kernelModules = ["overlay"];

      # Recommended settings for better rootless operation
      security.unprivilegedUsernsClone = lib.mkDefault true;
    };
  };

  # Home Manager user-level container tools
  flake.modules.homeManager.podman = { pkgs, ... }: {
    home.packages = with pkgs; [
      # Container management and development tools
      lazydocker
      dive          # Explore Docker/Podman image layers
      podman-tui    # Terminal UI for Podman
      buildah       # Container build tool
      skopeo        # Container image operations

      # Development tools that work with containers
      kubectl       # Kubernetes CLI
      k9s           # Kubernetes TUI
    ];
  };
}
