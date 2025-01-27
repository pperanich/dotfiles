{ 
  config,
  lib,
  pkgs, 
  ... 
}: let
  cfg = config.my.features.skhd;
in {

  options.my.features.skhd = {
    enable = lib.mkEnableOption "Simple hot-key daemon.";
  };

  config = lib.mkIf cfg.enable {
    services = {
      skhd = {
        enable = true;
        package = pkgs.skhd;
      };
    };

    environment.systemPackages = [ pkgs.skhd ];

    # For skhd debugging
    launchd.user.agents.skhd.serviceConfig.StandardErrorPath = "/tmp/skhd.err.log";
    launchd.user.agents.skhd.serviceConfig.StandardOutPath = "/tmp/skhd.out.log";
  };
}
