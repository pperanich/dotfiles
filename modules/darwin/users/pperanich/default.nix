{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.my.users.pperanich;
in {
  imports = lib.flatten [
    (lib.my.relativeToRoot "modules/shared/users/pperanich")
  ];

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      users.users.pperanich = {
        home = "/Users/pperanich";
      };

      launchd.user.envVariables = config.home-manager.users.pperanich.home.sessionVariables;
    })
  ];
}
