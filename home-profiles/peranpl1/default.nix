# Home configuration for peranpl1
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

    # General cli tools
    tools

    # Work
    aplnis
  ];

  # User identity
  home.username = "peranpl1";
}
