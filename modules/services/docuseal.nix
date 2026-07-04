# Self-hosted document signing (e-signatures)
#
# Create fillable PDF forms, send for signature, and store signed documents.
# Data (SQLite DB + uploaded documents) lives in /var/lib/docuseal, managed
# by systemd StateDirectory under DynamicUser.
#
# Access: via Caddy (docuseal.prestonperanich.com, split-horizon TLS)
# Admin: first account created through the web UI on first launch; set the
# app URL to the public name during onboarding so emailed links resolve.
_: {
  flake.modules.nixos.docuseal =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.docuseal;
    in
    {
      options.my.docuseal = {
        port = lib.mkOption {
          type = lib.types.port;
          default = 3000;
          description = "Port for the DocuSeal web interface.";
        };

        address = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address for DocuSeal to bind to.";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to open the firewall for DocuSeal.";
        };

        secretKeyBaseFile = lib.mkOption {
          type = lib.types.path;
          description = ''
            Path to a file containing the Rails secret key base
            (generate with `openssl rand -hex 64`). Delivered to the
            DynamicUser service via systemd LoadCredential, so a
            root-owned sops secret works as-is.
          '';
        };
      };

      config = {
        services.docuseal = {
          enable = true;
          host = cfg.address;
          inherit (cfg) port;
          # The nixpkgs module only exports HOST, which Rails >= 6 ignores
          # for socket binding; BINDING is what `rails server` actually reads.
          # Without it puma listens on 0.0.0.0.
          extraConfig.BINDING = cfg.address;
          # Read via the credential mount, not the sops path directly:
          # the service runs as DynamicUser and cannot read root-owned files
          secretKeyBaseFile = "/run/credentials/docuseal.service/secret-key-base";
        };

        systemd.services.docuseal.serviceConfig.LoadCredential = [
          "secret-key-base:${cfg.secretKeyBaseFile}"
        ];

        networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
      };
    };
}
