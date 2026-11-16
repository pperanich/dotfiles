{ inputs }:
{
  sops-nix = inputs.sops-nix.overlays.default;
  # The flake's own packages, built on its pinned nixpkgs: the overlay rebuilt every font
  # (download and Nerd patching) on each nixpkgs bump. Update this input only for new fonts.
  nix-apple-fonts = final: _prev: {
    apple-fonts = inputs.nix-apple-fonts.packages.${final.stdenv.hostPlatform.system};
  };
  # The site's own package output, built on our nixpkgs (flake.nix makes it follow).
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
    # 3.x logs the device-tags 404 once at debug instead of ERROR per poll.
    # Not backported to 26.05 (major bump) — revisit on next release bump
    # (likely 26.11): drop once `nixpkgs#unpoller.version` >= 3.3.1.
    unpoller = prev.unpoller.overrideAttrs (
      finalAttrs: _old: {
        version = "3.3.1";
        src = prev.fetchFromGitHub {
          owner = "unpoller";
          repo = "unpoller";
          rev = "v${finalAttrs.version}";
          hash = "sha256-MivEuI/XjRDlX+VjSAMLjRl0WlRVnhP18qVujbvwjeQ=";
        };
        vendorHash = "sha256-3DBUrKTvwRqaNuYtBlP5DlF1SNmU+ZNeH7ATVQjgLsA=";
      }
    );

    my-curl = prev.my-curl or prev.curl;
    my-git = prev.my-git or prev.git;
  };
}
