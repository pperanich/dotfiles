{ config, pkgs, lib, inputs, ... }:
let
    emacsSrc = pkgs.fetchFromGitHub {
      owner="emacs-mirror";
      repo = "emacs";
      rev = "835d2b6acbe42b0bdef8f6e5f00fb0adbd1e3bcb";
      hash = "sha256-QZ1ike7Q46DeG6zuGVSej4a8VMvBMqE9zo6IzXwnTKI=";
    }; 
in
{
  nixpkgs = {
    config = {
      packageOverrides = pkgs: {
        emacsGit = pkgs.emacsGit.overrideAttrs (attrs: { src = emacsSrc; });
      };
    };
  };
  home.sessionVariables = if pkgs.stdenv.hostPlatform.isDarwin then
  {
    NIX_GIT_SSL_CAINFO="/Users/peranpl1/Documents/certificates/JHUAPL-MS-Root-CA-05-21-2038-B64-text.cer";
    PIP_CERT="/Users/peranpl1/Documents/certificates/JHUAPL-MS-Root-CA-05-21-2038-B64-text.cer";
    REQUESTS_CA_BUNDLE="/Users/peranpl1/Documents/certificates/JHUAPL-MS-Root-CA-05-21-2038-B64-text.cer";
    SSL_CERT_FILE="/Users/peranpl1/Documents/certificates/JHUAPL-MS-Root-CA-05-21-2038-B64-text.cer";
  } else {
    PIP_CERT="/etc/ssl/certs/ca-certificates.crt";
    SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt";
    NIX_GIT_SSL_CAINFO="/etc/ssl/certs/ca-certificates.crt";
    REQUESTS_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt";
    NODE_EXTRA_CA_CERTS="/etc/ssl/certs/ca-certificates.crt";
    CURL_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt";
  };
}
