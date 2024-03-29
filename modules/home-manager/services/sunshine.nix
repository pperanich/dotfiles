{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.sunshine;

in {
  options = {
    services.sunshine = {
      enable = mkEnableOption "Sunshine service";

      package = mkPackageOption pkgs "sunshine" { };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      (hm.assertions.assertPlatform "services.sunshine" pkgs platforms.linux)
    ];

    home.packages = [ cfg.package ];

    # Inspired from https://github.com/LizardByte/Sunshine/blob/5bca024899eff8f50e04c1723aeca25fc5e542ca/packaging/linux/sunshine.service.in
    systemd.user.services.sunshine = {
      Install.WantedBy = [ "graphical-session.target" ];
      Unit = {
        Description = "Sunshine server";
        PartOf = [ "graphical-session.target" ];
        StartLimitIntervalSec = 500;
        StartLimitBurst = 5;
      };
      Service = {
        ExecStart = getExe pkgs.sunshine;
        # ExecStart = "${config.security.wrapperDir}/sunshine ${configFile}/config/sunshine.conf";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
