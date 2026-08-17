# pkgs for this repo's own perSystem outputs (the dev shell, treefmt). Machines
# get their pkgs from clan, configured by the upstream modules they import.
{ inputs, ... }:
{
  systems = import inputs.systems;

  perSystem =
    { system, pkgs, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        # The upstream's overlays, so a package resolves here the same way it
        # does there. Drop this if you only want plain nixpkgs.
        overlays = builtins.attrValues (import "${inputs.upstream}/overlays" { inherit inputs; }) ++ [
          # clan-cli is not in nixpkgs, so pkgs.clan-cli exists only if the
          # upstream overlays it in. Defer to that when it does (it may wrap a
          # different nix), otherwise take the package from clan-core.
          (final: prev: {
            clan-cli = prev.clan-cli or inputs.clan-core.packages.${final.stdenv.hostPlatform.system}.clan-cli;
          })
        ];
        config = {
          allowUnfree = true;
          allowBroken = true;
        };
      };

      clan.pkgs = pkgs;
    };
}
