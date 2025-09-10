{
  config,
  lib,
  ...
}: let
  cfg = config.my.users.peranpl1;
in {
  imports = lib.flatten [
    (lib.my.relativeToRoot "modules/shared/users/peranpl1")
  ];

  config = lib.mkIf cfg.enable {
    system.primaryUser = "peranpl1";
    users.users.peranpl1 = {
      home = "/Users/peranpl1";
    };

    launchd.user.envVariables = config.home-manager.users.peranpl1.home.sessionVariables;
  };
}
