# User config applicable only to darwin
{ config, ... }:
{
  users.users.pperanich = {
    home = "/Users/pperanich";
  };

  launchd.user.envVariables = config.home-manager.users.pperanich.home.sessionVariables;
} 