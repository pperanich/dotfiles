# Compose upstream and private home modules in one profile.
# desktop must be supplied explicitly through extraSpecialArgs by each caller:
# reading Home Manager's config or _module.args inside imports would recurse.
{
  homeManager,
  lib,
  desktop,
  ...
}:
{
  imports =
    with homeManager;
    [
      base
      sops
      stowPrivate
      nvim
      tools
      opencode

      # Optional: the local apiKeys module discovers this repo's api_keys/*
      # entries, replacing the upstream's fixed provider list.
      # apiKeys
    ]
    ++ lib.optionals desktop [
      fonts
      applications
    ];

  home.username = "example";
  sops.defaultSopsFile = ../../sops/secrets.yaml;
}
