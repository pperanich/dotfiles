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
  # Modules the private repo exports, merged with the ones defined locally:
  #   outputs = _: { modules.nixos.vpnSecrets = ./modules/vpn-secrets.nix; };
  flake.modules = private.modules or { };
}
