# Work-specific features
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.home.features.work;
in {
  imports = [
    ./aplnis.nix
  ];

  options.modules.home.features.work = {
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
