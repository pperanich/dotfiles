{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.modules.users.pperanich;
in {
  imports = lib.flatten [
    (lib.custom.relativeToRoot "modules/common/users/pperanich")
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
