# Nushell configuration
{
  config,
  lib,
  ...
}: let
  cfg = config.my.home.features.shell;
in {
  config = lib.mkIf cfg.nushell.enable {
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
