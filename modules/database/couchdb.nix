{...}: {
  flake.modules.nixos.couchdb = { config, lib, pkgs, ... }: let
    cfg = config.features.couchdb;
  in {
    options.features.couchdb = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 5984;
        description = "Port for CouchDB to listen on";
      };
      bindAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Address for CouchDB to bind to";
      };
      adminUser = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "CouchDB admin username";
      };
    };

    config = {
      services.couchdb = {
        enable = true;
        package = pkgs.couchdb3;
        inherit (cfg) port;
        inherit (cfg) bindAddress;
        inherit (cfg) adminUser;
      };

      # Secret management
      sops.secrets.couchdb-admin-pass = {};

      # Open firewall port if not binding to localhost
      networking.firewall.allowedTCPPorts = lib.mkIf (cfg.bindAddress != "127.0.0.1") [
        cfg.port
      ];
    };
  };

  # Add home-manager module for CouchDB client tools
  flake.modules.homeManager.couchdb = { pkgs, ... }: {
    home.packages = with pkgs; [
      # CouchDB administration and interaction tools
      curl  # For HTTP API interactions
      jq    # For JSON processing
    ];
  };
}