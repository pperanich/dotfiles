# Podman container runtime configuration
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.home.features.development.containers;
in {
  config = lib.mkIf (cfg.enable) {
    home.packages = with pkgs; [
      podman
      qemu
      gvproxy
    ];
  };
}
