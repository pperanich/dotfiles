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
        "fleet-health.json" = ./observability-assets/dashboards/fleet-health.json;
      };

      # Render alert email timestamps in the host timezone (UTC if unset)
      alertTimezone = if config.time.timeZone != null then config.time.timeZone else "Etc/UTC";

      mkPromRule = expr: alert: description: {
        inherit alert expr;
        for = "5m";
        labels.severity = "warning";
        annotations.description = description;
      };

      # Count kfree_skb tracepoint events per (device, drop reason) in a BPF
      # map; print the cumulative map every 30s for the converter to consume.
      dropMonitorCond = lib.concatMapStringsSep " || " (
        i: "$name == \"${i}\""
      ) cfg.dropMonitor.interfaces;
      dropMonitorScript = pkgs.writeText "netdev-drops.bt" ''
        tracepoint:skb:kfree_skb {
          $skb = (struct sk_buff *)args->skbaddr;
          if ($skb->dev != 0) {
            $name = str($skb->dev->name);
            if (${dropMonitorCond}) {
              @drops[$name, (uint64)args->reason] = count();
            }
          }
        }
        interval:s:30 { print(@drops); }
      '';
      # Resolve numeric reason ids against the running kernel's tracepoint
      # format (enum values shift between kernel versions) and publish
      # counters via the node-exporter textfile collector.
      dropMetricsConverter = pkgs.writeText "netdev-drop-metrics.py" ''
        import os
        import re
        import sys

        FMT = "/sys/kernel/tracing/events/skb/kfree_skb/format"
        OUT = "/var/lib/prometheus-node-exporter-text/netdev_drops.prom"
        HEADER = (
            "# HELP netdev_drop_reasons_total Packets freed with a kernel"
            " drop reason, by device (resets on service restart)\n"
            "# TYPE netdev_drop_reasons_total counter\n"
        )

        with open(FMT) as f:
            reasons = dict(re.findall(r'\{ (\d+), "([A-Z0-9_]+)" \}', f.read()))
        counts = {}
        line_re = re.compile(r'@drops\[(\S+), (\d+)\]: (\d+)')

        def write_out():
            tmp = OUT + ".tmp"
            with open(tmp, "w") as f:
                f.write(HEADER)
                for (dev, reason), cnt in sorted(counts.items()):
                    f.write(
                        'netdev_drop_reasons_total'
                        f'{{device="{dev}",reason="{reason}"}} {cnt}\n'
                    )
            os.replace(tmp, OUT)

        write_out()
        for line in sys.stdin:
            m = line_re.match(line)
            if not m:
                continue
            dev, num, cnt = m.groups()
            counts[(dev, reasons.get(num, "reason_" + num))] = cnt
            write_out()
      '';

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

        alerts = {
          email = {
            to = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Deliver Prometheus alerts to this address via Alertmanager (null disables Alertmanager)";
            };
            from = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              example = "alerts@example.com";
              description = "Envelope sender for alert emails; domain must be accepted by the local SMTP relay";
            };
          };

          deadman.pingUrlFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "File containing a healthchecks.io ping URL, hit every 5 minutes; missed pings alert externally when this host is down";
          };

          externalUrl = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "https://alerts.example.com";
            description = "External URL used for Alertmanager links in notifications";
          };

          carrierInterfaces = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [ "enp1s0f1np1" ];
            description = "Interfaces to alert on for sustained carrier loss and link flapping";
          };
        };

        smartctlTargets = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "pp-nas1.home.arpa:9633" ];
          description = "smartctl exporter targets to scrape for disk health";
        };

        nodeTargets = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "pp-nas1.home.arpa:9100" ];
          description = "Additional node exporter targets to scrape for host metrics";
        };

        dropMonitor = {
          enable = lib.mkEnableOption "per-reason packet drop metrics via the kfree_skb tracepoint";

          interfaces = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [
              "br-lan"
              "br-main"
            ];
            description = "Interfaces to count dropped packets on, labeled by kernel drop reason";
          };
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
                {
                  targets = [
                    "127.0.0.1:${toString config.services.prometheus.exporters.node.port}"
                  ]
                  ++ cfg.nodeTargets;
                }
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
          ++ lib.optionals (cfg.smartctlTargets != [ ]) [
            {
              job_name = "smartctl";
              static_configs = [ { targets = cfg.smartctlTargets; } ];
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
                    (mkPromRule "node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.1" "HostLowMemory"
                      "Memory available on {{ $labels.instance }} is below 10 percent."
                    )
                    (mkPromRule
                      "(node_filesystem_avail_bytes{fstype!~\"tmpfs|overlay|ramfs\"} / node_filesystem_size_bytes{fstype!~\"tmpfs|overlay|ramfs\"}) < 0.15"
                      "HostLowDiskSpace"
                      "Filesystem {{ $labels.mountpoint }} on {{ $labels.instance }} is below 15 percent available."
                    )
                    (mkPromRule "avg by (instance) (1 - rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) > 0.9" "HostHighCpu"
                      "CPU on {{ $labels.instance }} has been above 90 percent busy for 5 minutes."
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
                    (mkPromRule "rate(node_network_receive_drop_total{device=~\"br-.*|enp.*\"}[5m]) > 0.1"
                      "RouterInterfaceRxDrops"
                      "Interface {{ $labels.device }} is dropping incoming packets ({{ $value | humanize }}/s)."
                    )
                    (mkPromRule "rate(node_network_transmit_drop_total{device=~\"br-.*|enp.*\"}[5m]) > 0.1"
                      "RouterInterfaceTxDrops"
                      "Interface {{ $labels.device }} is dropping outgoing packets ({{ $value | humanize }}/s)."
                    )
                    # Reason-attributed companion to the drop alerts above.
                    # Constant router background, excluded: OTHERHOST (flooded
                    # frames for other MACs), NETFILTER_DROP (firewall doing
                    # its job), NOT_SPECIFIED (catch-all for routine stack
                    # discards like non-member multicast; never increments
                    # rx_dropped, so the counter alerts above still cover it).
                    (mkPromRule
                      "sum by (device, reason) (rate(netdev_drop_reasons_total{reason!~\"OTHERHOST|NETFILTER_DROP|NOT_SPECIFIED\"}[5m])) > 0.1"
                      "RouterInterfaceDropReasons"
                      "Interface {{ $labels.device }} dropping packets, kernel reason {{ $labels.reason }} ({{ $value | humanize }}/s)."
                    )
                    (mkPromRule "node_hwmon_temp_celsius{chip=~\".*coretemp.*\"} > 85" "HostCpuHot"
                      "CPU sensor {{ $labels.sensor }} on {{ $labels.instance }} above 85C for 5 minutes."
                    )
                    {
                      # DDR5 SPD sensors — join via chip_names since i2c bus ids can renumber
                      alert = "HostMemoryDimmHot";
                      expr = "(node_hwmon_temp_celsius and on (instance, chip) node_hwmon_chip_names{chip_name=\"spd5118\"}) > 55";
                      for = "10m";
                      labels.severity = "warning";
                      annotations.description = "DIMM sensor {{ $labels.chip }} on {{ $labels.instance }} above 55C for 10 minutes.";
                    }
                    (mkPromRule "(probe_ssl_earliest_cert_expiry - time()) < 14 * 86400" "CertExpiringSoon"
                      "TLS certificate for {{ $labels.instance }} expires in less than 14 days."
                    )
                    (mkPromRule "probe_success{job=\"blackbox-http\"} == 0" "HttpProbeFailing"
                      "HTTP probe against {{ $labels.instance }} has been failing for 5 minutes."
                    )
                    {
                      alert = "SystemdUnitFailed";
                      expr = "node_systemd_unit_state{state=\"failed\"} == 1";
                      for = "10m";
                      labels.severity = "warning";
                      annotations.description = "Unit {{ $labels.name }} on {{ $labels.instance }} has been failed for 10 minutes.";
                    }
                    {
                      alert = "ZfsPoolUnhealthy";
                      expr = "node_zfs_zpool_state{state!=\"online\"} == 1";
                      for = "5m";
                      labels.severity = "critical";
                      annotations.description = "ZFS pool {{ $labels.zpool }} on {{ $labels.instance }} is {{ $labels.state }}.";
                    }
                    {
                      # Informational: fires for ~10 minutes after any boot, planned or not
                      alert = "HostRebooted";
                      expr = "time() - node_boot_time_seconds < 600";
                      for = "1m";
                      labels.severity = "warning";
                      annotations.description = "{{ $labels.instance }} rebooted less than 10 minutes ago.";
                    }
                    {
                      # 250ms sustained is ~100x healthy NTP jitter yet under the ~0.5s step threshold
                      alert = "HostClockDrift";
                      expr = "abs(node_timex_offset_seconds) > 0.25";
                      for = "15m";
                      labels.severity = "warning";
                      annotations.description = "Clock on {{ $labels.instance }} has drifted more than 250ms from NTP for 15 minutes.";
                    }
                    (mkPromRule "increase(node_vmstat_oom_kill[1h]) > 0" "HostOomKills"
                      "The OOM killer fired on {{ $labels.instance }} within the last hour."
                    )
                    {
                      alert = "BackupStale";
                      expr = "time() - borg_last_success_timestamp_seconds > 172800";
                      for = "30m";
                      labels.severity = "critical";
                      annotations.description = "Borg backup on {{ $labels.instance }} has not succeeded in over 48 hours.";
                    }
                    {
                      # Expected to fire once after deploy until the first successful backup stamps the metric
                      alert = "BackupMetricMissing";
                      expr = "absent(borg_last_success_timestamp_seconds)";
                      for = "6h";
                      labels.severity = "warning";
                      annotations.description = "No borg backup success metric has been scraped for 6 hours.";
                    }
                    (mkPromRule "kea_dhcp4_addresses_assigned_total / kea_dhcp4_addresses_total > 0.9" "DhcpPoolNearlyFull"
                      "DHCP subnet {{ $labels.subnet }} is above 90 percent lease utilization."
                    )
                  ]
                  ++ lib.optionals (cfg.smartctlTargets != [ ]) [
                    {
                      alert = "DiskSmartFailure";
                      expr = "smartctl_device_smart_status == 0";
                      for = "5m";
                      labels.severity = "critical";
                      annotations.description = "SMART reports failing status for {{ $labels.device }} on {{ $labels.instance }}.";
                    }
                    (mkPromRule "smartctl_device_media_errors > 0" "DiskMediaErrors"
                      "A disk is reporting media errors."
                    )
                    (mkPromRule "smartctl_device_available_spare < 50" "DiskSpareLow"
                      "NVMe available spare below 50 percent."
                    )
                    (mkPromRule "smartctl_device_temperature{temperature_type=\"current\"} > 70" "DiskTemperatureHigh"
                      "Disk temperature above 70C for 5 minutes."
                    )
                    (mkPromRule "up{job=\"smartctl\"} == 0" "SmartctlExporterDown"
                      "A smartctl exporter target has been down for 5 minutes."
                    )
                  ]
                  ++ lib.concatMap (iface: [
                    {
                      alert = "InterfaceCarrierLost";
                      expr = "node_network_carrier{device=\"${iface}\"} == 0";
                      for = "1m";
                      labels.severity = "critical";
                      annotations.description = "Interface ${iface} has had no carrier for 1 minute.";
                    }
                    {
                      alert = "InterfaceFlapping";
                      expr = "increase(node_network_carrier_changes_total{device=\"${iface}\"}[15m]) > 4";
                      labels.severity = "warning";
                      annotations.description = "Interface ${iface} carrier changed more than 4 times in 15 minutes.";
                    }
                  ]) cfg.alerts.carrierInterfaces;
                }
              ];
            })
          ];
        };

        # Alerts leave via local Stalwart relay over WAN — independent of the
        # LAN path, so delivery survives a dead trunk (local dashboards don't).
        services.prometheus.alertmanager = lib.mkIf (cfg.alerts.email.to != null) {
          enable = true;
          listenAddress = "127.0.0.1";
          port = 9093;
          webExternalUrl = lib.mkIf (cfg.alerts.externalUrl != null) cfg.alerts.externalUrl;
          configuration = {
            global = {
              smtp_smarthost = "127.0.0.1:25";
              smtp_from = cfg.alerts.email.from;
              smtp_require_tls = false;
            };
            route = {
              receiver = "email";
              group_by = [ "alertname" ];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "4h";
            };
            receivers = [
              {
                name = "email";
                email_configs = [
                  {
                    to = cfg.alerts.email.to;
                    send_resolved = true;
                    # Default subject plus alert start time rendered in the
                    # host timezone (Alertmanager templates emit UTC otherwise)
                    headers.Subject = ''{{ template "email.default.subject" . }} [{{ (index .Alerts 0).StartsAt | tz "${alertTimezone}" | date "Jan 2 3:04PM MST" }}]'';
                  }
                ];
              }
            ];
          };
        };

        services.prometheus.alertmanagers = lib.mkIf (cfg.alerts.email.to != null) [
          { static_configs = [ { targets = [ "127.0.0.1:9093" ]; } ]; }
        ];

        assertions = [
          {
            assertion = cfg.alerts.email.to == null || cfg.alerts.email.from != null;
            message = "my.observability.alerts.email.from must be set when alerts.email.to is set";
          }
        ];

        # Dead-man's switch: external service alerts when pings stop arriving,
        # covering whole-host failure that local alerting can't report.
        systemd.services.deadman-ping = lib.mkIf (cfg.alerts.deadman.pingUrlFile != null) {
          description = "Dead-man's switch ping";
          serviceConfig.Type = "oneshot";
          script = ''
            url=$(cat ${cfg.alerts.deadman.pingUrlFile})
            case "$url" in
              https://*) ${pkgs.curl}/bin/curl -fsS -m 10 --retry 3 -o /dev/null "$url" ;;
              *) echo "ping URL not configured yet, skipping" ;;
            esac
          '';
        };

        systemd.timers.deadman-ping = lib.mkIf (cfg.alerts.deadman.pingUrlFile != null) {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "2m";
            OnUnitActiveSec = "5m";
          };
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
            # Query dhcp4's unix control socket directly (ctrl-agent lacks a
            # control-sockets forwarding map, so stats never flowed over HTTP)
            targets = [ "/run/kea/kea-dhcp4.socket" ];
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

        # Attribute interface packet drops to kernel drop reasons so the
        # RxDrops-style alerts can say *why* packets were dropped.
        systemd.services.netdev-drop-metrics =
          lib.mkIf (cfg.dropMonitor.enable && cfg.dropMonitor.interfaces != [ ])
            {
              description = "Per-reason packet drop metrics for node-exporter";
              wantedBy = [ "multi-user.target" ];
              after = [ "network.target" ];
              serviceConfig = {
                Restart = "always";
                RestartSec = "10s";
              };
              script = ''
                ${pkgs.bpftrace}/bin/bpftrace ${dropMonitorScript} \
                  | ${pkgs.python3}/bin/python3 ${dropMetricsConverter}
              '';
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
              # Default advertises first non-loopback addr in the ring, but
              # gRPC only listens on loopback
              instance_addr = "127.0.0.1";
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
          # No local InfluxDB; Prometheus scrapes the exporter instead
          influxdb.disable = true;
          unifi = {
            controllers = [
              {
                url = cfg.unpoller.controllerUrl;
                inherit (cfg.unpoller) user;
                pass = cfg.unpoller.passwordFile;
                save_sites = true;
                # Controller lacks /stat/event endpoint (404 on every poll)
                save_events = false;
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
