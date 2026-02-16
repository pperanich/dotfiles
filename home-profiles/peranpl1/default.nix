# Home configuration for peranpl1
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

    # Desktop
    fonts
    applications

    # Editors
    nvim

    # Languages
    rust

    # General cli tools
    tools

    # Work
    aplnis
  ];

  # User identity
  home.username = "peranpl1";
  home.sessionVariables.OPENCODE_CONFIG_DIR = "${config.home.homeDirectory}/.config/opencode/profiles/work/";
}
