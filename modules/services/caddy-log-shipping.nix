# Ship Caddy JSON access logs to Loki via Grafana Alloy with bounded stream labels.
_: {
  flake.modules.nixos.caddyLogShipping =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.caddyLogShipping;

      mkPrefixCond =
        prefixes:
        let
          checks = map (p: "(hasPrefix ${builtins.toJSON p} $ip)") prefixes;
        in
        if lib.length checks == 1 then builtins.head checks else "or " + lib.concatStringsSep " " checks;

      lanBranch = lib.optionalString (
        cfg.lanPrefixes != [ ]
      ) "{{ else if ${mkPrefixCond cfg.lanPrefixes} }}lan";

      isolatedBranches = lib.concatStrings (
        lib.mapAttrsToList (
          name: prefixes: lib.optionalString (prefixes != [ ]) "{{ else if ${mkPrefixCond prefixes} }}${name}"
        ) cfg.isolatedPrefixes
      );

      tailnetCond =
        let
          v4 = ''(regexMatch "^100\\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\\." $ip)'';
        in
        if cfg.tailnetV6Prefix != "" then
          "or (hasPrefix ${builtins.toJSON cfg.tailnetV6Prefix} $ip) ${v4}"
        else
          v4;

      networkTemplate =
        ''{{ $ip := trimPrefix "::ffff:" (default "" .client_ip) }}''
        + ''{{ if eq $ip "" }}unknown''
        + ''{{ else if or (hasPrefix "127." $ip) (eq $ip "::1") }}loopback''
        + lanBranch
        + isolatedBranches
        + "{{ else if ${tailnetCond} }}tailnet"
        + "{{ else }}external{{ end }}";
    in
    {
      options.my.caddyLogShipping = {
        enable = lib.mkEnableOption "ship Caddy JSON access logs to Loki via Grafana Alloy";

        lokiUrl = lib.mkOption {
          type = lib.types.str;
          example = "http://10.0.0.1:3100";
          description = "Base URL of the Loki instance to push Caddy access logs to.";
        };

        retryForever = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Retry Loki pushes indefinitely so transient receiver outages do not drop logs.";
        };

        logDir = lib.mkOption {
          type = lib.types.str;
          default = config.services.caddy.logDir;
          defaultText = lib.literalExpression "config.services.caddy.logDir";
          description = "Directory containing Caddy JSON access logs.";
        };

        lanPrefixes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "10.0.0."
            "fe80:"
          ];
          description = "Client IP prefixes classified as trusted LAN.";
        };

        isolatedPrefixes = lib.mkOption {
          type = lib.types.attrsOf (lib.types.listOf lib.types.str);
          default = { };
          example = {
            iot = [ "10.0.20." ];
            guest = [ "10.0.30." ];
          };
          description = "Map of isolated network label to client IP prefixes.";
        };

        tailnetV6Prefix = lib.mkOption {
          type = lib.types.str;
          default = "fd7a:115c:a1e0:";
          description = "Tailnet IPv6 ULA prefix classified as tailnet.";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.services.caddy.enable;
            message = "my.caddyLogShipping.enable requires services.caddy.enable.";
          }
          {
            assertion = config.services.alloy.enable;
            message = "my.caddyLogShipping.enable requires services.alloy.enable.";
          }
        ];

        systemd = {
          services.alloy.serviceConfig.SupplementaryGroups = [ config.services.caddy.group ];
          tmpfiles.rules = [
            "z ${cfg.logDir}/*.log 0640 ${config.services.caddy.user} ${config.services.caddy.group} -"
          ];
        };

        environment.etc."alloy/caddy.alloy".text = ''
          loki.write "caddy" {
            endpoint {
              url = "${cfg.lokiUrl}/loki/api/v1/push"
              ${lib.optionalString cfg.retryForever "max_backoff_retries = 0"}
            }
          }

          local.file_match "caddy" {
            path_targets = [{
              __path__ = "${cfg.logDir}/*.log",
              job      = "caddy",
              host     = "${config.networking.hostName}",
            }]
          }

          discovery.relabel "caddy" {
            targets = local.file_match.caddy.targets

            // Skip rotated timestamped files so rolled archives are not re-ingested.
            rule {
              source_labels = ["__path__"]
              regex         = ".*-[0-9]{4}-[0-9]{2}-[0-9]{2}T.*\\.log$"
              action        = "drop"
            }
            rule {
              source_labels = ["__path__"]
              regex         = ".*/public-([^/]+)\\.log$"
              target_label  = "exposure"
              replacement   = "public"
            }
            rule {
              source_labels = ["__path__"]
              regex         = ".*/access-([^/]+)\\.log$"
              target_label  = "exposure"
              replacement   = "internal"
            }
            rule {
              source_labels = ["__path__"]
              regex         = ".*/reproxy-([^/]+)\\.log$"
              target_label  = "exposure"
              replacement   = "reproxy"
            }
            rule {
              source_labels = ["__path__"]
              regex         = ".*/(?:public|access|reproxy)-([^/]+)\\.log$"
              target_label  = "site"
              replacement   = "$1"
            }
            rule {
              source_labels = ["exposure"]
              regex         = ".+"
              action        = "keep"
            }
          }

          loki.source.file "caddy" {
            targets       = discovery.relabel.caddy.output
            tail_from_end = true
            forward_to    = [loki.process.caddy.receiver]
          }

          loki.process "caddy" {
            forward_to = [loki.write.caddy.receiver]

            stage.json {
              expressions = {
                client_ip  = "request.client_ip",
                user_agent = "request.headers.\"User-Agent\"[0]",
              }
            }

            stage.template {
              source   = "network"
              template = `${networkTemplate}`
            }

            stage.template {
              source   = "probe"
              template = `{{ if regexMatch "^Blackbox[- ]Exporter/" (default "" .user_agent) }}true{{ else }}false{{ end }}`
            }

            stage.labels {
              values = {
                network = "",
                probe   = "",
              }
            }

            stage.label_drop {
              values = ["filename"]
            }
          }
        '';
      };
    };
}
