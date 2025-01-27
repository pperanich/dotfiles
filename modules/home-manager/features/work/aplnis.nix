# APLNIS-specific configuration
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.home.features.work;

  ssl-cert-file = pkgs.writeTextFile {
    name = "JHUAPL-MS-Root-CA";
    text = ''
      -----BEGIN CERTIFICATE-----
      MIIC+zCCAeOgAwIBAgIUHzL9C7zONRYlGFC5hJt5a5TzDFUwDQYJKoZIhvcNAQEL
      ...
      -----END CERTIFICATE-----
    '';
  };

  extra-certs = [
      ssl-cert-file
  ];

  aplnis-overlay = final: prev: {
    curl-aplnis = prev.curl.override {openssl = prev.openssl_1_1;};
    git-aplnis = prev.git.override {
      openssl = prev.openssl_1_1;
      curl = final.curl-aplnis;
    };
    rustPlatform =
      prev.rustPlatform
      // {
        buildRustPackage = args:
          prev.rustPlatform.buildRustPackage.override {
            fetchCargoTarball = prev.rustPlatform.fetchCargoTarball.override {
              cacert = prev.cacert.override {
                extraCertificateFiles = extra-certs;
              };
            };
          } (args // {});
      };
  };
in {
  config = lib.mkMerge [
    (lib.mkIf (cfg.enable) {
      nixpkgs = {
        overlays = [aplnis-overlay];
        config = {
          permittedInsecurePackages = [
            "openssl-1.1.1w"
          ];
        };
      };

      home.sessionVariables = {
        PIP_CERT = "${ssl-cert-file}";
        SSL_CERT_FILE = "${ssl-cert-file}";
        NIX_GIT_SSL_CAINFO = "${ssl-cert-file}";
        REQUESTS_CA_BUNDLE = "${ssl-cert-file}";
        NODE_EXTRA_CA_CERTS = "${ssl-cert-file}";
        CURL_CA_BUNDLE = "${ssl-cert-file}";
        POETRY_REQUEST_TIMEOUT = "600";
        PIP_DEFAULT_TIMEOUT = "600";
        UV_HTTP_TIMEOUT = "600";
      };

    })
    (lib.mkIf (cfg.enable) {
      home.packages = with pkgs; [
        openssl_1_1
        git-openssl_1_1
        curl-openssl_1_1
        aplnis-env # Small shell script to set and unset environment variables to work around VPN.
      ];
    })
  ];
}
