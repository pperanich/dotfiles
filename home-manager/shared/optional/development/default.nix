{pkgs, ...}: {
  imports = [
    ./editors
    # ./containers
    ./rust.nix
    ./tex.nix
    # ./git.nix
  ];

  # Common development tools
  home.packages = with pkgs; [
    gnumake
    gcc
    git-crypt
    gh # GitHub CLI
  ];

  # Git configuration
  programs.git = {
    enable = true;
    delta.enable = true;
    lfs.enable = true;
  };
}
