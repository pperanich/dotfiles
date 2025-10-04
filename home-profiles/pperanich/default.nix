# Home configuration for pperanich
{
  homeManager,
  ...
}:
{
  imports = with homeManager; [
    # Core
    base

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
    tex

    # Utilities
    networkUtilities
    fileExploration
  ];

  # User identity
  home = {
    username = "pperanich";
    homeDirectory = "/home/pperanich";
    stateVersion = "25.05";
  };
}
