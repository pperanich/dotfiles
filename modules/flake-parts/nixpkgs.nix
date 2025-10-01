{
  inputs,
  withSystem,
  ...
}: let
  overlays = import ../../overlays {inherit inputs;};

  # Extend nixpkgs lib with custom functions
  extendedLib = inputs.nixpkgs.lib.extend (self: super: {
    my = import ../../lib {lib = inputs.nixpkgs.lib;};
  });
in {
  systems = import inputs.systems;

  # Make extended lib available to all flake-parts modules
  _module.args.lib = extendedLib;

  perSystem = {system, ...}: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        allowBroken = true;
        permittedInsecurePackages = [
          "openssl-1.1.1w"
        ];
        overlays = builtins.attrValues overlays;
      };
    };
  };

  flake = {
    lib = extendedLib;
    overlays.default = _final: prev:
      withSystem prev.stdenv.hostPlatform.system (
        {config, ...}: {
          local = config.packages;
        }
      );
  };
}
