# Journal log shipping to a remote Loki via Grafana Alloy.
#
# For fleet hosts that don't run the observability stack themselves:
# ships a unit-filtered journal stream to the Loki instance on the
# router so SystemdUnitFailed alerts have log context. Uses the same
# label scheme (job/host/unit/priority) as the router's local pipeline.
_: {
  flake.modules.nixos.logShipping =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.logShipping;
    in
    {
      options.my.logShipping = {
        lokiUrl = lib.mkOption {
          type = lib.types.str;
          example = "http://10.0.0.1:3100";
          description = "Base URL of the Loki instance to push logs to.";
        };

        keepUnits = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "sshd"
            "smartd"
          ];
          description = "Systemd unit name regex fragments (without .service) whose journal entries are shipped.";
        };
      };

      config = {
        services.alloy = {
          enable = true;
          # Alloy's own HTTP/UI port — keep it loopback-only
          extraFlags = [ "--server.http.listen-addr=127.0.0.1:9080" ];
        };

        # Journal access for the DynamicUser'd alloy service
        systemd.services.alloy.serviceConfig.SupplementaryGroups = [ "systemd-journal" ];

        environment.etc."alloy/config.alloy".text = ''
          loki.write "remote" {
            endpoint {
              url = "${cfg.lokiUrl}/loki/api/v1/push"
            }
          }

          loki.relabel "journal" {
            forward_to = []

            rule {
              source_labels = ["__journal__systemd_unit"]
              regex = "(${lib.concatStringsSep "|" cfg.keepUnits})\\.service"
              action = "keep"
            }
            rule {
              source_labels = ["__journal__systemd_unit"]
              target_label = "unit"
            }
            rule {
              source_labels = ["__journal__syslog_identifier"]
              target_label = "syslog_identifier"
            }
            rule {
              source_labels = ["__journal_priority_keyword"]
              target_label = "priority"
            }
            rule {
              source_labels = ["__journal__transport"]
              target_label = "transport"
            }
          }

          loki.source.journal "journal" {
            max_age = "12h"
            relabel_rules = loki.relabel.journal.rules
            labels = {
              job = "journal",
              host = "${config.networking.hostName}",
            }
            forward_to = [loki.write.remote.receiver]
          }
        '';
      };
    };
}
