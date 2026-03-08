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
            server.hostname = cfg.hostname;

            # Localhost-only SMTP listener — accepts mail from local services only
            server.listener.smtp = {
              protocol = "smtp";
              bind = "${cfg.listenAddress}:${toString cfg.listenPort}";
              tls.implicit = false;
            };

            # Storage — RocksDB (minimal, all-in-one)
            store.db = {
              type = "rocksdb";
              path = "%{base_path}%/db";
              compression = "lz4";
            };

            storage = {
              data = "db";
              fts = "db";
              blob = "db";
              lookup = "db";
              directory = "internal";
            };

            directory.internal = {
              type = "internal";
              store = "db";
            };

            # Relay policy — accept from localhost, reject everything else
            session.rcpt.relay = [
              {
                "if" = "remote_ip == '127.0.0.1'";
                "then" = true;
              }
              { "else" = false; }
            ];

            # Outbound routing — relay through Resend
            queue.outbound.hostname = cfg.hostname;

            remote.resend = {
              protocol = "smtp";
              address = "smtp.resend.com";
              port = 587;
              tls = {
                starttls = "require";
                allow-invalid-certs = false;
              };
              auth = {
                username = "resend";
                password = "%{file:/run/credentials/stalwart.service/relay-token}%";
              };
            };

            queue.routing.default = {
              relay = "resend";
            };

            # DNS resolver
            resolver.type = "system";

            # Logging
            tracer.stdout = {
              type = "stdout";
              level = "info";
              enable = true;
            };
          };
        };
      };
    };
}
