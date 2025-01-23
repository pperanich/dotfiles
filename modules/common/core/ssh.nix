# SSH configuration
{
  inputs,
  lib,
  pkgs,
  config,
  modulesPath,
  ...
}: let
  cfg = config.modules.core;
in {
  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
    };
  };
}
