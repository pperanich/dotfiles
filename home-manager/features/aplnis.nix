{ pkgs, outputs, ... }:
let
ssl-cert-path = if pkgs.stdenv.hostPlatform.isDarwin then
  "/usr/local/share/ca-certificates/JHUAPL-MS-Root-CA-05-21-2038-B64-text.crt"
else
  "/etc/ssl/certs/ca-certificates.crt";


  aplnis-overlay = final: prev: {
    curl-aplnis = prev.curl.override { openssl = prev.openssl_1_1; };
    git-aplnis = prev.git.override { openssl = prev.openssl_1_1; curl = final.curl-aplnis; };
    rustPlatform = prev.rustPlatform // {
      buildRustPackage = args: prev.rustPlatform.buildRustPackage.override{
        fetchCargoTarball = prev.rustPlatform.fetchCargoTarball.override {
          cacert = prev.cacert.override {
            extraCertificateFiles = [ 
              /usr/local/share/ca-certificates/JHUAPL-MS-Root-CA-05-21-2038-B64-text.crt
            ];
          };
        };
      } (args // { });
    };
  };

in
{
  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays ++ [ aplnis-overlay ];
    config = {
      permittedInsecurePackages = [
        "openssl-1.1.1w"
      ];
    };
  };
  home.sessionVariables = {
    PIP_CERT=ssl-cert-path;
    SSL_CERT_FILE=ssl-cert-path;
    NIX_GIT_SSL_CAINFO=ssl-cert-path;
    REQUESTS_CA_BUNDLE=ssl-cert-path;
    NODE_EXTRA_CA_CERTS=ssl-cert-path;
    CURL_CA_BUNDLE=ssl-cert-path;
    GIT_SSL_CAINFO=ssl-cert-path;
    POETRY_REQUEST_TIMEOUT="30";
    PIP_DEFAULT_TIMEOUT="30";
  };
  home.packages = with pkgs; [
    openssl_1_1
    git-aplnis
    curl-aplnis
    aplnis-env # Small shell script to set and unset environment variables to work around VPN.
  ];
}
