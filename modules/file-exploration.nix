_: {
  flake.modules.nixos.fileExploration = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      bat # A cat clone with wings (syntax highlighting and Git integration)
      fd # A simple, fast and user-friendly alternative to find
      ripgrep # A line-oriented search tool that recursively searches the current directory for a regex pattern
      fzf # A command-line fuzzy finder
    ];
  };

  flake.modules.homeModules.fileExploration = {
    pkgs,
    lib,
    ...
  }: {
    home.packages = with pkgs; [
      bat # A cat clone with wings (syntax highlighting and Git integration)
      fd # A simple, fast and user-friendly alternative to find
      ripgrep # A line-oriented search tool that recursively searches the current directory for a regex pattern
      fzf # A command-line fuzzy finder
      choose # A human-friendly and fast alternative to cut and (sometimes) awk
      dust # du + rust = dust. Like du but more intuitive
      duf # Disk Usage/Free Utility - a better 'df' alternative
      xplr # A hackable, minimal, fast TUI file explorer
    ];
  };
}
