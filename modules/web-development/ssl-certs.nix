# NixOS SSL certificate setup for development
# Manages development certificate authority and SSL certificates
# Only available on NixOS systems
_: {
  # NixOS system configuration for SSL certificates
  flake.modules.nixos.webDevelopment = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.features.webDev;
  in {
    options.features.webDev = {
      enableSSL = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable SSL/TLS development certificates";
      };

      devDomains = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["localhost.dev" "app.test" "api.test"];
        description = "Development domains to configure with SSL certificates";
      };
    };

    config = {
      # Development certificate authority (if SSL enabled)
      security.pki.certificateFiles = lib.mkIf cfg.enableSSL [
        # Add development CA certificates here if needed
      ];
    };
  };
}
