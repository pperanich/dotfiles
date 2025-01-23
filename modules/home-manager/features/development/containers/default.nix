# Container runtime features
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.home.features.development.containers;
in {
  imports = [
    ./podman.nix
  ];

  options.modules.home.features.development.containers = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.modules.home.features.development.enable;
      description = "Whether to enable container runtime support";
    };
  };

  config = lib.mkIf cfg.enable {
    # Common container tools
    home.packages = with pkgs; [
      docker-compose
      lazydocker
      dive # A tool for exploring each layer in a docker image
    ];
  };
}
