{ config, pkgs, lib, inputs, ... }:
let
  inherit (config.home) homeDirectory;
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  home.packages = with pkgs; [
    comma # Install and run programs by sticking a , before them

    bc # Calculator
    bottom # System viewer
    ncdu # TUI disk usage
    exa # Better ls
    ripgrep # Better grep
    fd # Better find
    httpie # Better curl
    jq # JSON pretty printer and manipulator
    azure-cli
    gnutls
    graphviz
    # nodejs
    qpdf
    wget
    cmake
    ffmpeg
    cups
    tmux
    libcxx
    clang
    sshfs
  ];

  xdg.configFile."tmux".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/tmux";
}
