# Work-specific features
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.home.features.work;
in {
  imports = [
    ./aplnis.nix
  ];

  options.my.home.features.work = {
    enable = lib.mkEnableOption "work-specific features";

    # Sub-feature toggles
    aplnis = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.enable;
        description = "Whether to enable APLNIS-specific configuration";
      };
    };
  };
}
