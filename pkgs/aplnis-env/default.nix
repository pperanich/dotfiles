# Sets/unsets a few environment variables that are important if on APLNIS VPN.
{
  lib,
  writeShellApplication,
  aplCertificate,
}: let
  ssl-cert-path = "${aplCertificate}/etc/ssl/certs/apl-ca.crt";
  system-cert-path = "/etc/ssl/certs/ca-certificates.crt";

  # List of environment variables to manage
  ssl_vars = [
    "PIP_CERT"
    "NIX_SSL_CERT_FILE"
    "SSL_CERT_FILE"
    "NIX_GIT_SSL_CAINFO"
    "REQUESTS_CA_BUNDLE"
    "NODE_EXTRA_CA_CERTS"
    "CURL_CA_BUNDLE"
  ];
in
  writeShellApplication {
    name = "aplnis-env";

    runtimeInputs = ["ripgrep"];

    text = ''
      set +o errexit
      set +o nounset
      set +o pipefail

      is_darwin() {
        [ "$(uname -s)" = "Darwin" ]
      }

      usage() {
        echo "Usage: $0 <on|off>"
        echo "  on  - Enable APLNIS certificate and environment"
        echo "  off - Disable APLNIS certificate and environment"
        exit 1
      }

      set_vars() {
        local cert_path="$1"
        for var in ${toString ssl_vars}; do
          export "$var=$cert_path"
        done
      }

      unset_vars() {
        for var in ${toString ssl_vars}; do
          unset "$var"
        done
      }

      main() {
        case "$1" in
          "on")
            set_vars "${ssl-cert-path}"
            ;;
          "off")
            unset_vars
            ;;
          *)
            usage
            ;;
        esac
      }

      if [ $# -eq 0 ]; then
        usage
      else
        main "$1"
      fi
    '';
  }
  // {
    meta = with lib; {
      description = "APLNIS environment helper script";
      license = licenses.mit;
      platforms = platforms.all;
    };
  }
