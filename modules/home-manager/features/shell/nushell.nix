# Nushell configuration
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.home.features.shell;
in {
  options.my.home.features.shell.nushell = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable;
      description = "Whether to enable Nushell configuration";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.nushell.enable) {
    programs = {
      nushell = {
        enable = true;
      };
      direnv = {
        enableNushellIntegration = true;
      };
      atuin = {
        enableNushellIntegration = true;
      };
      zoxide = {
        enableNushellIntegration = true;
      };
    };
  };
}
