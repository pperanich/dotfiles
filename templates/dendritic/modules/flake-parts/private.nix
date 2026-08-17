# Optional private repo for machines and modules you don't want public.
# Inert until you declare the input in flake.nix:
#
#   private.url = "git+ssh://git@github.com/you/nix-private";
#
# Nothing here fetches anything while the input is absent, so `nix flake init`
# and `nix flake check` still work for someone without access to your repo.
# See docs/private-repo.md.
{ inputs, ... }:
let
  private = inputs.private or { };
in
{
  # A flake-parts module from the private repo — perSystem packages, overlays,
  # anything this flake's own modules/flake-parts/ files can do:
  #   outputs = _: { flakeModules.default = ./flake-modules/private.nix; };
  #
  # `inputs`, not the `lib` module arg: `lib` comes from _module.args, and an
  # `imports` that depends on it recurses.
  imports = inputs.nixpkgs.lib.optional (private ? flakeModules) private.flakeModules.default;

  # NixOS/Darwin/home-manager modules, merged with the ones defined locally:
  #   outputs = _: { modules.nixos.vpnTopology = ./modules/vpn-topology.nix; };
  flake.modules = private.modules or { };
}
