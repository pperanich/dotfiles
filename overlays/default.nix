{ inputs, ... }:
{
  # This one brings our custom packages from the 'pkgs' directory
  emacs-overlay = inputs.emacs-overlay.overlays.default;
  neovim-overlay = inputs.neovim-nightly-overlay.overlay;
  nixgl = inputs.nixgl.overlay;
  rust-overlay = inputs.rust-overlay.overlays.default;

  additions = final: _prev: import ../pkgs { pkgs = final; };
  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    tmux-sessionizer = prev.tmux-sessionizer.overrideAttrs (old: {
      patches =
        (old.patches or [ ])
        ++ [
          ../home-manager/features/patches/0001-Expand-env-vars-and-tilde-for-search_dirs.patch
        ];
    });
    heygpt = prev.heygpt.overrideAttrs (oldAttrs: rec {
      buildInputs = oldAttrs.buildInputs ++ final.lib.optionals final.stdenv.hostPlatform.isDarwin [ final.darwin.apple_sdk.frameworks.SystemConfiguration ];
    });
    glibtool = final.libtool.overrideAttrs (oldAttrs: {
      configureFlags = (oldAttrs.configureFlags or [ ]) ++ [ "--program-prefix=g" ];
    });
    logseq = if final.stdenv.hostPlatform.isDarwin then prev.logseq-darwin else prev.logseq;
    brave = if final.stdenv.hostPlatform.isDarwin then prev.brave-darwin else prev.brave;
    zotero = if final.stdenv.hostPlatform.isDarwin then prev.zotero-darwin else prev.zotero;
    etcher = if final.stdenv.hostPlatform.isDarwin then prev.etcher-darwin else prev.etcher;
    spotify = if final.stdenv.hostPlatform.isDarwin then prev.spotify-darwin else prev.spotify;
    tailscale = if final.stdenv.hostPlatform.isDarwin then prev.tailscale-darwin else prev.tailscale;
    vlc = if final.stdenv.hostPlatform.isDarwin then prev.vlc-darwin else prev.vlc;
    protonvpn-gui = if final.stdenv.hostPlatform.isDarwin then prev.protonvpn-gui-darwin else prev.protonvpn-gui;
  };
}
