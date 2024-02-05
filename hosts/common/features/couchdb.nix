{ inputs, lib, pkgs, config, ... }:
{
  # make the tailscale command usable to users
  environment.systemPackages = [ pkgs.couchdb3 ];

  services.couchdb = {
    enable = true;
    bindAddress = "0.0.0.0";
    extraConfig = ''
      [couchdb]
      single_node=true
      max_document_size = 50000000

      [admins]
      admin = admin

      [chttpd]
      require_valid_user = true
      max_http_request_size = 4294967296
      enable_cors = true

      [chttpd_auth]
      require_valid_user = true
      authentication_redirect = /_utils/session.html

      [httpd]
      WWW-Authenticate = Basic realm="couchdb"
      bind_address = 0.0.0.0

      [cors]
      origins = app://obsidian.md, capacitor://localhost, http://localhost
      credentials = true
      headers = accept, authorization, content-type, origin, referer
      methods = GET,PUT,POST,HEAD,DELETE
      max_age = 3600
    '';
  };
}
