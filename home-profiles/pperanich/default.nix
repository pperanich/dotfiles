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

      # Editors
      nvim

      # Languages
      # rust

      tools

      # Rex CLI on every host, so remote panes can use it; no server is started
      rex
    ]
    ++ lib.optionals desktop [
      # AI CLI agents & provider tokens (workstations only, never servers)
      apiKeys
      aiTools

      # Desktop
      fonts
      applications
    ];

  # User identity
  home.username = "pperanich";
  home.sessionVariables = lib.mkIf desktop {
    OPENCODE_CONFIG_DIR = "${config.home.homeDirectory}/.config/opencode/profiles/default/";
  };
}
