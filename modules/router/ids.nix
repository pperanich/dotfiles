# Router intrusion detection and prevention via CrowdSec, with nftables
# and optional Caddy HTTP bouncers plus Prometheus/Grafana observability.
_: {
  flake.modules.nixos.routerIds =
    {
      config,
      lib,
      pkgs,
      options,
      ...
    }:
    let
      cfg = config.my.router;
      idsCfg = cfg.ids;
      enabled = cfg.enable && idsCfg.enable;

      csUser = config.services.crowdsec.user;
      csGroup = config.services.crowdsec.group;

      caddyBouncerDir = "/var/lib/crowdsec-caddy-bouncer";
      caddyBouncerEnvFile = "${caddyBouncerDir}/env";

      # Local DNS resolvers must be up before cscli fetches hub updates or registers CAPI.
      dnsDeps = [
        "nss-lookup.target"
      ]
      ++ lib.optional config.services.unbound.enable "unbound.service"
      ++ lib.optional config.services.blocky.enable "blocky.service";

      caddyBouncerEnabled = enabled && idsCfg.caddyBouncer.enable;
    in
    {
      options.my.router.ids = {
        enable = lib.mkEnableOption "CrowdSec intrusion detection and prevention";

        lapiPort = lib.mkOption {
          type = lib.types.port;
          default = 8089;
          description = "Loopback TCP port for CrowdSec Local API (avoids UniFi inform on 8080).";
        };

        metricsPort = lib.mkOption {
          type = lib.types.port;
          default = 6060;
          description = "Loopback TCP port for CrowdSec Prometheus metrics.";
        };

        bouncerMetricsPort = lib.mkOption {
          type = lib.types.port;
          default = 60601;
          description = "Loopback TCP port for the firewall bouncer Prometheus metrics.";
        };

        enableCapi = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Auto-register with CrowdSec Central API (CAPI) for the community blocklist.";
        };

        simulation = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Run CrowdSec in simulation mode (detect and record alerts without enforcing bans).";
        };

        whitelistCidrs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "100.64.0.0/10"
            "fc00::/7"
            "fe80::/10"
          ];
          description = "Extra CIDRs whitelisted from CrowdSec parsing/bans (RFC1918 and loopback are already whitelisted).";
        };

        firewallBouncer = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enforce CrowdSec bans in kernel nftables.";
          };

          hooks = lib.mkOption {
            type = lib.types.listOf (
              lib.types.enum [
                "input"
                "forward"
              ]
            );
            default = [
              "input"
              "forward"
            ];
            description = "Netfilter hooks managed by the firewall bouncer.";
          };

          priority = lib.mkOption {
            type = lib.types.int;
            default = -10;
            description = "nftables hook priority (negative runs before standard filter chains at 0).";
          };

          denyAction = lib.mkOption {
            type = lib.types.enum [
              "DROP"
              "REJECT"
            ];
            default = "DROP";
            description = "nftables verdict for banned source IPs.";
          };

          denyLog = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Emit kernel log entries for packets dropped by the bouncer.";
          };
        };

        caddyBouncer = {
          enable = lib.mkEnableOption "CrowdSec HTTP bouncer inside Caddy (enforces bans on Cloudflare Tunnel and HTTP vhosts)";

          bouncerName = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "caddy-bouncer";
            description = "Bouncer name registered with CrowdSec LAPI.";
          };

          tickerInterval = lib.mkOption {
            type = lib.types.str;
            default = "15s";
            description = "Interval for streaming decision deltas from LAPI.";
          };

          metricsInterval = lib.mkOption {
            type = lib.types.str;
            default = "15m";
            description = "Interval for pushing Caddy bouncer metrics to LAPI.";
          };
        };

        caddyLogs = {
          enable = lib.mkEnableOption "parse Caddy JSON access logs with crowdsecurity/caddy";

          files = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "/var/log/caddy/access-*.log" ];
            description = "Caddy JSON access log paths or globs to acquire.";
          };
        };

        vaultwardenLogs = {
          enable = lib.mkEnableOption "parse Vaultwarden auth logs with Dominic-Wagner/vaultwarden";
        };

        extraCollections = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional CrowdSec Hub collections to install.";
        };

        extraAcquisitions = lib.mkOption {
          type = lib.types.listOf (pkgs.formats.yaml { }).type;
          default = [ ];
          description = "Additional CrowdSec log acquisition entries.";
        };
      };

      config = lib.mkIf enabled (
        lib.mkMerge [
          {
            assertions = [
              {
                assertion = !idsCfg.caddyBouncer.enable || config.services.caddy.enable;
                message = "my.router.ids.caddyBouncer.enable requires services.caddy.enable.";
              }
              {
                assertion = !idsCfg.vaultwardenLogs.enable || config.services.vaultwarden.enable;
                message = "my.router.ids.vaultwardenLogs.enable requires services.vaultwarden.enable.";
              }
            ];

            # Raise WAN drop log budget so multi-port scans (15+ distinct ports) reliably trip iptables-scan-multi_ports.
            my.router.firewall = {
              wanDropLogRate = lib.mkDefault "120/minute";
              wanDropLogBurst = lib.mkDefault 50;
            };

            services.crowdsec = {
              enable = true;
              autoUpdateService = true;
              extraGroups = [
                "systemd-journal"
              ]
              ++ lib.optional idsCfg.caddyLogs.enable config.services.caddy.group;
              readOnlyPaths = lib.optional idsCfg.caddyLogs.enable "-${config.services.caddy.logDir}";

              hub.collections = [
                "crowdsecurity/linux"
                "crowdsecurity/iptables"
              ]
              ++ lib.optional idsCfg.caddyLogs.enable "crowdsecurity/caddy"
              ++ lib.optional idsCfg.vaultwardenLogs.enable "Dominic-Wagner/vaultwarden"
              ++ idsCfg.extraCollections;

              settings = {
                config = {
                  common.log_media = "stdout";
                  api.server = {
                    enable = true;
                    listen_uri = "127.0.0.1:${toString idsCfg.lapiPort}";
                  }
                  // lib.optionalAttrs idsCfg.enableCapi {
                    online_client.credentials_path = "/var/lib/crowdsec/data/online_api_credentials.yaml";
                  };
                  prometheus = {
                    enabled = true;
                    level = "full";
                    listen_addr = "127.0.0.1";
                    listen_port = idsCfg.metricsPort;
                  };
                };

                simulation.simulation = idsCfg.simulation;

                acquisitions = [
                  {
                    source = "journalctl";
                    journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
                    labels.type = "syslog";
                  }
                  {
                    source = "journalctl";
                    journalctl_filter = [
                      "-k"
                      "--grep=nft6?-drop-wan:"
                    ];
                    labels.type = "syslog";
                  }
                ]
                ++ lib.optional (idsCfg.caddyLogs.enable && idsCfg.caddyLogs.files != [ ]) {
                  source = "file";
                  filenames = idsCfg.caddyLogs.files;
                  force_inotify = true;
                  labels.type = "caddy";
                }
                ++ lib.optional idsCfg.vaultwardenLogs.enable {
                  source = "journalctl";
                  journalctl_filter = [ "_SYSTEMD_UNIT=vaultwarden.service" ];
                  labels.type = "syslog";
                }
                ++ idsCfg.extraAcquisitions;

                parsers.s02Enrich =
                  lib.optional (idsCfg.whitelistCidrs != [ ]) {
                    name = "local/router-whitelists";
                    description = "Whitelist local overlay and IPv6 ULA/link-local ranges";
                    whitelist = {
                      reason = "Router local and overlay networks";
                      cidr = idsCfg.whitelistCidrs;
                    };
                  }
                  ++ [
                    {
                      name = "local/ignore-nft-accept";
                      description = "Never treat lowercase nft-wan-accept logs as drops";
                      whitelist = {
                        reason = "Accepted WAN connection log";
                        expression = [
                          "evt.Parsed.message contains 'nft-wan-accept:'"
                          "evt.Parsed.message contains 'nft6-wan-accept:'"
                        ];
                      };
                    }
                  ];
              };
            };

            services.crowdsec-firewall-bouncer = lib.mkIf idsCfg.firewallBouncer.enable {
              enable = true;
              # Let the bouncer manage its own tables so input/forward hooks, priority, and per-origin counters work.
              createRulesets = false;
              registerBouncer.enable = true;
              settings = {
                mode = "nftables";
                deny_action = idsCfg.firewallBouncer.denyAction;
                deny_log = idsCfg.firewallBouncer.denyLog;
                deny_log_prefix = "crowdsec-drop: ";
                nftables = {
                  ipv4 = {
                    enabled = true;
                    set-only = false;
                    table = "crowdsec";
                    chain = "crowdsec-chain";
                    inherit (idsCfg.firewallBouncer) priority;
                  };
                  ipv6 = {
                    enabled = cfg.ipv6.enable;
                    set-only = false;
                    table = "crowdsec6";
                    chain = "crowdsec6-chain";
                    inherit (idsCfg.firewallBouncer) priority;
                  };
                };
                nftables_hooks = idsCfg.firewallBouncer.hooks;
                prometheus = {
                  enabled = true;
                  listen_addr = "127.0.0.1";
                  listen_port = idsCfg.bouncerMetricsPort;
                };
              };
            };

            systemd = {
              services = {
                crowdsec-setup = {
                  wants = [ "nss-lookup.target" ];
                  after = dnsDeps;
                };

                crowdsec-update-hub = {
                  wants = [ "nss-lookup.target" ];
                  after = dnsDeps;
                };

                crowdsec-firewall-bouncer = lib.mkIf idsCfg.firewallBouncer.enable {
                  serviceConfig = {
                    Restart = "on-failure";
                    RestartSec = 10;
                  };
                };

                crowdsec-caddy-bouncer-register = lib.mkIf caddyBouncerEnabled {
                  description = "Register Caddy CrowdSec bouncer with local CrowdSec API";
                  wantedBy = [ "multi-user.target" ];
                  after = [ "crowdsec.service" ];
                  wants = [ "crowdsec.service" ];
                  path = [
                    config.services.crowdsec.package
                    pkgs.jq
                  ];
                  script = ''
                    bouncer=${lib.escapeShellArg idsCfg.caddyBouncer.bouncerName}
                    envFile=${lib.escapeShellArg caddyBouncerEnvFile}
                    if cscli bouncers list --output json | jq -e --arg name "$bouncer" 'any((. // [])[]; .name == $name)' >/dev/null; then
                      if [ -s "$envFile" ]; then
                        exit 0
                      fi
                      cscli bouncers delete "$bouncer" || true
                    else
                      rm -f "$envFile"
                    fi
                    key=$(cscli bouncers add --output raw -- "$bouncer")
                    printf 'CROWDSEC_API_KEY=%s\n' "$key" > "$envFile.tmp"
                    chmod 0400 "$envFile.tmp"
                    mv "$envFile.tmp" "$envFile"
                  '';
                  serviceConfig = {
                    Type = "oneshot";
                    User = csUser;
                    Group = csGroup;
                    DynamicUser = true;
                    ReadWritePaths = [
                      "/var/lib/crowdsec"
                      caddyBouncerDir
                    ];
                    RestrictAddressFamilies = "none";
                    CapabilityBoundingSet = [ "" ];
                    LockPersonality = true;
                    PrivateDevices = true;
                    ProtectClock = true;
                    ProtectControlGroups = true;
                    ProtectHome = true;
                    ProtectHostname = true;
                    ProtectKernelLogs = true;
                    ProtectKernelModules = true;
                    ProtectKernelTunables = true;
                    ProtectProc = "invisible";
                    ProcSubset = "pid";
                    RestrictNamespaces = true;
                    RestrictRealtime = true;
                    SystemCallArchitectures = "native";
                    SystemCallFilter = [
                      "@system-service"
                      "~@privileged"
                      "~@resources"
                    ];
                    UMask = "0077";
                  };
                };

                caddy = lib.mkIf caddyBouncerEnabled {
                  after = [ "crowdsec-caddy-bouncer-register.service" ];
                  wants = [ "crowdsec-caddy-bouncer-register.service" ];
                  serviceConfig.EnvironmentFile = [ caddyBouncerEnvFile ];
                };
              };

              tmpfiles.settings."10-crowdsec-caddy-bouncer" = lib.mkIf caddyBouncerEnabled {
                ${caddyBouncerDir}.d = {
                  user = csUser;
                  group = csGroup;
                  mode = "0750";
                };
              };

              tmpfiles.rules = lib.optionals idsCfg.caddyLogs.enable (
                map (
                  f: "z ${f} 0640 ${config.services.caddy.user} ${config.services.caddy.group} -"
                ) idsCfg.caddyLogs.files
              );
            };

            services.caddy.globalConfig = lib.mkIf caddyBouncerEnabled ''
              order crowdsec first
              crowdsec {
                api_url http://127.0.0.1:${toString idsCfg.lapiPort}
                api_key {env.CROWDSEC_API_KEY}
                ticker_interval ${idsCfg.caddyBouncer.tickerInterval}
                metrics_interval ${idsCfg.caddyBouncer.metricsInterval}
                enable_caddy_metrics
              }
            '';
          }

          (lib.optionalAttrs (options.my ? caddyDns01) {
            my.caddyDns01.crowdsecBouncer = lib.mkIf caddyBouncerEnabled true;
          })

          (lib.optionalAttrs (options.my ? observability) {
            my.observability = {
              extraLocalTargets = [
                {
                  job = "crowdsec";
                  port = idsCfg.metricsPort;
                }
              ]
              ++ lib.optional idsCfg.firewallBouncer.enable {
                job = "crowdsec-bouncer";
                port = idsCfg.bouncerMetricsPort;
              };

              extraDashboards."crowdsec-metrics.json" = ./assets/dashboards/crowdsec-metrics.json;

              extraJournalUnits = [
                "crowdsec"
                "crowdsec-setup"
                "crowdsec-update-hub"
              ]
              ++ lib.optionals idsCfg.firewallBouncer.enable [
                "crowdsec-firewall-bouncer"
                "crowdsec-firewall-bouncer-register"
              ]
              ++ lib.optional caddyBouncerEnabled "crowdsec-caddy-bouncer-register";

              extraAlertRules = lib.optional idsCfg.enableCapi {
                alert = "CrowdSecCapiEmpty";
                expr = "absent(cs_active_decisions{origin=\"CAPI\"}) or sum(cs_active_decisions{origin=\"CAPI\"}) == 0";
                for = "2h";
                labels.severity = "warning";
                annotations.description = "CrowdSec has no active CAPI community blocklist decisions for 2 hours.";
              };
            };
          })
        ]
      );
    };
}
