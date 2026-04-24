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
  # Export homeModules from flake.modules.homeManager (schema-compliant name)
  flake.homeModules = config.flake.modules.homeManager or { };

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
        "prest"
      ];
    }
  );
}
