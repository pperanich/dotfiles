_: {
  # Web-based network scanner UI (scanservjs) backed by sane-airscan.
  # Pulls scans from any AirScan/eSCL device and saves to a configurable output dir.
  flake.modules.nixos.scanservjs =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.scanservjs;

      # Optional sane-airscan pin: builds a tiny "backend" derivation whose
      # etc/sane.d/airscan.conf overrides the upstream default. mkSaneConfig
      # processes extraBackends last and ln -sfn lets the last copy win.
      airscanOverlay =
        if cfg.scanner.url == null && cfg.scanner.discovery then
          null
        else
          pkgs.writeTextFile {
            name = "sane-airscan-pinned";
            destination = "/etc/sane.d/airscan.conf";
            text = ''
              [options]
              discovery = ${if cfg.scanner.discovery then "enable" else "disable"}
              ws-discovery = ${if cfg.scanner.discovery then "fast" else "off"}
            ''
            + lib.optionalString (cfg.scanner.url != null) ''

              [devices]
              "${cfg.scanner.name}" = ${cfg.scanner.url}
            '';
          };
    in
    {
      options.my.scanservjs = {
        port = lib.mkOption {
          type = lib.types.port;
          default = 8080;
          description = "Port for scanservjs web UI";
        };
        address = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address for scanservjs to bind to";
        };
        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Open the configured TCP port in the host firewall";
        };
        outputDir = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/scanservjs/data/output";
          description = "Directory where finished scans are written (must be writable by scanservjs user)";
        };
        scanner = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "Network Scanner";
            description = "Friendly name for the pinned scanner (only used when scanner.url is set)";
          };
          url = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "http://10.0.20.50/eSCL";
            description = ''
              Pin a specific eSCL/AirScan device URL. When null and discovery is
              enabled, sane-airscan relies on mDNS discovery (requires Avahi reachability).
            '';
          };
          discovery = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Allow mDNS and WS-Discovery broadcast probing in addition to any pinned device";
          };
        };

        basicAuthHashSecret = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "scanservjs-password-hash";
          description = ''
            sops key holding a bcrypt hash for Caddy's basic_auth. When set, the
            module renders it into Caddy's EnvironmentFile; reference it in the
            vhost via basicAuthHashPlaceholder.
          '';
        };

        allowUnauthenticated = lib.mkEnableOption "serving scanservjs without basicAuthHashSecret (transitional opt-out only)";

        basicAuthHashEnvVar = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          default = "SCANSERVJS_PASSWORD_HASH";
          description = "Read-only. Name of the env var carrying the basic_auth hash.";
        };

        basicAuthHashPlaceholder = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          default = "{$" + cfg.basicAuthHashEnvVar + "}";
          description = ''
            Read-only. Caddy env-var reference for the hash, ready to drop into a
            vhost: `pperanich ''${config.my.scanservjs.basicAuthHashPlaceholder}`.
            Built by concatenation because `{$''${var}}` inside an indented string
            is a literal-$ escape, not an interpolation.
          '';
        };
      };

      config = lib.mkIf (cfg.address != null) (
        lib.mkMerge [
          (lib.mkIf (cfg.basicAuthHashSecret != null) {
            sops = {
              secrets.${cfg.basicAuthHashSecret} = { };

              templates."caddy-scanservjs.env" = {
                content = "${cfg.basicAuthHashEnvVar}=${config.sops.placeholder.${cfg.basicAuthHashSecret}}";
                owner = "caddy";
                restartUnits = [ "caddy.service" ];
              };
            };

            systemd.services.caddy.serviceConfig.EnvironmentFile = [
              config.sops.templates."caddy-scanservjs.env".path
            ];
          })
          {
            assertions = [
              {
                assertion = cfg.basicAuthHashSecret != null || cfg.allowUnauthenticated;
                message = "my.scanservjs.basicAuthHashSecret is unset; set a sops bcrypt hash secret or explicitly set my.scanservjs.allowUnauthenticated = true.";
              }
            ];

            warnings =
              lib.optional (cfg.basicAuthHashSecret == null && cfg.allowUnauthenticated)
                "my.scanservjs.allowUnauthenticated is enabled; scan vhost has no Caddy basic_auth until my.scanservjs.basicAuthHashSecret is configured.";

            # scanservjs 3.1.0 (nixos-26.05) ships the built Vue UI at
            # $out/lib/client (express-configurer.js patched via @client@) and the
            # module sets NIX_SCANSERVJS_CONFIG_PATH + a preview tmpfiles link
            # itself. The old override that patched the pre-3.1.0
            # $out/lib/node_modules/scanservjs layout is obsolete and broke the
            # build, so stock scanservjs is used directly now.
            services.scanservjs = {
              enable = true;
              settings = {
                host = cfg.address;
                inherit (cfg) port;
                outputDirectory = cfg.outputDir;
              };
            };

            hardware.sane = {
              enable = true;
              openFirewall = false;
              netConf = lib.mkDefault "";
              disabledDefaultBackends = lib.mkIf (!cfg.scanner.discovery) [ "net" ];
              extraBackends = [ pkgs.sane-airscan ] ++ lib.optional (airscanOverlay != null) airscanOverlay;
            };

            systemd.tmpfiles.settings."10-scanservjs" = {
              ${cfg.outputDir}."d" = {
                user = "scanservjs";
                group = "scanservjs";
                mode = "0750";
              };
            };

            networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
          }
        ]
      );
    };
}
