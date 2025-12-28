# Generic home configuration for additional users
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

    # Editors
    nvim
    vscode

    # General cli tools
    tools

    # Utilities
    networkUtilities
    fileExploration

    # Utilities
    fonts

    # Work profile
    aplnis

    shellEnvironment
  ];

  # State version set by mkHomeConfigurations
  home.stateVersion = "25.11";
}
