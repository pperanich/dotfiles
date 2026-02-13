final: prev: {
  cacert-apl = prev.cacert.override {
    extraCertificateFiles = [ ./JHUAPL-MS-Root-CA-05-21-2038-B64-text.crt ];
  };
  my-curl = prev.curl.override {
    openssl = prev.openssl_1_1;
    # OpenSSL 1.1 is required in this environment; disable HTTP/3 (ngtcp2)
    # because recent curl builds require QUIC-capable TLS for --with-ngtcp2.
    http3Support = false;
  };
  my-git = prev.git.override {
    openssl = prev.openssl_1_1;
    curl = final.my-curl;
  };
  buildPackages = prev.buildPackages // {
    openssl = prev.openssl_1_1;
    buildInputs = (prev.buildInputs or [ ]) // [ prev.openssl_1_1 ];
  };

  buildGoModule = prev.buildGoModule.override { cacert = final.cacert-apl; };

  rustPlatform = prev.rustPlatform // {
    fetchCargoVendor = prev.rustPlatform.fetchCargoVendor.override {
      cacert = final.cacert-apl;
    };
    buildRustPackage = prev.rustPlatform.buildRustPackage.override {
      fetchCargoVendor = prev.rustPlatform.fetchCargoVendor.override {
        cacert = prev.cacert.override {
          extraCertificateFiles = [ ./JHUAPL-MS-Root-CA-05-21-2038-B64-text.crt ];
        };
      };
    };
  };
  sops-install-secrets = prev.sops-install-secrets.overrideAttrs (_old: {
    env.GODEBUG = "x509negativeserial=1";
  });
}
