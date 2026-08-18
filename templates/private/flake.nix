{
  description = "Private machines, built from a public config";

  # The only input. nixpkgs, home-manager, nix-darwin and sops-nix are all
  # reached through it, so there is one version to bump and no way for this
  # repo's nixpkgs to drift from the modules it imports.
  #
  # Step 1: point this at your own public config.
  inputs.upstream.url = "github:you/your-config";

  outputs =
    inputs@{ upstream, ... }:
    upstream.inputs.flake-parts.lib.mkFlake {
      # Upstream's inputs under their bare names, so a module copied from the
      # dendritic template keeps working, with this repo's own `self` on top.
      inputs = upstream.inputs // inputs;
    } (upstream.inputs.import-tree ./modules);
}
