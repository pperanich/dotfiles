# Home configuration for pperanich
{
  homeManager,
  config,
  ...
}:
{
  imports = with homeManager; [
    # Core
    base
    sops

    # Editors
    nvim

    # Languages
    rust

    tools

    # Services
    opencode

    # Desktop
    fonts
    applications
  ];

  # User identity
  home.username = "pperanich";
  home.sessionVariables.OPENCODE_CONFIG_DIR = "${config.home.homeDirectory}/.config/opencode/profiles/default/";
}
