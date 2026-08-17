# Standalone home-manager configs (for machines you don't manage with NixOS or
# nix-darwin): home-profiles/<user>/ -> homeConfigurations.<user>
#
#   home-manager switch --flake .#example
#
# homeConfigurations aren't per-system, so the platform is pinned here. Change
# it to "aarch64-darwin" for a Mac, or key the attribute names by system if you
# need both.
{
  inputs,
  config,
  withSystem,
  ...
}:
{
  # Schema-compliant alias so `outputs.homeModules.<name>` works in profiles
  flake.homeModules = config.flake.modules.homeManager or { };

  flake.homeConfigurations = withSystem "x86_64-linux" (
    { pkgs, ... }:
    config.flake.lib.my.mkHomeConfigurations {
      homePath = ../../home-profiles;
      outputs = config.flake;
      inherit inputs pkgs;
      inherit (inputs) home-manager;
    }
  );
}
