# Flake module to register the openclaw clan service
_:
let
  module = ./default.nix;
in
{
  # Register the module with clan
  clan.modules.openclaw = module;
}
