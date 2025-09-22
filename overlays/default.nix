{inputs}: {
  emacs-overlay = inputs.emacs-overlay.overlays.default;
  neovim-overlay = inputs.neovim-nightly-overlay.overlays.default;
  sops-nix = inputs.sops-nix.overlays.default;
  ghostty = inputs.ghostty.overlays.default;

  nixgl = inputs.nixgl.overlay;
  rust-overlay = inputs.rust-overlay.overlays.default;
  jetpack-nixos = inputs.jetpack-nixos.overlays.default;

  # This one brings my packages from the 'pkgs' directory
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
  };
}
