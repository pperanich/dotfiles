final: prev: {
    aplCertificate = final.runCommand "apl-certificate" {} ''
      mkdir -p $out/etc/ssl/certs
      cp ${./JHUAPL-MS-Root-CA-05-21-2038-B64-text.crt} $out/etc/ssl/certs/apl-ca.crt
    '';
    cacert-apl = prev.cacert.override {
      extraCertificateFiles = [./JHUAPL-MS-Root-CA-05-21-2038-B64-text.crt];
    };
    curl-openssl_1_1 = prev.curl.override {openssl = prev.openssl_1_1;};
    git-openssl_1_1 = prev.git.override {
      openssl = prev.openssl_1_1;
      curl = final.curl-openssl_1_1;
    };
    buildPackages =
      prev.buildPackages
      // {
        openssl = prev.openssl_1_1;
        buildInputs = (prev.buildInputs or []) // [prev.openssl_1_1];
      };

    buildGoModule = prev.buildGoModule.override {
      cacert = final.cacert-apl;
    };

    rustPlatform =
      prev.rustPlatform
      // {
        buildRustPackage = args:
          prev.rustPlatform.buildRustPackage.override {
            fetchCargoVendor = prev.rustPlatform.fetchCargoVendor.override {
              cacert = final.cacert-apl;
            };
          }
          (args // {});
      };
  }
