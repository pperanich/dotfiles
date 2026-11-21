# Self-hosted Headscale coordination server for the Tailscale mesh overlay.
#
# Listens on loopback HTTP behind Caddy TLS termination on public TCP :9443
# (gray-cloud DDNS + DNS-01 ACME, since Cloudflare Tunnel strips TS2021's
# raw `Upgrade: tailscale-control-protocol` handshake).
_: {
  flake.modules.nixos.headscale =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.headscale;

      defaultPolicy = {
        groups = {
          "group:admin" = [ "pperanich@" ];
        };

        tagOwners = {
          "tag:admin" = [ "group:admin" ];
          "tag:router" = [ "group:admin" ];
          "tag:nas" = [ "group:admin" ];
          "tag:server" = [ "group:admin" ];
          "tag:iot" = [ "group:admin" ];
          "tag:mobile" = [ "group:admin" ];
          "tag:dev" = [ "group:admin" ];
        };

        acls = [
          # Full administrative access from workstation nodes (pp-ml1)
          {
            action = "accept";
            src = [ "tag:admin" ];
            dst = [ "*:*" ];
          }

          # Mobile devices: HTTPS apps, DNS and the Rex login servers (no SSH to any host)
          {
            action = "accept";
            src = [ "tag:mobile" ];
            dst = [
              "tag:router:53"
              "tag:router:443"
              "tag:router:7297"
              "tag:nas:443"
              "tag:nas:7297"
              "tag:dev:7297"
            ];
          }

          # Untrusted/semi-trusted dev environments (e.g. pp-wsl1): Gitea/HTTPS + DNS only, no SSH
          {
            action = "accept";
            src = [ "tag:dev" ];
            dst = [
              "tag:router:53"
              "tag:router:443"
            ];
          }

          # Constrained server / IoT overlay nodes (e.g. pp-rpi1): router DNS only
          {
            action = "accept";
            src = [
              "tag:iot"
              "tag:server"
            ];
            dst = [ "tag:router:53" ];
          }

          # Server-to-server least privilege: router Borg pull SSH and Caddy HTTPS re-proxy on NAS
          # (Loki :3100 and Prometheus exporters :9633/:9640 stay strictly on LAN br-main)
          {
            action = "accept";
            src = [ "tag:router" ];
            proto = "tcp";
            dst = [
              "tag:nas:22"
              "tag:nas:443"
            ];
          }
        ]
        ++ cfg.extraAcls;
      };

      policyFile = pkgs.writeText "headscale-policy.json" (builtins.toJSON cfg.policy);
    in
    {
      options.my.headscale = {
        enable = lib.mkEnableOption "self-hosted Headscale Tailscale control plane";

        domain = lib.mkOption {
          type = lib.types.str;
          default = "hs.${lib.my.homelab.publicDomain}";
          defaultText = lib.literalExpression ''"hs.''${lib.my.homelab.publicDomain}"'';
          description = "Public FQDN for the Headscale coordination server.";
        };

        publicPort = lib.mkOption {
          type = lib.types.port;
          default = 9443;
          description = "Public HTTPS port terminated by the reverse proxy.";
        };

        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Local address for Headscale HTTP listener.";
        };

        listenPort = lib.mkOption {
          type = lib.types.port;
          default = 8085;
          description = "Local port for Headscale HTTP listener.";
        };

        metricsPort = lib.mkOption {
          type = lib.types.port;
          default = 9095;
          description = "Local loopback port for Headscale Prometheus metrics.";
        };

        baseDomain = lib.mkOption {
          type = lib.types.str;
          default = "pp-ts";
          description = "MagicDNS base domain for tailnet nodes (must differ from domain).";
        };

        routerTailscaleIpv4 = lib.mkOption {
          type = lib.types.str;
          default = "100.64.0.1";
          description = "Sequential Tailscale IPv4 assigned to pp-router1 (first enrolled node).";
        };

        routerTailscaleIpv6 = lib.mkOption {
          type = lib.types.str;
          default = "fd7a:115c:a1e0::1";
          description = "Sequential Tailscale ULA IPv6 assigned to pp-router1 (first enrolled node).";
        };

        nameservers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Global DNS nameservers advertised to Tailscale clients (empty when override_local_dns is false).";
        };

        splitDns = lib.mkOption {
          type = lib.types.attrsOf (lib.types.listOf lib.types.str);
          # Empty: home.arpa is the LAN and is not resolved over the tailnet.
          default = { };
          description = "Split-DNS domain to nameserver map forwarded over Tailscale (`dns.nameservers.split`).";
        };

        extraAcls = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [ ];
          description = "Host-specific ACLs appended to the default Headscale policy.";
        };

        policy = lib.mkOption {
          type = lib.types.attrs;
          default = defaultPolicy;
          description = "Declarative Headscale zero-trust ACL policy (serialized as JSON).";
        };
      };

      config = lib.mkIf cfg.enable {
        # Headscale exits if it cannot fetch the DERP map at startup. nss-lookup.target alone
        # does not order a deploy that restarts the resolver, so name the local resolvers too.
        systemd.services.headscale = {
          wants = [ "nss-lookup.target" ];
          after = [
            "nss-lookup.target"
          ]
          ++ lib.optional config.services.unbound.enable "unbound.service"
          ++ lib.optional config.services.blocky.enable "blocky.service";
        };
        services.headscale = {
          enable = true;
          address = cfg.listenAddress;
          port = cfg.listenPort;
          settings = {
            server_url = "https://${cfg.domain}:${toString cfg.publicPort}";
            metrics_listen_addr = "127.0.0.1:${toString cfg.metricsPort}";
            grpc_listen_addr = "127.0.0.1:50443";
            grpc_allow_insecure = false;
            noise.private_key_path = "/var/lib/headscale/noise_private.key";
            prefixes = {
              v4 = "100.64.0.0/10";
              v6 = "fd7a:115c:a1e0::/48";
              allocation = "sequential";
            };
            database = {
              type = "sqlite";
              sqlite = {
                path = "/var/lib/headscale/db.sqlite";
                write_ahead_log = true;
              };
            };
            derp = {
              server.enabled = false;
              urls = [ "https://controlplane.tailscale.com/derpmap/default" ];
              auto_update_enabled = true;
              update_frequency = "24h";
            };
            logtail.enabled = false;
            policy = {
              mode = "file";
              path = policyFile;
            };
            dns = {
              magic_dns = true;
              base_domain = cfg.baseDomain;
              override_local_dns = false;
              nameservers = {
                global = cfg.nameservers;
                split = cfg.splitDns;
              };
            };
          };
        };

        environment.systemPackages = [ config.services.headscale.package ];
      };
    };
}
