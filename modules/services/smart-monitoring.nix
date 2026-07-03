# SMART disk health: smartd for local scheduled self-tests plus the
# smartctl Prometheus exporter for scraping by the observability stack.
_: {
  flake.modules.nixos.smartMonitoring =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.smartMonitoring;
    in
    {
      options.my.smartMonitoring = {
        enable = lib.mkEnableOption "SMART disk health monitoring (smartd + smartctl exporter)";

        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address for the smartctl exporter to listen on";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 9633;
          description = "Port for the smartctl exporter";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Open the firewall for the smartctl exporter (needed when scraped from another host)";
        };
      };

      config = lib.mkIf cfg.enable {
        services.smartd = {
          enable = true;
          autodetect = true;
        };

        services.prometheus.exporters.smartctl = {
          enable = true;
          inherit (cfg) listenAddress port openFirewall;
        };
      };
    };
}
