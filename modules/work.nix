{ lib, inputs, ... }:
let
  nixpkgsConfig = {
    permittedInsecurePackages = [
      "openssl-1.1.1w"
    ];
  };

  legacyNixpkgsConfig = nixpkgsConfig // {
    allowBroken = true;
    allowUnfree = true;
  };

  workOverlay =
    final: prev:
    let
      apl-root-ca = builtins.fetchurl {
        url = "https://apllinuxdepot.jhuapl.edu/linux/APL-root-cert/JHUAPL-MS-Root-CA-05-21-2038-B64-text.cer";
        sha256 = "faaadfb3803bbe659906c5a3abdea6a8c5b5e13c0321c3ca098213c5ca893f99";
      };
      pkgs2505 = import inputs.nixpkgs-2505 {
        system = prev.stdenv.hostPlatform.system;
        config = legacyNixpkgsConfig;
      };
    in
    {
      cacert-work = prev.cacert.override {
        extraCertificateFiles = [ apl-root-ca ];
      };
      inherit (pkgs2505) openssl_1_1;
      my-curl = pkgs2505.curl.override {
        openssl = final.openssl_1_1;
        # OpenSSL 1.1 is required in this environment; disable HTTP/3 (ngtcp2)
        # because recent curl builds require QUIC-capable TLS for --with-ngtcp2.
        http3Support = false;
      };
      # curl = final.my-curl;
      my-git =
        (pkgs2505.git.override {
          openssl = final.openssl_1_1;
          curl = final.my-curl;
        }).overrideAttrs
          (_: {
            # Keep dev shell bootstrap reliable; upstream git checks are flaky in
            # some constrained build environments and are not needed here.
            doCheck = false;
            doInstallCheck = false;
          });

      # buildPackages = prev.buildPackages // {
      #   openssl = final.openssl_1_1;
      # };

      buildGoModule = prev.buildGoModule.override { cacert = final.cacert-work; };

      rustPlatform = prev.rustPlatform // {
        fetchCargoVendor = prev.rustPlatform.fetchCargoVendor.override {
          cacert = final.cacert-work;
        };
        buildRustPackage = prev.rustPlatform.buildRustPackage.override {
          fetchCargoVendor = prev.rustPlatform.fetchCargoVendor.override {
            cacert = prev.cacert.override {
              extraCertificateFiles = [ apl-root-ca ];
            };
          };
        };
      };
      sops-install-secrets = prev.sops-install-secrets.overrideAttrs (old: {
        env = (old.env or { }) // {
          GODEBUG = "x509negativeserial=1";
        };
      });
    };
in
{
  # Work environment configuration
  # Overlay provides OpenSSL 1.1, corporate root CA, and SSL-aware build tooling.
  # Uses lib.mkAfter to ensure overlay runs AFTER others (especially sops-nix).

  flake.modules = {
    nixos.work = _: {
      nixpkgs.overlays = lib.mkAfter [ workOverlay ];
      nixpkgs.config = nixpkgsConfig;
      environment.variables = {
        DETSYS_IDS_TELEMETRY = "disabled";
      };
    };

    darwin.work = _: {
      nixpkgs.overlays = lib.mkAfter [ workOverlay ];
      nixpkgs.config = nixpkgsConfig;
      environment.variables = {
        DETSYS_IDS_TELEMETRY = "disabled";
      };
    };

    homeManager.work =
      { pkgs, ... }:
      let
        certBundle = "${pkgs.cacert-work}/etc/ssl/certs/ca-bundle.crt";
      in
      {
        nixpkgs.overlays = lib.mkAfter [ workOverlay ];
        nixpkgs.config = nixpkgsConfig;

        # Uses cacert-work (Mozilla bundle + corporate root CA) so SSL works
        # both on and off VPN without toggling.
        home.sessionVariables = {
          NIX_SSL_CERT_FILE = certBundle;
          SSL_CERT_FILE = certBundle;
          NIX_GIT_SSL_CAINFO = certBundle;
          REQUESTS_CA_BUNDLE = certBundle;
          NODE_EXTRA_CA_CERTS = certBundle;
          CURL_CA_BUNDLE = certBundle;
          PIP_CERT = certBundle;
          POETRY_REQUEST_TIMEOUT = "600";
          PIP_DEFAULT_TIMEOUT = "600";
          UV_HTTP_TIMEOUT = "600";
          DETSYS_IDS_TELEMETRY = "disabled";
          GODEBUG = "x509negativeserial=1";
          COLIMA_PROFILE = "work";
        };

        home.packages = with pkgs; [
          openssl_1_1
        ];
      };
  };
}
