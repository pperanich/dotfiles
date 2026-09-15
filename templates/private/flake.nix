{
  description = "Private machines, built from a public config";

  inputs = {
    # Step 1: point this at your public config. Its inputs supply the package
    # set and modules together, so their versions move with upstream.
    upstream.url = "github:you/your-config";

    # Optional remote deployment: follow optional/deploy-rs/README.md.
    # deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs =
    inputs@{ upstream, ... }:
    upstream.inputs.flake-parts.lib.mkFlake {
      # Upstream's inputs under their bare names, so a module copied from the
      # dendritic template keeps working, with this repo's own `self` on top.
      inputs = upstream.inputs // inputs;
    } (upstream.inputs.import-tree ./modules);
}
