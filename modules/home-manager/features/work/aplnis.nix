# APLNIS-specific configuration
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.home.features.work;
in {
  config = lib.mkIf cfg.enable {
    nixpkgs = {
      overlays = [(import ../../../../overlays/aplnis-overlay.nix)];
      config = {
        permittedInsecurePackages = [
          "openssl-1.1.1w"
        ];
      };
    };

    home.sessionVariables = {
      POETRY_REQUEST_TIMEOUT = "600";
      PIP_DEFAULT_TIMEOUT = "600";
      UV_HTTP_TIMEOUT = "600";
    };
    home.packages = with pkgs; [
      openssl_1_1
      git-openssl_1_1
      curl-openssl_1_1
      aplnis-env # Small shell script to set and unset environment variables to work around VPN.
    ];
  };
}
