{ inputs }:
{
  emacs-overlay = inputs.emacs-overlay.overlays.default;
  neovim-overlay = inputs.neovim-nightly-overlay.overlays.default;
  sops-nix = inputs.sops-nix.overlays.default;
  nix-apple-fonts = inputs.nix-apple-fonts.overlays.default;
  # Use the flake's own package output (built with personal-site's locked
  # nixpkgs) rather than its overlay — the Astro/sharp build breaks under
  # 26.05's bun. Revert to overlays.default once fixed upstream.
  personal-site = final: _prev: {
    personal-site = inputs.personal-site.packages.${final.stdenv.hostPlatform.system}.personal-site;
  };

  nixgl = inputs.nixgl.overlay;
  rust-overlay = inputs.rust-overlay.overlays.default;
  jetpack-nixos = inputs.jetpack-nixos.overlays.default;
  bun2nix = inputs.bun2nix.overlays.default;

  # This one brings my packages from the 'pkgs' directory
  additions =
    final: _prev:
    import ../pkgs {
      pkgs = final;
    };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
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
    glibtool = final.libtool.overrideAttrs (oldAttrs: {
      configureFlags = (oldAttrs.configureFlags or [ ]) ++ [ "--program-prefix=g" ];
    });
    # Enable GSSAPI support on macOS to suppress "Unsupported option gssapiauthentication"
    # warnings from colima's auto-generated ssh_config
    openssh = prev.openssh.override (
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        withKerberos = true;
      }
    );
  };
}
