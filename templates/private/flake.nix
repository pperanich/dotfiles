{
  description = "Private machines, built from a public config";

  # The only input. Everything else (nixpkgs, clan-core, sops-nix, home-manager,
  # nix-darwin) is reached through it, so there is one version to bump and no
  # way for this repo's nixpkgs to drift from the modules it imports.
  #
  # Step 1: point this at your own public config.
  inputs = {
    upstream.url = "github:you/your-config";

    # Not a second version of anything: `follows` resolves this to the exact
    # clan-core the upstream already locked. It has to be a *declared* input
    # because clan resolves `module.input = "clan-core"` in the inventory
    # against the lock file, not against the attrset handed to mkFlake, and
    # without it every service instance fails with
    #   error: Flake doesn't provide input with name 'clan-core'
    clan-core.follows = "upstream/clan-core";
  };

  outputs =
    { self, upstream, ... }:
    upstream.inputs.flake-parts.lib.mkFlake {
      # Upstream's inputs under their bare names, so modules copied from the
      # dendritic template keep working, plus `self` and `upstream`.
      #
      # `self` must be OURS. Writing `self = upstream` makes clan derive its
      # machine directory from the upstream checkout, and nixosConfigurations
      # quietly comes back holding that repo's machines instead of these.
      inputs = upstream.inputs // {
        inherit self upstream;
      };
    } (upstream.inputs.import-tree ./modules);
}
