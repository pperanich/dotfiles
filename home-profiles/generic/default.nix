# Generic home configuration for additional users
{
  outputs,
  pkgs,
  ...
}: {
  imports = with outputs.homeManagerModules; [
    # Core
    base

    # Shell
    zsh

    # Editors
    nvim
    vscode

    # Utilities
    fonts
  ];

  # State version set by mkHomeConfigurations
  home.stateVersion = "25.05";
}
