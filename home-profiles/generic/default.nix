# Generic home configuration for additional users
{
  outputs,
  ...
}:
{
  imports = with outputs.homeModules; [
    # Core
    base

    # Editors
    nvim

    # General cli tools
    tools

    # Desktop
    fonts

    # Work profile
    work

    rust
  ];

  # State version set by mkHomeConfigurations
  home.stateVersion = "25.11";
}
