{ inputs }:
{
  sops-nix = inputs.sops-nix.overlays.default;

  # Everything in /pkgs becomes a normal pkgs.<name>
  additions =
    final: _prev:
    import ../pkgs {
      pkgs = final;
    };

  # Version pins, patches, build-flag changes
  modifications = _final: _prev: {
    # example = prev.example.overrideAttrs (old: { ... });
  };
}
