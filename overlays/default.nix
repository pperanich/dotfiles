{inputs, ...}: {
  # This one brings our my packages from the 'pkgs' directory
  emacs-overlay = inputs.emacs-overlay.overlays.default;
  neovim-overlay = inputs.neovim-nightly-overlay.overlays.default;

  nixgl = inputs.nixgl.overlay;
  rust-overlay = inputs.rust-overlay.overlays.default;

  additions = final: _prev: import ../pkgs {pkgs = final;};
  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    aplCertificate = final.runCommand "apl-certificate" {} ''
      mkdir -p $out/etc/ssl/certs
      cp ${./JHUAPL-MS-Root-CA-05-21-2038-B64-text.crt} $out/etc/ssl/certs/apl-ca.crt
    '';

    atuin = prev.atuin.overrideAttrs (old: {
      # as cursed as doing mitigations=off in the kernel command line
      patches = [./patches/0001-make-atuin-on-zfs-fast-again.patch];
    });
    glibtool = final.libtool.overrideAttrs (oldAttrs: {
      configureFlags = (oldAttrs.configureFlags or []) ++ ["--program-prefix=g"];
    });
    apple-fonts = {
      inherit
        (inputs.apple-fonts.packages.${final.system})
        sf-pro
        sf-pro-nerd
        sf-compact
        sf-compact-nerd
        sf-mono
        sf-mono-nerd
        sf-arabic
        sf-arabic-nerd
        ny
        ny-nerd
        ;
    };
    curl-openssl_1_1 = prev.curl.override {openssl = prev.openssl_1_1;};
    git-openssl_1_1 = prev.git.override {
      openssl = prev.openssl_1_1;
      curl = final.curl-openssl_1_1;
    };
    rustPlatform =
      prev.rustPlatform
      // {
        buildRustPackage = args:
          prev.rustPlatform.buildRustPackage.override {
            fetchCargoTarball = prev.rustPlatform.fetchCargoTarball.override {
              cacert = prev.cacert.override {
                extraCertificateFiles = [./JHUAPL-MS-Root-CA-05-21-2038-B64-text.crt];
              };
            };
          } (args // {});
      };
  };
}
