# User config applicable only to darwin
{ config, ... }:
{
  users.users.peranpl1 = {
    home = "/Users/peranpl1";
  };

  launchd.user.envVariables = config.home-manager.users.peranpl1.home.sessionVariables;
}