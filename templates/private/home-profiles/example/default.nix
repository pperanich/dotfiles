# A home profile is a composition of upstream homeManager modules and nothing
# else. Keep this list matching the profile you use publicly and a private
# machine feels identical to log into.
#
# Every module here brings its own required sops keys with it, and a key it
# names but sops/secrets.yaml lacks is a build failure. The upstream's
# `apiKeys` module is the usual example: leave it out and this repo owes no
# provider tokens. See docs/upstream-contract.md.
#
# No conditionals in this list: an option read here would be read from
# `config`, and reading config inside `imports` is an infinite recursion. Add
# and remove lines instead.
{ homeManager, ... }:
{
  imports = with homeManager; [
    # Core
    base
    sops

    # Editors
    nvim

    tools

    # Services
    opencode

    # Provider API keys, if you want them here too. Costs six api_keys/*
    # entries in sops/secrets.yaml.
    # apiKeys

    # Desktop — uncomment on a machine with a screen
    # fonts
    # applications
  ];

  home.username = "example";

  # The upstream's home sops module defaults this at its own secrets.yaml, a
  # store path this machine's key is not a recipient of.
  sops.defaultSopsFile = ../../sops/secrets.yaml;
}
