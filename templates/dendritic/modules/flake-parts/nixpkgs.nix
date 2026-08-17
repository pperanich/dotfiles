{
  inputs,
  withSystem,
  ...
}:
let
  overlays = import ../../overlays { inherit inputs; };

  # nixpkgs lib + this repo's helpers under lib.my.*
  extendedLib = import ../../lib/extended.nix { inherit (inputs) nixpkgs; };
in
{
  systems = import inputs.systems;

  # Every flake-parts module in this repo sees the extended lib
  _module.args.lib = extendedLib;

  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = builtins.attrValues overlays;
        config = {
          allowUnfree = true;
          allowBroken = true;
        };
      };
    };

  flake = {
    # flake.lib is owned by lib.nix

    # Consumers get this repo's packages under pkgs.local.*
    overlays.default =
      _final: prev:
      withSystem prev.stdenv.hostPlatform.system (
        { config, ... }:
        {
          local = config.packages;
        }
      );
  };
}
