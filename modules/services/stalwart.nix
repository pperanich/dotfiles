_: {
  flake.modules.nixos.stalwart =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.stalwart;
    in
    {
      options.my.stalwart = {
        enable = lib.mkEnableOption "Stalwart mail server for outbound transactional email via Resend";

        hostname = lib.mkOption {
          type = lib.types.str;
          example = "mail.example.com";
          description = "FQDN of the mail server (used in SMTP EHLO)";
        };

        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address for the SMTP listener (localhost-only by default)";
        };

        listenPort = lib.mkOption {
          type = lib.types.port;
          default = 25;
          description = "Port for the SMTP listener";
        };

        relayCredentialFile = lib.mkOption {
          type = lib.types.path;
          description = "Path to file containing the Resend API key (used as SMTP password)";
        };
      };

      config = lib.mkIf cfg.enable {
        services.stalwart = {
          enable = true;

          credentials = {
            "relay-token" = cfg.relayCredentialFile;
          };

          settings = {
            # Allow queue/session/route settings in local TOML config
            config.local-keys = [
              "store.*"
              "directory.*"
              "tracer.*"
              "server.*"
              "!server.blocked-ip.*"
              "!server.allowed-ip.*"
              "storage.*"
              "certificate.*"
              "queue.*"
              "session.*"
              "remote.*"
              "resolver.*"
              "spam-filter.*"
              "webadmin.*"
            ];

            server.hostname = cfg.hostname;

            # Localhost-only SMTP listener — accepts mail from local services only
            server.listener.smtp = {
              protocol = "smtp";
              bind = "${cfg.listenAddress}:${toString cfg.listenPort}";
              tls.implicit = false;
            };

            # Localhost-only — allow non-FQDN EHLO (e.g. vaultwarden sends bare hostname)
            session.ehlo.reject-non-fqdn = false;

            # Relay policy — accept from localhost, reject everything else
            session.rcpt.relay = [
              {
                "if" = "remote_ip == '127.0.0.1'";
                "then" = true;
              }
              { "else" = false; }
            ];

            # Outbound routing — all mail relayed through Resend
            queue.outbound.hostname = cfg.hostname;

            queue.route.resend = {
              type = "relay";
              protocol = "smtp";
              address = "smtp.resend.com";
              port = 587;
              tls = {
                implicit = false;
                allow-invalid-certs = false;
              };
              auth = {
                username = "resend";
                secret = "%{file:/run/credentials/stalwart.service/relay-token}%";
              };
            };

            # Route all outbound mail through the Resend relay
            queue.strategy.route = [
              {
                "if" = "is_local_domain('', rcpt_domain)";
                "then" = "'local'";
              }
              { "else" = "'resend'"; }
            ];
          };
        };
      };
    };
}
