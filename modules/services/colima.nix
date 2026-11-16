_: {
  flake.modules.darwin.colima =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Inherit session variables so XDG_CONFIG_HOME, COLIMA_PROFILE, etc.
      # are baked into the plist, with no dependency on launchctl setenv ordering.
      inherit (config.system) primaryUser;
      homeDir = config.home-manager.users.${primaryUser}.home.homeDirectory;
      sessionVars = config.home-manager.users.${primaryUser}.home.sessionVariables;

      # Ensure the narrow scratch mount directory exists with 0700 permissions
      # before Colima starts so Colima never falls back to mounting $HOME.
      colimaStart = pkgs.writeShellScript "colima-launchd-start" ''
        /bin/mkdir -p -m 0700 ${lib.escapeShellArg "${homeDir}/colima-shared"}
        exec "${pkgs.colima}/bin/colima" start --foreground --save-config=false
      '';
    in
    {
      environment.systemPackages = [ pkgs.colima ];

      launchd.user.agents.colima = {
        serviceConfig = {
          ProgramArguments = [ "${colimaStart}" ];
          RunAtLoad = true;
          KeepAlive = {
            # Restart on unexpected failures, but allow a clean manual stop.
            SuccessfulExit = false;
          };
          ThrottleInterval = 30;
          WorkingDirectory = homeDir;
          EnvironmentVariables = sessionVars // {
            PATH =
              lib.makeBinPath [
                pkgs.colima
                pkgs.docker-client
                pkgs.docker-compose
                pkgs.docker-credential-helpers
              ]
              + ":/usr/bin:/bin:/usr/sbin:/sbin";
          };
          StandardOutPath = "${homeDir}/Library/Logs/colima.stdout.log";
          StandardErrorPath = "${homeDir}/Library/Logs/colima.stderr.log";
        };
      };
    };
}
