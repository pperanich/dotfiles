{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
  emacs-overlay = inputs.emacs-overlay.overlays.default;
  neovim-overlay = inputs.neovim-nightly-overlay.overlays.default;

  nixgl = inputs.nixgl.overlay;
  rust-overlay = inputs.rust-overlay.overlays.default;

  additions = final: _prev: import ../pkgs {pkgs = final;};
  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    atuin = prev.atuin.overrideAttrs (old: {
      # as cursed as doing mitigations=off in the kernel command line
      patches = [./patches/0001-make-atuin-on-zfs-fast-again.patch];
    });
    heygpt = prev.heygpt.overrideAttrs (oldAttrs: {
      buildInputs = oldAttrs.buildInputs ++ final.lib.optionals final.stdenv.hostPlatform.isDarwin [final.darwin.apple_sdk.frameworks.SystemConfiguration];
    });
    glibtool = final.libtool.overrideAttrs (oldAttrs: {
      configureFlags = (oldAttrs.configureFlags or []) ++ ["--program-prefix=g"];
    });
    logseq =
      if final.stdenv.hostPlatform.isDarwin
      then prev.nixcasks.logseq
      else prev.logseq;
    brave =
      if final.stdenv.hostPlatform.isDarwin
      then prev.nixcasks.brave-browser
      else prev.brave;
    zotero =
      if final.stdenv.hostPlatform.isDarwin
      then prev.nixcasks.zotero
      else prev.zotero;
    etcher =
      if final.stdenv.hostPlatform.isDarwin
      then prev.nixcasks.etcher
      else prev.etcher;
    tailscale =
      if final.stdenv.hostPlatform.isDarwin
      then prev.nixcasks.tailscale
      else prev.tailscale;
    vlc =
      if final.stdenv.hostPlatform.isDarwin
      then prev.nixcasks.vlc
      else prev.vlc;
    protonvpn-gui =
      if final.stdenv.hostPlatform.isDarwin
      then prev.nixcasks.protonvpn
      else prev.protonvpn-gui;
  };
}
