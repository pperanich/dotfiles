# Sets/unsets a few environment variables that are important if on APLNIS VPN.
{ lib, writeShellApplication, stdenv }:
let
ssl-cert-path = if stdenv.hostPlatform.isDarwin then
  "/etc/ssl/certs/JHUAPL-MS-Root-CA-05-21-2038-B64-text.crt"
else
  "/etc/ssl/certs/ca-certificates.crt";

darwin = if stdenv.hostPlatform.isDarwin then "true" else "false";
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
      export NIX_SSL_CERT_FILE=${ssl-cert-path}
      export SSL_CERT_FILE=${ssl-cert-path}
      export NIX_GIT_SSL_CAINFO=${ssl-cert-path}
      export REQUESTS_CA_BUNDLE=${ssl-cert-path}
      export NODE_EXTRA_CA_CERTS=${ssl-cert-path}
      export CURL_CA_BUNDLE=${ssl-cert-path}
      export GIT_SSL_CAINFO=${ssl-cert-path}
      if ${darwin};
      then
        sudo sed -i '/<key>NIX_SSL_CERT_FILE<\/key>/!b;n;c<string>${ssl-cert-path}</string>' /Library/LaunchDaemons/org.nixos.nix-daemon.plist
        sudo launchctl unload /Library/LaunchDaemons/org.nixos.nix-daemon.plist
        sudo launchctl load /Library/LaunchDaemons/org.nixos.nix-daemon.plist
      fi
    elif [ "$arg" = "off" ]; then
      unset PIP_CERT
      unset NIX_SSL_CERT_FILE
      unset SSL_CERT_FILE
      unset NIX_GIT_SSL_CAINFO
      unset REQUESTS_CA_BUNDLE
      unset NODE_EXTRA_CA_CERTS
      unset CURL_CA_BUNDLE
      unset GIT_SSL_CAINFO
      if ${darwin};
      then
        sudo sed -i '/<key>NIX_SSL_CERT_FILE<\/key>/!b;n;c<string>/etc/ssl/certs/ca-certificates.crt</string>' /Library/LaunchDaemons/org.nixos.nix-daemon.plist
        sudo launchctl unload /Library/LaunchDaemons/org.nixos.nix-daemon.plist
        sudo launchctl load /Library/LaunchDaemons/org.nixos.nix-daemon.plist
      fi
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
