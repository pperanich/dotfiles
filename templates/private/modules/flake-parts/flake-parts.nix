{ inputs, ... }:
{
  imports = [
    # Gives this flake its own flake.modules.{nixos,darwin,homeManager} tree,
    # merged over the upstream's in hosts.nix.
    inputs.flake-parts.flakeModules.modules
  ];
}
