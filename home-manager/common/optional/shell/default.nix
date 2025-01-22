{ config, lib, pkgs, ... }:

{
  imports = [
    ./cli.nix
    ./zsh.nix
    ./nushell.nix
  ];

  # Common shell configuration
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    LESS = "-R";
  };

  # Common packages for all shells
  home.packages = with pkgs; [
    ripgrep
    fd
    fzf
    jq
    tree
  ];
} 