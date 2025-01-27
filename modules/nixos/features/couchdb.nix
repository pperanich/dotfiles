# CouchDB feature module
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.features.couchdb;
in {
  options.my.features.couchdb = {
    enable = lib.mkEnableOption "CouchDB database server";
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

  config = lib.mkIf cfg.enable {
    services.couchdb = {
      enable = true;
      package = pkgs.couchdb3;
      inherit (cfg) port;
      inherit (cfg) bindAddress;
      inherit (cfg) adminUser;
    };

    # Secret management
    sops.secrets.couchdb-admin-pass = { };

    # Open firewall port if not binding to localhost
    networking.firewall.allowedTCPPorts = lib.mkIf (cfg.bindAddress != "127.0.0.1") [
      cfg.port
    ];
  };
}
