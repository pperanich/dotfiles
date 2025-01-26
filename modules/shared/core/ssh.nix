# SSH configuration
{
  lib,
  config,
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
