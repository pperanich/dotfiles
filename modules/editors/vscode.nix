# Visual Studio Code editor configuration
{...}: {
  flake.modules.homeManager.vscode = {pkgs, ...}: {
    home.packages = with pkgs; [
      # Common dependencies for modern text editing
      ripgrep # Required for modern text search
      fd # Required for file finding
      fzf # Fuzzy finder
    ];

    programs.vscode = {
      enable = true;
    };
  };
}
