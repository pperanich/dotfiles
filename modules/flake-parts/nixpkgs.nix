{
  inputs,
  withSystem,
  ...
}: let
  overlays = import ../../overlays {inherit inputs;};
in {
  systems = import inputs.systems;

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
    overlays.default = _final: prev:
      withSystem prev.stdenv.hostPlatform.system (
        {config, ...}: {
          local = config.packages;
        }
      );
  };
}
