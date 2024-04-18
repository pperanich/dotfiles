{ config, pkgs, lib, inputs, ... }:
let
  inherit (config.home) homeDirectory;
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  home.packages = with pkgs; [
    comma # Install and run programs by sticking a , before them

    act # Run github workflows locally
    gh # Github CLI
    gnused
    # ai-buddy
    bat # Better cat
    bc # Calculator
    bottom # System viewer
    bandwhich
    # ncdu # TUI disk usage
    ripgrep # Better grep
    fd # Better find
    httpie # Better curl
    jq # JSON pretty printer and manipulator
    # azure-cli
    statix
    gitui
    git-filter-repo
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
    tmux-sessionizer
    zellij
    sshfs
    tealdeer
    xsel
    xclip
    update-display
    nodePackages.npm
    kubectl
    pixi
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    libtool
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    reattach-to-user-namespace
    pam-reattach
    glibtool
    xquartz
  ];

  xdg = {
    configFile = {
      "tmux".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/tmux";
      "tms".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/tms";
      "direnv".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/direnv";
      "shell_gpt".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/shell_gpt";
    };
  };
  home = {
    file = {
      ".npmrc".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/npmrc";
      ".heygpt.toml".text = ''
        model = "gpt-4-0125-preview"
        api_base_url = "https://api.openai.com/v1"
        stream = true
        '';
    };
    sessionPath = [
      "${homeDirectory}/.npm-global/bin"
        "${homeDirectory}/dotfiles/bin"
        "${homeDirectory}/.pixi/bin"
        "${homeDirectory}/.rye/shims"
    ];
  };

}
