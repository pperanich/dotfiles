{ inputs, ... }:
{
  # This one brings our custom packages from the 'pkgs' directory
  emacs-overlay = inputs.emacs-overlay.overlays.default;
  # neovim-overlay = inputs.neovim-nightly-overlay.overlay;
  nixgl = inputs.nixgl.overlay;

  additions = final: _prev: import ../pkgs { pkgs = final; };
  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    liblpeg = final.stdenv.mkDerivation {
      pname = "liblpeg";
      inherit (final.luajitPackages.lpeg) version meta src;

      buildInputs = [ final.luajit ];

      buildPhase = ''
        sed -i makefile -e "s/CC = gcc/CC = clang/"
        sed -i makefile -e "s/-bundle/-dynamiclib/"

        make macosx
        '';

      installPhase = ''
        mkdir -p $out/lib
        mv lpeg.so $out/lib/lpeg.dylib
        '';

      nativeBuildInputs = [ final.fixDarwinDylibNames ];
    };
    neovim-nightly = inputs.neovim-nightly-overlay.packages.${final.system}.neovim.overrideAttrs (oa: rec {
          nativeBuildInputs = oa.nativeBuildInputs ++ final.lib.optionals final.stdenv.hostPlatform.isDarwin [ final.liblpeg ];
          });
  };

}
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
#   };
# }
