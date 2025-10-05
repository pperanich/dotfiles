# Home configuration for pperanich
{
  homeManager,
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

    # Utilities
    networkUtilities
    fileExploration
  ];

  # User identity
  home.username = "pperanich";
}
