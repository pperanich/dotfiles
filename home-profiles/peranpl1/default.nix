# Home configuration for peranpl1
{
  outputs,
  ...
}:
{
  imports = with outputs.homeManagerModules; [
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

    # General cli tools
    tools

    # Work
    aplnis
  ];

  # User identity
  home = {
    username = "peranpl1";
    homeDirectory = "/home/peranpl1";
    stateVersion = "25.05";
  };
}
