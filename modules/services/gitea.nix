_: {
  flake.modules.nixos.gitea =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.gitea;
    in
    {
      options.my.gitea = {
        enable = lib.mkEnableOption "Gitea self-hosted git service";
        port = lib.mkOption {
          type = lib.types.port;
          default = 3001;
          description = "HTTP port for Gitea to listen on (loopback only — Caddy fronts TLS).";
        };
        address = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address Gitea binds to.";
        };
        domain = lib.mkOption {
          type = lib.types.str;
          example = "gitea.example.com";
          description = "Public domain name for Gitea (used for ROOT_URL and SSH clone URLs).";
        };
        stateDir = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/gitea";
          description = "State directory for Gitea (also home of the system SSH user).";
        };
        user = lib.mkOption {
          type = lib.types.str;
          default = "git";
          description = "System user/group Gitea runs as. Doubles as the SSH login (git@host).";
        };
        sshPort = lib.mkOption {
          type = lib.types.port;
          default = 22;
          description = "Port advertised in SSH clone URLs. Defaults to the system sshd port.";
        };
        mail = {
          enable = lib.mkEnableOption "outbound mail (relayed via localhost:25)";
          from = lib.mkOption {
            type = lib.types.str;
            example = "gitea@example.com";
            description = "Sender email address.";
          };
          fromName = lib.mkOption {
            type = lib.types.str;
            default = "Gitea";
            description = "Sender display name.";
          };
        };
        admin = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.submodule {
              options = {
                username = lib.mkOption {
                  type = lib.types.str;
                  description = "Username for the initial admin account.";
                };
                email = lib.mkOption {
                  type = lib.types.str;
                  description = "Email for the initial admin account.";
                };
                passwordFile = lib.mkOption {
                  type = lib.types.path;
                  description = "Path to file containing the admin password (sops-managed).";
                };
              };
            }
          );
          default = null;
          description = ''
            Declarative initial admin user. Created on first boot via `gitea admin user create`.
            On subsequent boots the password is reset to match the file (idempotent), so rotating
            the sops secret reprovisions the admin.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        services.gitea = {
          enable = true;
          user = cfg.user;
          group = cfg.user;
          stateDir = cfg.stateDir;
          database.type = "sqlite3";
          lfs.enable = true;

          settings = {
            server = {
              DOMAIN = cfg.domain;
              ROOT_URL = "https://${cfg.domain}/";
              HTTP_ADDR = cfg.address;
              HTTP_PORT = cfg.port;
              # Disable Gitea's built-in SSH server. System sshd serves the `git`
              # user; authorized_keys (written by Gitea) carries the forced
              # `gitea serv` command per key.
              START_SSH_SERVER = false;
              DISABLE_SSH = false;
              SSH_DOMAIN = cfg.domain;
              SSH_PORT = cfg.sshPort;
              SSH_CREATE_AUTHORIZED_KEYS_FILE = true;
              LANDING_PAGE = "explore";
              OFFLINE_MODE = true;
            };
            service = {
              DISABLE_REGISTRATION = true;
              SHOW_REGISTRATION_BUTTON = false;
              DEFAULT_KEEP_EMAIL_PRIVATE = true;
            };
            session.COOKIE_SECURE = true;
            log.LEVEL = "Warn";
            ui.DEFAULT_THEME = "gitea-dark";
          }
          // lib.optionalAttrs cfg.mail.enable {
            mailer = {
              ENABLED = true;
              PROTOCOL = "smtp";
              SMTP_ADDR = "127.0.0.1";
              SMTP_PORT = 25;
              FROM = "${cfg.mail.fromName} <${cfg.mail.from}>";
            };
          };
        };

        # NixOS gitea module only auto-creates users.users when `user == "gitea"`.
        # We rename to `git` for clean clone URLs, so create the user/group here.
        users.users.${cfg.user} = lib.mkIf (cfg.user != "gitea") {
          description = "Gitea Service";
          home = cfg.stateDir;
          useDefaultShell = true;
          group = cfg.user;
          isSystemUser = true;
        };

        users.groups.${cfg.user} = lib.mkIf (cfg.user != "gitea") { };

        # Let system sshd serve git@host. Gitea writes authorized_keys with a
        # forced `gitea serv` command per key, so allowing pubkey login here is
        # not a shell — it's a per-key restricted git command.
        services.openssh.extraConfig = lib.mkAfter ''
          Match User ${cfg.user}
            AuthorizedKeysFile ${cfg.stateDir}/.ssh/authorized_keys
            AuthenticationMethods publickey
            PasswordAuthentication no
            KbdInteractiveAuthentication no
            PermitTTY no
            X11Forwarding no
            AllowAgentForwarding no
            AllowTcpForwarding no
            PermitTunnel no
        '';

        # Declarative admin bootstrap. Creates user if absent; otherwise resets
        # the password to match the sops file (so rotating the secret reprovisions).
        systemd.services.gitea-admin-bootstrap = lib.mkIf (cfg.admin != null) {
          description = "Provision Gitea admin user from sops";
          after = [ "gitea.service" ];
          wants = [ "gitea.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            User = cfg.user;
            Group = cfg.user;
            WorkingDirectory = cfg.stateDir;
            LoadCredential = "password:${cfg.admin.passwordFile}";
          };
          script = ''
            set -eu
            APP_INI="${cfg.stateDir}/custom/conf/app.ini"
            GITEA="${config.services.gitea.package}/bin/gitea --config $APP_INI --work-path ${cfg.stateDir}"
            PASS=$(cat "$CREDENTIALS_DIRECTORY/password")
            if $GITEA admin user list | awk 'NR>1 {print $2}' | grep -Fxq "${cfg.admin.username}"; then
              $GITEA admin user change-password \
                --username "${cfg.admin.username}" \
                --password "$PASS" \
                --must-change-password=false
            else
              $GITEA admin user create \
                --username "${cfg.admin.username}" \
                --email "${cfg.admin.email}" \
                --password "$PASS" \
                --admin \
                --must-change-password=false
            fi
          '';
          path = [ pkgs.gawk ];
        };
      };
    };
}
