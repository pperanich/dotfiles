{ inputs, ... }:
{
  imports = [
    # Provides flake.modules.<class>.<name> — the export surface every module
    # in this repo writes into.
    inputs.flake-parts.flakeModules.modules
    inputs.home-manager.flakeModules.home-manager
  ];
}
