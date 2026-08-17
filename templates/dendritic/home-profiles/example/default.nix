# A home profile is a composition of homeManager modules and nothing else.
# Used two ways, unchanged:
#   - homeConfigurations.example (standalone, see modules/flake-parts/home.nix)
#   - home-manager.users.example on a NixOS/Darwin host (see modules/users/example.nix)
{ homeManager, ... }:
{
  imports = with homeManager; [
    base
    sops
  ];

  home.username = "example";
}
