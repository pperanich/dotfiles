# Home configuration for pperanich
{
  homeManager,
  config,
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

      # Services
      opencode
    ]
    ++ (
      if desktop then
        [
          # Desktop
          fonts
          applications
        ]
      else
        [ ]
    );

  # User identity
  home.username = "pperanich";
  home.sessionVariables.OPENCODE_CONFIG_DIR = "${config.home.homeDirectory}/.config/opencode/profiles/default/";
}
