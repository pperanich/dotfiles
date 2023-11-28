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
    heygpt = prev.heygpt.overrideAttrs (oldAttrs: rec {
      buildInputs = oldAttrs.buildInputs ++ final.lib.optionals final.stdenv.hostPlatform.isDarwin [ final.darwin.apple_sdk.frameworks.SystemConfiguration ];
    });
    glibtool = final.libtool.overrideAttrs (oldAttrs: {
      configureFlags = (oldAttrs.configureFlags or [ ]) ++ [ "--program-prefix=g" ];
    });
  };
}
