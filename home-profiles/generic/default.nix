# Generic home configuration for additional users
{
  outputs,
  ...
}:
{
  imports = with outputs.homeModules; [
    # Core
    base

    # Shell
    zsh

    # Editors
    nvim

    # General cli tools
    tools

    # Desktop
    fonts

    # Work profile
    aplnis
  ];

  # State version set by mkHomeConfigurations
  home.stateVersion = "25.11";
}
