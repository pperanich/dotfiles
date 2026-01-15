# Import essential flake-parts modules
# Enables the modules system and home-manager integration
{ inputs, ... }:
{
  imports = [
    # Enable the flake-parts modules system
    # This allows modules to export via flake.modules.<platform>.<name>
    inputs.flake-parts.flakeModules.modules

    # Enable home-manager flake module
    # Provides home-manager integration at the flake level
    inputs.home-manager.flakeModules.home-manager
  ];
}
