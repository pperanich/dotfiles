# Host configuration for peranpl1-ml1 (macOS laptop)
{inputs, ...}: {
  imports = [
    # Core system configuration
    inputs.self.modules.darwin.base
    inputs.self.modules.homeManager.base

    # User setup
    inputs.self.modules.darwin.peranpl1
    inputs.self.modules.homeManager.peranpl1

    # Desktop environment
    inputs.self.modules.homeManager.fonts
    inputs.self.modules.homeManager.desktopApplications
    inputs.self.modules.homeManager.zsh

    # Development environment
    inputs.self.modules.homeManager.nvim
    inputs.self.modules.homeManager.emacs
    inputs.self.modules.homeManager.vscode
    inputs.self.modules.darwin.rust
    inputs.self.modules.homeManager.rust
    inputs.self.modules.homeManager.tex

    # Network and file utilities
    inputs.self.modules.homeManager.networkUtilities
    inputs.self.modules.homeManager.fileExploration

    # Work environment
    inputs.self.modules.darwin.aplnis
    inputs.self.modules.homeManager.aplnis
  ];

  # Host-specific configuration
  networking.hostName = "peranpl1-ml1";
  nixpkgs.hostPlatform = "x86_64-darwin";
}
