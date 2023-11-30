{ config, pkgs, lib, inputs, ... }:
let
  inherit (config.home) homeDirectory;
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  home.packages = with pkgs; [
    comma # Install and run programs by sticking a , before them

    gnused
    bat # Better cat
    bc # Calculator
    bottom # System viewer
    # ncdu # TUI disk usage
    ripgrep # Better grep
    fd # Better find
    httpie # Better curl
    jq # JSON pretty printer and manipulator
    # azure-cli
    heygpt
    shell_gpt
    xplr
    plantuml
    micromamba
    gnutls
    graphviz
    nodejs
    qpdf
    wget
    cmake
    ffmpeg
    cups
    tmux
    zellij
    sshfs
    xsel
    xclip
    nodePackages.npm
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    libtool
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    reattach-to-user-namespace
    pam-reattach
    glibtool
    # xquartz
  ];

  xdg.configFile."tmux".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/tmux";
  home.file.".npmrc".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/npmrc";
  xdg.configFile."shell_gpt".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/shell_gpt";
  home.file.".heygpt.toml".text = ''
    model = "gpt-4-1106-preview"
    api_base_url = "https://api.openai.com/v1"
    stream = true
  '';

  home.sessionPath = [ "${homeDirectory}/.npm-global/bin" ];
}
