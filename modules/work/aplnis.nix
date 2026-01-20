_:
let
  nixpkgs = {
    overlays = [ (import ../../overlays/aplnis-overlay.nix) ];
    config = {
      permittedInsecurePackages = [
        "openssl-1.1.1w"
      ];
    };
  };
in
{
  # APLNIS work environment configuration
  # Provides overlay for OpenSSL 1.1 support and work-specific packages

  flake.modules = {
    nixos.aplnis = _: {
      # System-level APLNIS configuration
      inherit nixpkgs;
      environment.variables = {
        DETSYS_IDS_TELEMETRY = "disabled";
      };
    };

    darwin.aplnis = _: {
      # Darwin-specific APLNIS configuration
      inherit nixpkgs;
      environment.variables = {
        DETSYS_IDS_TELEMETRY = "disabled";
      };
    };

    homeManager.aplnis =
      { pkgs, config, ... }:
      {
        # User-level APLNIS configuration
        inherit nixpkgs;

        # Work-specific environment variables for APLNIS VPN
        home.sessionVariables = {
          POETRY_REQUEST_TIMEOUT = "600";
          PIP_DEFAULT_TIMEOUT = "600";
          UV_HTTP_TIMEOUT = "600";
          DETSYS_IDS_TELEMETRY = "disabled";
          GODEBUG = "x509negativeserial=1";
          OPENCODE_CONFIG_DIR = "${config.home.homeDirectory}/.config/opencode-work/";
        };

        # APLNIS-specific packages
        home.packages = with pkgs; [
          openssl_1_1
          # git-openssl_1_1
          # curl-openssl_1_1
          aplnis-env # Small shell script to set and unset environment variables to work around VPN.
        ];
      };
  };
}
