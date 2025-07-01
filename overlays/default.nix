{inputs, ...}: {
  # This one brings our my packages from the 'pkgs' directory
  emacs-overlay = inputs.emacs-overlay.overlays.default;
  neovim-overlay = inputs.neovim-nightly-overlay.overlays.default;
  sops-nix = inputs.sops-nix.overlays.default;

  nixgl = inputs.nixgl.overlay;
  rust-overlay = inputs.rust-overlay.overlays.default;
  jetpack-nixos = inputs.jetpack-nixos.overlays.jetpack6;

  additions = final: _prev: import ../pkgs {pkgs = final;};
  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
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

    sops-install-secrets = prev.sops-install-secrets.overrideAttrs( old: { env.GODEBUG = "x509negativeserial=1";});
    # sops-install-secrets = inputs.sops-nix.packages.sops-install-secrets.overrideAttrs( old: {
    #   GODEBUG = "x509negativeserial=1";
    #   env = {
    #     GODEBUG = "x509negativeserial=1";
    #   };
    # });
    # buildGoModule = (prev.buildGoModule // {
    #   env = {
    #     NIX_SSL_CERT_FILE = final.aplCertificate;
    #     SSL_CERT_FILE = final.aplCertificate;
    #     GIT_SSL_CAINFO= final.aplCertificate;
    #     GODEBUG = "x509negativeserial=1";
    #   };
    # }).override {
    #   cacert = prev.cacert.override {
    #     extraCertificateFiles = [./JHUAPL-MS-Root-CA-05-21-2038-B64-text.crt];
    #   };
    # };
  # rustPlatform =
  #   prev.rustPlatform
  #   // {
  #     fetchCargoVendor = prev.rustPlatform.fetchCargoVendor.override {
  #       cacert = prev.cacert.override {
  #         extraCertificateFiles = [./JHUAPL-MS-Root-CA-05-21-2038-B64-text.crt];
  #       };
  #     };
  #     buildRustPackage = 
  #       prev.rustPlatform.buildRustPackage.override {
  #         fetchCargoVendor = prev.rustPlatform.fetchCargoVendor.override {
  #           cacert = prev.cacert.override {
  #             extraCertificateFiles = [./JHUAPL-MS-Root-CA-05-21-2038-B64-text.crt];
  #           };
  #         };
  #       };
  #   };

  };
}
