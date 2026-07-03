# Node exporter for fleet hosts scraped by pp-router1's Prometheus,
# with the textfile collector for host-local custom metrics.
_: {
  flake.modules.nixos.nodeMetrics =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.nodeMetrics;
      textfileDir = "/var/lib/prometheus-node-exporter-text";
    in
    {
      options.my.nodeMetrics = {
        enable = lib.mkEnableOption "node exporter for Prometheus scraping";

        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address for the node exporter to listen on";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 9100;
          description = "Port for the node exporter";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Open the firewall for the node exporter (needed when scraped from another host)";
        };
      };

      config = lib.mkIf cfg.enable {
        services.prometheus.exporters.node = {
          enable = true;
          inherit (cfg) listenAddress port openFirewall;
          enabledCollectors = [
            "systemd"
            "textfile"
          ];
          extraFlags = [ "--collector.textfile.directory=${textfileDir}" ];
        };

        systemd.tmpfiles.rules = [ "d ${textfileDir} 0755 root root -" ];
      };
    };
}
