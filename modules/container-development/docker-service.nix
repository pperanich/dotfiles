# NixOS Docker system service configuration
# Alternative to Podman - handles virtualisation.docker configuration
_: {
  # NixOS system configuration for Docker
  flake.modules.nixos.containerDevelopment = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.features.containers;
  in {
    config = lib.mkIf (cfg.runtime == "docker") {
      # Configure Docker container runtime
      virtualisation.docker = {
        enable = true;
        enableOnBoot = true;
      };

      # Kernel modules and settings for container operation
      boot.kernelModules = ["overlay"];

      # Enable rootless containers
      security.unprivilegedUsernsClone = lib.mkDefault true;
    };
  };
}
