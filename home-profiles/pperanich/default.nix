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

    # Shell
    zsh

    # Desktop
    fonts
    desktopApplications

    # Editors
    nvim
    vscode

    # Languages
    rust

    tools

    # Services
    opencode
  ];

  # User identity
  home.username = "pperanich";
  home.sessionVariables.OPENCODE_CONFIG_DIR = "${config.home.homeDirectory}/.config/opencode/profiles/default/";
}
