{
  inputs,
  lib,
  config,
  ...
}: let
  # Import custom library functions
  myLib = import ../../lib {inherit lib;};

  # Extend lib with custom functions
  extendedLib = lib.extend (_: _: {my = myLib;});

  # Create package sets for all systems
  pkgsFor = extendedLib.my.mkPkgsFor {nixpkgs = inputs.nixpkgs;};
in {
  # Export homeManagerModules from flake.modules.homeManager
  flake.homeManagerModules = config.flake.modules.homeManager or {};

  # Auto-generate homeConfigurations from home-profiles/
  flake.homeConfigurations = extendedLib.my.mkHomeConfigurations {
    homePath = ../../home-profiles;
    inherit inputs;
    outputs = config.flake;
    lib = extendedLib;
    home-manager = inputs.home-manager;
    inherit pkgsFor;
    extraSpecialArgs = {};
    additionalUsers = ["hst" "holo" "mxwbio"];
  };
}
