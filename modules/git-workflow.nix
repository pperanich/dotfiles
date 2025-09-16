_: {
  flake.modules.nixos.gitWorkflow = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      git # Version control system
      git-lfs # Git extension for versioning large files
    ];
  };

  flake.modules.homeModules.gitWorkflow = {pkgs, ...}: {
    home.packages = with pkgs; [
      gh # GitHub CLI
      glab # GitLab CLI
      gitui # Blazing fast terminal-ui for Git written in Rust
      lazygit # A simple terminal UI for git commands
      git-filter-repo # Quickly rewrite git repository history
    ];
  };
}
