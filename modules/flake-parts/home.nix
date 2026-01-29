{
  inputs,
  config,
  withSystem,
  ...
}:
let
  inherit (config.flake) lib;
  outputs = config.flake;
in
{
  # Export homeManagerModules from flake.modules.homeManager
  flake.homeManagerModules = config.flake.modules.homeManager or { };

  # Auto-generate homeConfigurations from home-profiles/
  # Uses pkgs from perSystem (defined in nixpkgs.nix) to avoid duplication
  flake.homeConfigurations = withSystem "x86_64-linux" (
    { pkgs, ... }:
    lib.my.mkHomeConfigurations {
      homePath = ../../home-profiles;
      inherit
        inputs
        pkgs
        outputs
        lib
        ;
      inherit (inputs) home-manager;
      extraSpecialArgs = { };
      additionalUsers = [
        "hst"
        "holo"
        "magic"
        "mxwbio"
        "prest"
      ];
    }
  );
}
