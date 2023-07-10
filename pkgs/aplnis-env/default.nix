# Sets/unsets a few environment variables that are important if on APLNIS VPN.
{ lib, writeShellApplication, stdenv }:
let
ssl-cert-path = if stdenv.hostPlatform.isDarwin then
  "/Users/peranpl1/Documents/certificates/JHUAPL-MS-Root-CA-05-21-2038-B64-text.cer"
else
  "/etc/ssl/certs/ca-certificates.crt";
in
(writeShellApplication {
  name = "aplnis-env";

  text = ''
  set +o errexit
  set +o nounset
  set +o pipefail

  if [ $# -eq 0 ]; then
    echo "Usage: $0 <on/off>"
  else
    arg=$1
    if [ "$arg" = "on" ]; then
      export PIP_CERT=${ssl-cert-path}
      export SSL_CERT_FILE=${ssl-cert-path}
      export NIX_GIT_SSL_CAINFO=${ssl-cert-path}
      export REQUESTS_CA_BUNDLE=${ssl-cert-path}
      export NODE_EXTRA_CA_CERTS=${ssl-cert-path}
      export CURL_CA_BUNDLE=${ssl-cert-path}
      export GIT_SSL_CAINFO=${ssl-cert-path}
    elif [ "$arg" = "off" ]; then
      unset PIP_CERT
      unset SSL_CERT_FILE
      unset NIX_GIT_SSL_CAINFO
      unset REQUESTS_CA_BUNDLE
      unset NODE_EXTRA_CA_CERTS
      unset CURL_CA_BUNDLE
      unset GIT_SSL_CAINFO
    else
      echo "Invalid argument. Must be either 'on' or 'off'."
    fi
  fi
  '';
}) // {
  meta = with lib; {
    description = "APLNIS environment helper script.";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
