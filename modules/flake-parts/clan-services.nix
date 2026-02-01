# Register local clan services
#
# This module registers clan services from the clanServices directory
# with the clan inventory system.
_: {
  # Register clan modules directly
  # These can be referenced with module.input = "self" in inventory
  flake.clan.modules = {
    "@pperanich/openclaw" = ../../clanServices/openclaw;
  };
}
