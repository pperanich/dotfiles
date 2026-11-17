{ inputs }:
{
  sops-nix = inputs.sops-nix.overlays.default;
  # The flake's own packages, built on its pinned nixpkgs: the overlay rebuilt every font
  # (download and Nerd patching) on each nixpkgs bump. Update this input only for new fonts.
  nix-apple-fonts = final: _prev: {
    apple-fonts = inputs.nix-apple-fonts.packages.${final.stdenv.hostPlatform.system};
  };
  # The site's own package output, built on the nixpkgs in the site's flake.lock.
  personal-site = final: _prev: {
    personal-site = inputs.personal-site.packages.${final.stdenv.hostPlatform.system}.personal-site;
  };

  # comma bakes nixpkgs' upstream nix into its binary at build time; that nix
  # warns on Determinate-only settings in /etc/nix/nix.conf (lazy-trees,
  # eval-cores, the provenance feature). Build it against Determinate's nix.
  comma = final: prev: {
    comma = prev.comma.override {
      nix = inputs.determinate.inputs.nix.packages.${final.stdenv.hostPlatform.system}.nix;
    };
  };

  rust-overlay = inputs.rust-overlay.overlays.default;

  # This one brings my packages from the 'pkgs' directory
  additions =
    final: _prev:
    import ../pkgs {
      pkgs = final;
    };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = _final: prev: {
    my-curl = prev.my-curl or prev.curl;
    my-git = prev.my-git or prev.git;
  };
}
