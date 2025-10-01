# Host configuration for peranpl1-ml1 (macOS laptop)
{
  modules,
  ...
}:
{
  imports = with modules.darwin; [
    # Core system configuration
    base

    # User setup
    peranpl1

    # Development environment
    rust

    # Work environment
    aplnis
  ];

  home-manager.users.peranpl1 = {
    imports = with modules.homeManager; [
      # Core system configuration
      base

      # Desktop environment
      fonts
      desktopApplications
      zsh

      # Development environment
      nvim
      emacs
      vscode
      rust
      tex

      # Network and file utilities
      networkUtilities
      fileExploration
    ];
  };

  # Host-specific configuration
  networking.hostName = "peranpl1-ml1";
  nixpkgs.hostPlatform = "x86_64-darwin";
}
