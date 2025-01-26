{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.my.users.peranpl1;
in {
  imports = lib.flatten [
    (lib.my.relativeToRoot "modules/shared/users/peranpl1")
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
