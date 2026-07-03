_: {
  flake.modules.nixos.observability =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.observability;
      enabled = cfg.enable;

      dashboardDir = "/var/lib/grafana/dashboards";

      mkDashboardCopyRule = name: src: "C+ ${dashboardDir}/${name} 0640 grafana grafana - ${src}";

      dashboardFiles = {
        "router-overview.json" = ./observability-assets/dashboards/router-overview.json;
        "dns-stack.json" = ./observability-assets/dashboards/dns-stack.json;
        "service-health.json" = ./observability-assets/dashboards/service-health.json;
        "logs-overview.json" = ./observability-assets/dashboards/logs-overview.json;
        "wan-remote-access.json" = ./observability-assets/dashboards/wan-remote-access.json;
      };

      mkPromRule = expr: alert: description: {
        inherit alert expr;
        for = "5m";
        labels.severity = "warning";
        annotations.description = description;
      };

      blackboxRelabelConfigs = [
        {
          source_labels = [ "__address__" ];
          target_label = "__param_target";
        }
        {
          source_labels = [ "__param_target" ];
          target_label = "instance";
        }
        {
          target_label = "__address__";
          replacement = "127.0.0.1:${toString config.services.prometheus.exporters.blackbox.port}";
        }
      ];
    in
    {
      options.my.observability = {
        enable = lib.mkEnableOption "local observability stack";

        grafana.hostname = lib.mkOption {
          type = lib.types.str;
          default = "grafana.prestonperanich.com";
          description = "Grafana hostname exposed through the local Caddy instance";
        };

        prometheus.retentionTime = lib.mkOption {
          type = lib.types.str;
          default = "14d";
          description = "Prometheus data retention window";
        };

        loki.retentionPeriod = lib.mkOption {
          type = lib.types.str;
          default = "168h";
          description = "Loki retention window";
        };

        blackbox.httpTargets = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "https://${cfg.grafana.hostname}" ];
          description = "HTTP endpoints to probe with blackbox exporter";
        };

        unpoller = {
          enable = lib.mkEnableOption "UniFi metrics collection via unpoller";

          controllerUrl = lib.mkOption {
            type = lib.types.str;
            default = "https://127.0.0.1:8443";
            description = "URL of the UniFi controller to poll";
          };

          user = lib.mkOption {
            type = lib.types.str;
            default = "unpoller";
            description = "Read-only UniFi controller user for metrics collection";
          };

          passwordFile = lib.mkOption {
            type = lib.types.path;
            description = "Path to file containing the unpoller user's password";
          };
        };
      };

      config = lib.mkIf enabled {
        services.prometheus = {
          enable = true;
          listenAddress = "127.0.0.1";
          port = 9090;
          inherit (cfg.prometheus) retentionTime;
          globalConfig = {
            scrape_interval = "30s";
            evaluation_interval = "30s";
          };
          scrapeConfigs = [
            {
              job_name = "prometheus";
              static_configs = [ { targets = [ "127.0.0.1:9090" ]; } ];
            }
            {
              job_name = "grafana";
              static_configs = [ { targets = [ "127.0.0.1:3010" ]; } ];
            }
            {
              job_name = "loki";
              metrics_path = "/metrics";
              static_configs = [ { targets = [ "127.0.0.1:3100" ]; } ];
            }
            {
              job_name = "blocky";
              metrics_path = "/metrics";
              static_configs = [ { targets = [ "127.0.0.1:${toString config.my.router.blocky.httpPort}" ]; } ];
            }
            {
              job_name = "node";
              static_configs = [
                { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ]; }
              ];
            }
            {
              job_name = "unbound";
              static_configs = [
                { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.unbound.port}" ]; }
              ];
            }
            {
              job_name = "kea";
              static_configs = [
                { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.kea.port}" ]; }
              ];
            }
            {
              job_name = "wireguard";
              static_configs = [
                { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.wireguard.port}" ]; }
              ];
            }
          ]
          ++ lib.optionals cfg.unpoller.enable [
            {
              job_name = "unpoller";
              static_configs = [ { targets = [ "127.0.0.1:9130" ]; } ];
            }
          ]
          ++ [
            {
              job_name = "blackbox-icmp";
              metrics_path = "/probe";
              params = {
                module = [ "icmp_v4" ];
              };
              static_configs = [
                {
                  targets = [
                    "1.1.1.1"
                    "9.9.9.9"
                  ];
                }
              ];
              relabel_configs = blackboxRelabelConfigs;
            }
            {
              job_name = "blackbox-tcp";
              metrics_path = "/probe";
              params = {
                module = [ "tcp_connect" ];
              };
              static_configs = [
                {
                  targets = [
                    "1.1.1.1:853"
                    "9.9.9.9:853"
                  ];
                }
              ];
              relabel_configs = blackboxRelabelConfigs;
            }
            {
              job_name = "blackbox-dns";
              metrics_path = "/probe";
              params = {
                module = [ "dns_udp" ];
                target = [ "google.com" ];
              };
              static_configs = [ { targets = [ "127.0.0.1:53" ]; } ];
              relabel_configs = blackboxRelabelConfigs;
            }
            {
              job_name = "blackbox-http";
              metrics_path = "/probe";
              params = {
                module = [ "http_2xx" ];
              };
              static_configs = [ { targets = cfg.blackbox.httpTargets; } ];
              relabel_configs = blackboxRelabelConfigs;
            }
          ];
          rules = [
            (builtins.toJSON {
              groups = [
                {
                  name = "observability";
                  rules = [
                    (mkPromRule "up{job=~\"prometheus|grafana|loki|blocky|node|unbound|kea|wireguard|unpoller\"} == 0"
                      "ObservabilityTargetDown"
                      "An observability target has been down for 5 minutes."
                    )
                    (mkPromRule "probe_success{job=\"blackbox-icmp\"} == 0" "RouterIcmpProbeFailing"
                      "External ICMP probe has been failing for 5 minutes."
                    )
                    (mkPromRule "probe_success{job=\"blackbox-tcp\"} == 0" "RouterTcpProbeFailing"
                      "External TCP probe has been failing for 5 minutes."
                    )
                    (mkPromRule "probe_success{job=\"blackbox-dns\"} == 0" "RouterDnsProbeFailing"
                      "DNS probing through the local resolver has been failing for 5 minutes."
                    )
                    (mkPromRule "node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.1" "RouterLowMemory"
                      "Router memory available is below 10 percent."
                    )
                    (mkPromRule
                      "(node_filesystem_avail_bytes{mountpoint=\"/\",fstype!=\"tmpfs\"} / node_filesystem_size_bytes{mountpoint=\"/\",fstype!=\"tmpfs\"}) < 0.15"
                      "RouterLowDiskSpace"
                      "Router root filesystem available space is below 15 percent."
                    )
                    (mkPromRule "rate(node_cpu_seconds_total{mode!=\"idle\"}[5m]) > 0.9" "RouterHighCpu"
                      "Router CPU busy time has remained high for 5 minutes."
                    )
                    (mkPromRule
                      "increase(node_systemd_unit_state{name=~\"systemd-networkd.service|unbound.service|blocky.service|kea-dhcp4-server.service\",state=\"failed\"}[15m]) > 0"
                      "RouterCoreServiceFailed"
                      "A core router service entered failed state in the last 15 minutes."
                    )
                    (mkPromRule "node_nf_conntrack_entries / node_nf_conntrack_entries_limit > 0.8"
                      "RouterConntrackHigh"
                      "Connection tracking table is above 80 percent capacity."
                    )
                    (mkPromRule "rate(node_network_receive_drop_total{device=~\"br-.*|enp.*\"}[5m]) > 0"
                      "RouterInterfaceRxDrops"
                      "Network interface is dropping incoming packets."
                    )
                    (mkPromRule "rate(node_network_transmit_drop_total{device=~\"br-.*|enp.*\"}[5m]) > 0"
                      "RouterInterfaceTxDrops"
                      "Network interface is dropping outgoing packets."
                    )
                  ];
                }
              ];
            })
          ];
        };

        services.prometheus.exporters = {
          node = {
            enable = true;
            listenAddress = "127.0.0.1";
            enabledCollectors = [
              "systemd"
              "textfile"
            ];
            extraFlags = [
              "--collector.textfile.directory=/var/lib/prometheus-node-exporter-text"
            ];
          };
          blackbox = {
            enable = true;
            listenAddress = "127.0.0.1";
            configFile = ./observability-assets/blackbox.yml;
          };
          unbound = {
            enable = true;
            listenAddress = "127.0.0.1";
          };
          kea = {
            enable = true;
            listenAddress = "127.0.0.1";
            targets = [ "http://127.0.0.1:8000" ];
          };
          wireguard = {
            enable = true;
            listenAddress = "127.0.0.1";
            interfaces = [ "pp-wg" ];
            latestHandshakeDelay = true;
          };
        };

        # Export nftables named counters (wan_input_drop, wan_new_accept_*)
        # as Prometheus metrics via the node-exporter textfile collector.
        # (Textfile dir tmpfiles rule lives in the shared list below.)
        systemd.services.nftables-metrics = lib.mkIf config.networking.nftables.enable {
          description = "Export nftables named counters for node-exporter";
          path = [
            pkgs.nftables
            pkgs.jq
            pkgs.coreutils
          ];
          serviceConfig.Type = "oneshot";
          script = ''
            out=/var/lib/prometheus-node-exporter-text/nftables.prom
            tmp="$out.tmp"
            {
              echo "# HELP nftables_counter_packets Packets seen by nftables named counter"
              echo "# TYPE nftables_counter_packets counter"
              echo "# HELP nftables_counter_bytes Bytes seen by nftables named counter"
              echo "# TYPE nftables_counter_bytes counter"
              nft --json list counters | jq -r '
                .nftables[] | select(.counter) | .counter |
                "nftables_counter_packets{family=\"\(.family)\",table=\"\(.table)\",name=\"\(.name)\"} \(.packets)",
                "nftables_counter_bytes{family=\"\(.family)\",table=\"\(.table)\",name=\"\(.name)\"} \(.bytes)"
              '
            } > "$tmp" && mv "$tmp" "$out"
          '';
        };

        systemd.timers.nftables-metrics = lib.mkIf config.networking.nftables.enable {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "30s";
            OnUnitActiveSec = "15s";
            AccuracySec = "1s";
          };
        };

        services.grafana = {
          enable = true;
          provision.enable = true;
          settings = {
            analytics = {
              reporting_enabled = false;
              check_for_updates = false;
              check_for_plugin_updates = false;
            };
            metrics.enabled = true;
            server = {
              http_addr = "127.0.0.1";
              http_port = 3010;
              domain = cfg.grafana.hostname;
              root_url = "https://${cfg.grafana.hostname}";
              enforce_domain = true;
            };
            security = {
              admin_user = "admin";
              admin_password = "$__file{${config.sops.secrets.grafana-admin-password.path}}";
              secret_key = "$__file{${config.sops.secrets.grafana-secret-key.path}}";
            };
            users = {
              allow_sign_up = false;
              allow_org_create = false;
            };
          };
          provision = {
            datasources.settings = {
              apiVersion = 1;
              prune = true;
              datasources = [
                {
                  name = "Prometheus";
                  uid = "prometheus";
                  type = "prometheus";
                  access = "proxy";
                  url = "http://127.0.0.1:9090";
                  isDefault = true;
                }
                {
                  name = "Loki";
                  uid = "loki";
                  type = "loki";
                  access = "proxy";
                  url = "http://127.0.0.1:3100";
                }
              ];
            };
            dashboards.settings = {
              apiVersion = 1;
              providers = [
                {
                  name = "Observability";
                  orgId = 1;
                  folder = "Observability";
                  type = "file";
                  disableDeletion = false;
                  allowUiUpdates = false;
                  updateIntervalSeconds = 30;
                  options.path = dashboardDir;
                }
              ];
            };
          };
        };

        services.loki = {
          enable = true;
          configuration = {
            auth_enabled = false;
            server = {
              http_listen_address = "127.0.0.1";
              http_listen_port = 3100;
              grpc_listen_address = "127.0.0.1";
              grpc_listen_port = 9096;
            };
            common = {
              path_prefix = "/var/lib/loki";
              replication_factor = 1;
              ring.kvstore.store = "inmemory";
            };
            schema_config.configs = [
              {
                from = "2024-01-01";
                store = "tsdb";
                object_store = "filesystem";
                schema = "v13";
                index = {
                  prefix = "index_";
                  period = "24h";
                };
              }
            ];
            storage_config = {
              filesystem.directory = "/var/lib/loki/chunks";
            };
            ingester = {
              chunk_encoding = "snappy";
              wal = {
                enabled = true;
                dir = "/var/lib/loki/wal";
              };
            };
            compactor = {
              working_directory = "/var/lib/loki/compactor";
              retention_enabled = true;
              delete_request_store = "filesystem";
            };
            limits_config = {
              retention_period = cfg.loki.retentionPeriod;
              reject_old_samples = true;
              reject_old_samples_max_age = "168h";
            };
          };
        };

        # Log shipping via Grafana Alloy (promtail was removed in NixOS 26.05).
        # Same pipeline as the old promtail config: journal (filtered to the
        # services we care about) + blocky query-log files → local Loki.
        services.alloy = {
          enable = true;
          # Alloy's own HTTP/UI port — keep it loopback-only
          extraFlags = [ "--server.http.listen-addr=127.0.0.1:9080" ];
        };

        # Journal access for the DynamicUser'd alloy service
        systemd.services.alloy.serviceConfig.SupplementaryGroups = [ "systemd-journal" ];

        environment.etc."alloy/config.alloy".text = ''
          loki.write "local" {
            endpoint {
              url = "http://127.0.0.1:3100/loki/api/v1/push"
            }
          }

          loki.relabel "journal" {
            forward_to = []

            rule {
              source_labels = ["__journal__systemd_unit"]
              regex = "(systemd-networkd|nftables|unbound|blocky|kea-dhcp4-server|kea-unbound-sync|caddy|cloudflared|prometheus|grafana|loki|alloy|homepage-dashboard|sshd)\\.service"
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
            forward_to = [loki.write.local.receiver]
          }

          local.file_match "blocky" {
            path_targets = [{
              __path__ = "/var/log/blocky/*",
              job = "blocky-file",
              host = "${config.networking.hostName}",
            }]
          }

          loki.source.file "blocky" {
            targets = local.file_match.blocky.targets
            forward_to = [loki.write.local.receiver]
          }

          // Kernel messages carry no systemd unit, so the journal source
          // above never ships them. nftables log rules (nft-drop-wan:,
          // nft-wan-accept:, nft-drop-input:, ...) are kernel messages —
          // ship only those, drop the rest of the kernel firehose.
          loki.source.journal "kernel" {
            max_age = "12h"
            matches = "_TRANSPORT=kernel"
            labels = {
              job = "kernel",
              host = "${config.networking.hostName}",
            }
            forward_to = [loki.process.nftlogs.receiver]
          }

          loki.process "nftlogs" {
            forward_to = [loki.write.local.receiver]
            stage.match {
              selector = "{job=\"kernel\"} !~ \"nft6?-\""
              action = "drop"
            }
          }
        '';

        services.unpoller = lib.mkIf cfg.unpoller.enable {
          enable = true;
          unifi = {
            controllers = [
              {
                url = cfg.unpoller.controllerUrl;
                inherit (cfg.unpoller) user;
                pass = cfg.unpoller.passwordFile;
                save_sites = true;
                save_events = true;
                save_alarms = true;
                save_dpi = false;
                verify_ssl = false;
              }
            ];
          };
          prometheus = {
            http_listen = "127.0.0.1:9130";
          };
        };

        systemd.tmpfiles.rules = [
          "d ${dashboardDir} 0750 grafana grafana -"
          "d /var/lib/prometheus-node-exporter-text 0755 root root -"
        ]
        ++ lib.mapAttrsToList mkDashboardCopyRule dashboardFiles;
      };
    };
}
