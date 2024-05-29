{ config, pkgs, lib, inputs, ... }:
let
ssl-cert-path = if pkgs.stdenv.hostPlatform.isDarwin then
  "/Users/peranpl1/Documents/certificates/JHUAPL-MS-Root-CA-05-21-2038-B64-text.cer"
else
  "/etc/ssl/certs/ca-certificates.crt";

curl-openssl-v1 = pkgs.curl.override { openssl = pkgs.openssl_1_1; };
git-openssl-v1 = pkgs.git.override { openssl = pkgs.openssl_1_1; curl = curl-openssl-v1; };

in
{
  nixpkgs = {
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
  programs.git.package = git-openssl-v1;
  home.packages = with pkgs; [
    openssl_1_1
    aplnis-env # Small shell script to set and unset environment variables to work around VPN.
  ];
}
