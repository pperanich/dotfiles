{ inputs, ... }:
{
  # This one brings our custom packages from the 'pkgs' directory
  emacs-overlay = inputs.emacs-overlay.overlays.default;
  neovim-overlay = inputs.neovim-nightly-overlay.overlay;
  nixgl = inputs.nixgl.overlay;

  additions = final: _prev: import ../pkgs { pkgs = final; };
  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });
    # micromamba = prev.micromamba.overrideAttrs(oldAttrs: rec {
    #   postInstall = ''
    #     export HOME=$out
    #     mkdir -p $out/.conda/
    #     touch $out/.conda/environments.txt
    #     mkdir -p $out/opt/
    #     $out/bin/micromamba env create -n conda conda -c conda-forge --root-prefix $out/opt --ssl-verify false -y
    #     rm -rf $out/.conda/
    #     '';
    # });
  };
}
