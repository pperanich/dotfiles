{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.modules.users.peranpl1;
in {
  imports = lib.flatten [
    (lib.custom.relativeToRoot "modules/common/users/peranpl1")
  ];

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      users.users.peranpl1 = {
        home = "/Users/peranpl1";
      };

      launchd.user.envVariables = config.home-manager.users.peranpl1.home.sessionVariables;
    })
  ];
}
