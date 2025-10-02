final: prev: {
  cacert-apl = prev.cacert.override {
    extraCertificateFiles = [ ./JHUAPL-MS-Root-CA-05-21-2038-B64-text.crt ];
  };
  my-curl = prev.curl.override { openssl = prev.openssl_1_1; };
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
}
