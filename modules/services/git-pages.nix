# Forge-backed static site server (git-pages) behind a reverse proxy.
_: {
  flake.modules.nixos.gitPages =
    {
      config,
      lib,
      options,
      pkgs,
      ...
    }:
    let
      cfg = config.my.gitPages;
      forgeBase = lib.removeSuffix "/" cfg.forgeUrl;
    in
    {
      options.my.gitPages = {
        enable = lib.mkEnableOption "git-pages static site server";

        domain = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "pages.example.com";
          description = "Base domain for wildcard site routing (*.<domain>).";
        };

        forgeUrl = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "https://gitea.example.com";
          description = "Base URL of the git forge used for clone templates and token authorization.";
        };

        authorization = lib.mkOption {
          type = lib.types.enum [
            "gitea"
            "forgejo"
            "gogs"
          ];
          default = "gitea";
          description = "Forge authorization backend for wildcard archive uploads.";
        };

        indexRepo = lib.mkOption {
          type = lib.types.str;
          default = "pages";
          description = "Repository name (or template) mapped to the owner index site (https://<owner>.<domain>/).";
        };

        indexRepoBranch = lib.mkOption {
          type = lib.types.str;
          default = "pages";
          description = "Branch served from the index repository on webhook updates.";
        };

        address = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Loopback address git-pages binds to.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 3020;
          description = "HTTP port for serving and publishing pages (fronted by Caddy).";
        };

        metricsPort = lib.mkOption {
          type = lib.types.nullOr lib.types.port;
          default = 3022;
          description = "Loopback port for Prometheus /metrics (null disables the listener).";
        };

        caddyPort = lib.mkOption {
          type = lib.types.nullOr lib.types.port;
          default = null;
          description = "Loopback port for Caddy on_demand_tls checks (null disables it; unneeded with wildcard certs).";
        };

        maxSiteSize = lib.mkOption {
          type = lib.types.str;
          default = "128MB";
          description = "Maximum size of a published site or uploaded archive.";
        };

        memoryMax = lib.mkOption {
          type = lib.types.str;
          default = "512M";
          description = "Systemd cgroup MemoryMax limit (git-pages derives GOMEMLIMIT from cgroup limits).";
        };

        auditCollect = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Record site publication and deletion events in git-pages's audit log.";
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            assertions = [
              {
                assertion = cfg.domain != "";
                message = "my.gitPages.domain must be set when my.gitPages.enable is true.";
              }
              {
                assertion = cfg.forgeUrl != "";
                message = "my.gitPages.forgeUrl must be set when my.gitPages.enable is true.";
              }
            ];

            system.services.git-pages = {
              imports = [ pkgs.git-pages.services.default ];

              git-pages.settings = {
                log-format = "text";
                server = {
                  pages = "tcp/${cfg.address}:${toString cfg.port}";
                  caddy = if cfg.caddyPort == null then "-" else "tcp/${cfg.address}:${toString cfg.caddyPort}";
                  metrics = if cfg.metricsPort == null then "-" else "tcp/${cfg.address}:${toString cfg.metricsPort}";
                };
                storage = {
                  type = "fs";
                  fs.root = "/var/lib/git-pages/data";
                };
                wildcard = [
                  {
                    inherit (cfg) domain authorization;
                    clone-url = "${forgeBase}/<user>/<project>.git";
                    index-repo = cfg.indexRepo;
                    index-repo-branch = cfg.indexRepoBranch;
                  }
                ];
                limits = {
                  max-site-size = cfg.maxSiteSize;
                  allowed-repository-url-prefixes = [ "${forgeBase}/" ];
                };
                audit = {
                  collect = cfg.auditCollect;
                  include-ip = "X-Forwarded-For";
                };
              };

              systemd.service.serviceConfig.MemoryMax = cfg.memoryMax;
            };
          }

          (lib.optionalAttrs (options.my ? observability) {
            my.observability = {
              extraLocalTargets = lib.optional (cfg.metricsPort != null) {
                job = "git-pages";
                port = cfg.metricsPort;
              };
              extraJournalUnits = [ "git-pages" ];
            };
          })
        ]
      );
    };
}
