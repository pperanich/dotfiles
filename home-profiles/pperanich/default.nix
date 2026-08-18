# Home configuration for pperanich
{
  homeManager,
  config,
  lib,
  desktop ? true,
  ...
}:
{
  imports =
    with homeManager;
    [
      # Core
      base
      sops
      apiKeys

      # Editors
      nvim

      # Languages
      # rust

      tools

      # Services
      opencode
    ]
    ++ lib.optionals desktop [
      # Desktop
      fonts
      applications
    ];

  # User identity
  home.username = "pperanich";
  home.sessionVariables.OPENCODE_CONFIG_DIR = "${config.home.homeDirectory}/.config/opencode/profiles/default/";
}
