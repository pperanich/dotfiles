# SSH configuration
{
  lib,
  config,
  ...
}: let
  cfg = config.my.core;
in {
  config = lib.mkIf cfg.enable {
    # This setups a SSH server. Very important if you're setting up a headless system.
    # Feel free to remove if you don't need it.
    services = {
      openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };
    };
  };
}
