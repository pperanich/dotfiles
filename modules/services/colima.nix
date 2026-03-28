_:
{
  flake.modules.darwin.colima =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Inherit session variables so XDG_CONFIG_HOME, COLIMA_PROFILE, etc.
      # are baked into the plist — no dependency on launchctl setenv ordering.
      primaryUser = config.system.primaryUser;
      sessionVars = config.home-manager.users.${primaryUser}.home.sessionVariables;
    in
    {
      environment.systemPackages = [ pkgs.colima ];

      launchd.user.agents.colima = {
        serviceConfig = {
          ProgramArguments = [
            "${pkgs.colima}/bin/colima"
            "start"
            "--foreground"
            "--save-config=false"
          ];
          RunAtLoad = true;
          KeepAlive = {
            # Restart on unexpected failures, but allow a clean manual stop.
            SuccessfulExit = false;
          };
          ThrottleInterval = 30;
          WorkingDirectory = config.home-manager.users.${primaryUser}.home.homeDirectory;
          EnvironmentVariables = sessionVars // {
            PATH = lib.makeBinPath [
              pkgs.colima
              pkgs.docker-client
              pkgs.docker-compose
              pkgs.docker-credential-helpers
            ] + ":/usr/bin:/bin:/usr/sbin:/sbin";
          };
          StandardOutPath = "/tmp/colima.stdout.log";
          StandardErrorPath = "/tmp/colima.stderr.log";
        };
      };
    };
}
