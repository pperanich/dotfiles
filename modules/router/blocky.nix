# DNS ad-blocking proxy: Blocky sits in front of Unbound
#
# Architecture: Clients → Blocky (:53) → Unbound (:5335) → upstream DoT
# Blocky handles ad-blocking, per-VLAN filtering, metrics, and query logging.
# Unbound handles DNSSEC validation, DoT forwarding, local zone, and DDNS records.
#
# Requires: routerDns (Unbound backend). Enable with my.router.blocky.enable = true.
_: {
  flake.modules.nixos.routerBlocky =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.router;
      blockyCfg = cfg.blocky;
      dnsCfg = cfg.dns;
      enabled = cfg.enable && dnsCfg.enable && blockyCfg.enable;

      # VLAN networks (exclude main LAN — its IP is already in cfg.lan.address)
      vlanNets = lib.filterAttrs (_: n: (n.vlan or null) != null) (cfg._internal.networks or { });

      # All addresses Blocky should listen on (same set Unbound currently uses)
      listenAddresses = [
        "127.0.0.1"
        "::1"
        cfg.lan.address
      ]
      ++ lib.optional cfg.ipv6.enable "${cfg.ipv6.ulaPrefix}::1"
      ++ dnsCfg.extraInterfaces
      ++ lib.mapAttrsToList (_: net: net.routerIp) vlanNets;

      # Format address for Blocky ports.dns (IPv6 needs brackets)
      formatDnsAddr = addr: if lib.hasInfix ":" addr then "[${addr}]:53" else "${addr}:53";

      dnsBindAddresses = map formatDnsAddr listenAddresses;

      # Auto-derive per-subnet blocking from network segments when user doesn't set explicit groups
      # Only VLAN networks get explicit CIDR entries — main LAN is covered by "default"
      autoClientGroups = {
        default = [
          "ads"
          "malware"
        ];
      }
      // lib.mapAttrs' (_name: net: {
        name = net.cidr;
        value =
          if net.isolation == "internet" then
            [
              "ads"
              "malware"
              "telemetry"
            ]
          else
            [
              "ads"
              "malware"
            ];
      }) vlanNets;

      effectiveClientGroups =
        if blockyCfg.clientGroupsBlock != { } then blockyCfg.clientGroupsBlock else autoClientGroups;

      # Build conditional mapping: local zone + private domains → Unbound backend
      localZone = lib.removeSuffix "." dnsCfg.localZone;
      conditionalMappings = {
        "${localZone}" = "127.0.0.1:5335";
      }
      // lib.listToAttrs (
        map (d: {
          name = d;
          value = "127.0.0.1:5335";
        }) dnsCfg.privateDomains
      );
    in
    {
      options.my.router.blocky = {
        enable = lib.mkEnableOption "Blocky DNS ad-blocker (in front of Unbound)";

        httpPort = lib.mkOption {
          type = lib.types.port;
          default = 4000;
          description = "HTTP port for API and Prometheus metrics";
        };

        denylists = lib.mkOption {
          type = lib.types.attrsOf (lib.types.listOf lib.types.str);
          default = {
            ads = [
              "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
              "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/pro.txt"
            ];
            malware = [
              "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/tif.mini.txt"
            ];
            telemetry = [
              "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/native.winoffice.txt"
              "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/native.tiktok.extended.txt"
              "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/native.amazon.txt"
              "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/native.apple.txt"
            ];
          };
          description = "Named groups of denylist URLs for ad/malware/telemetry blocking";
        };

        allowlists = lib.mkOption {
          type = lib.types.attrsOf (lib.types.listOf lib.types.str);
          default = { };
          description = "Named groups of allowlist URLs or inline entries";
        };

        clientGroupsBlock = lib.mkOption {
          type = lib.types.attrsOf (lib.types.listOf lib.types.str);
          default = { };
          example = lib.literalExpression ''
            {
              default = [ "ads" "malware" ];
              "10.0.20.0/24" = [ "ads" "malware" "telemetry" ];
              "10.0.30.0/24" = [ "ads" "malware" ];
            }
          '';
          description = ''
            Per-client/subnet blocking groups. Keys are CIDR subnets, client names,
            or "default". Values reference denylist group names.
            When empty, defaults are auto-derived from network segments:
            IoT-class (isolation=internet) gets aggressive blocking, others get standard.
          '';
        };

        prometheus = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable Prometheus metrics endpoint at /metrics";
          };
        };

        queryLog = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable DNS query logging";
          };
          type = lib.mkOption {
            type = lib.types.enum [
              "csv"
              "csv-client"
              "console"
              "mysql"
              "postgresql"
            ];
            default = "csv";
            description = "Query log output format";
          };
          retentionDays = lib.mkOption {
            type = lib.types.int;
            default = 7;
            description = "Number of days to retain query logs";
          };
        };

        caching = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable Blocky-level DNS caching. Disabled by default — Unbound already caches. Enabling adds a second cache layer that can delay DDNS propagation (negative cache).";
          };
          prefetching = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Prefetch expiring cache entries (only meaningful when caching is enabled)";
          };
        };

        extraSettings = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "Additional raw Blocky settings merged into the configuration. WARNING: can override critical keys (upstreams, ports, conditional) — use with care.";
        };
      };

      config = lib.mkMerge [
        {
          warnings = lib.optional (
            blockyCfg.enable && !(cfg.enable && dnsCfg.enable)
          ) "router: blocky.enable has no effect without router and DNS both enabled";
        }

        (lib.mkIf enabled {
          assertions =
            let
              validGroups = builtins.attrNames blockyCfg.denylists;
              referencedGroups = lib.unique (lib.flatten (builtins.attrValues effectiveClientGroups));
              invalidGroups = lib.filter (g: !builtins.elem g validGroups) referencedGroups;
            in
            [
              {
                assertion = invalidGroups == [ ];
                message = "router.blocky: clientGroupsBlock references undefined denylist groups: ${toString invalidGroups}. Valid groups: ${toString validGroups}";
              }
            ];

          services.blocky = {
            enable = true;
            settings = lib.recursiveUpdate (
              {
                ports = {
                  dns = dnsBindAddresses;
                  http = "127.0.0.1:${toString blockyCfg.httpPort}";
                };

                upstreams = {
                  groups.default = [ "127.0.0.1:5335" ];
                  strategy = "strict";
                  timeout = "2s";
                };

                # Forward local zone + private domains directly to Unbound
                conditional.mapping = conditionalMappings;

                blocking = {
                  inherit (blockyCfg) denylists allowlists;
                  clientGroupsBlock = effectiveClientGroups;
                  blockType = "zeroIp";
                  blockTTL = "1m";
                  loading = {
                    refreshPeriod = "24h";
                    strategy = "fast"; # Start serving DNS immediately; lists download in background
                    concurrency = 4;
                  };
                };

                # Fallback DNS for downloading block lists before Unbound may be ready
                bootstrapDns = {
                  upstream = "https://one.one.one.one/dns-query";
                  ips = [
                    "1.1.1.1"
                    "1.0.0.1"
                  ];
                };

                log = {
                  level = "info";
                  format = "text";
                  timestamp = true;
                };

                # Extended DNS Errors (RFC 8914) — clients see WHY a query was blocked
                ede.enable = true;
              }
              // lib.optionalAttrs blockyCfg.caching.enable {
                caching = {
                  minTime = "5m";
                  maxTime = "30m";
                  inherit (blockyCfg.caching) prefetching;
                  prefetchExpires = "2h";
                  prefetchThreshold = 5;
                  cacheTimeNegative = "30m";
                };
              }
              // lib.optionalAttrs blockyCfg.prometheus.enable {
                prometheus = {
                  enable = true;
                  path = "/metrics";
                };
              }
              // lib.optionalAttrs blockyCfg.queryLog.enable {
                queryLog = {
                  inherit (blockyCfg.queryLog) type;
                  target = "/var/log/blocky";
                  logRetentionDays = blockyCfg.queryLog.retentionDays;
                  flushInterval = "30s";
                };
              }
            ) blockyCfg.extraSettings;
          };

          # Blocky must start after Unbound (its upstream resolver)
          systemd.services.blocky = {
            after = [ "unbound.service" ];
            wants = [ "unbound.service" ];
            serviceConfig.LogsDirectory = "blocky";
          };
        })
      ];
    };
}
