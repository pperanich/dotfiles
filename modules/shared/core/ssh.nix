# SSH configuration
{
  inputs,
  lib,
  pkgs,
  config,
  modulesPath,
  ...
}: let
  cfg = config.my.core;
in {
  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
    };
  };
}
