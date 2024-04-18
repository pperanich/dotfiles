{ config, pkgs, lib, inputs, ... }:
let
  inherit (config.lib.meta) mkMutableSymlink;
in
{
  home.packages = with pkgs; [
    comma  # Install and run programs by sticking a , before them

    act  # Run github workflows locally
    gh  # Github CLI
    gitui  # Blazing fast terminal-ui for Git written in Rust
    git-filter-repo  # Quickly rewrite git repository history

    bat  # Better cat
    eva  # A calculator REPL, similar to bc
    bottom  # System viewer
    bandwhich  # A CLI utility for displaying current network utilization

    ripgrep  # Better grep
    fd  # Better find
    # ncdu  # TUI disk usage
    xplr  # A hackable, minimal, fast TUI file explorer

    httpie  # Better curl
    wget  # Tool for retrieving files using HTTP, HTTPS, and FTP

    jq  # JSON pretty printer and manipulator

    tmux  # Terminal multiplexer
    tmux-sessionizer  # The fastest way to manage projects as tmux sessions
    zellij  # A terminal workspace with batteries included

    nh  # NH reimplements some basic nix commands.
    nix-output-monitor  # Processes output of Nix commands to show helpful and pretty information
    nvd  # Nix/NixOS package version diff tool
    statix  # Lints and suggestions for the nix programming language

    micromamba  # Reimplementation of the conda package manager
    pixi  # Package management made easy
    rye  # A tool to easily manage python dependencies and environments

    heygpt  # A simple command-line interface for ChatGPT API
    shell_gpt  # Access ChatGPT from your terminal

    gnused  # sed (stream editor) is a non-interactive command-line text editor.
    gnutls  # The GNU Transport Layer Security Library
    sshfs  # FUSE-based filesystem that allows remote filesystems to be mounted over SSH
    cups  # A standards-based printing system for UNIX
    libtool  # GNU Libtool, a generic library support script

    xsel  # Command-line program for getting and setting the contents of the X selection
    xclip  # Tool to access the X clipboard from a console application

    plantuml  # Draw UML diagrams using a simple and human readable text description
    graphviz  # Graph visualization tools

    nodejs  # Event-driven I/O framework for the V8 JavaScript engine

    qpdf  # A C++ library and set of programs that inspect and manipulate the structure of PDF files
    cmake  # Cross-platform, open-source build system generator
    rbw  # Unofficial Bitwarden CLI
    pinentry-curses  # GnuPG’s interface to passphrase input
    ffmpeg  # A complete, cross-platform solution to record, convert and stream audio and video
    tealdeer  # A very fast implementation of tldr in Rust
    kubectl  # Kubernetes CLI
    update-display  # Re-export DISPLAY in tmux shells.
    # ai-buddy  # AI assistant for projects
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    reattach-to-user-namespace  # A wrapper that provides access to the Mac OS X pasteboard service
    pam-reattach  # Reattach to the user's GUI session on macOS during authentication (for Touch ID support in tmux)
    xquartz  # Version of the X.Org X Window System that runs on macOS
    # glibtool  # GNU Libtool, a generic library support script
  ];

  xdg = {
    configFile = {
      "tmux".source = mkMutableSymlink "tmux";
      "tms".source = mkMutableSymlink "tms";
      "direnv".source = mkMutableSymlink "direnv";
      "shell_gpt".source = mkMutableSymlink "shell_gpt";
    };
  };
  home = {
    file = {
      ".npmrc".source = mkMutableSymlink "npmrc";
      ".heygpt.toml".text = ''
        model = "gpt-4-0125-preview"
        api_base_url = "https://api.openai.com/v1"
        stream = true
        '';
    };
    sessionPath = [
      "${config.home.homeDirectory}/.npm-global/bin"
        "${config.home.homeDirectory}/dotfiles/bin"
        "${config.home.homeDirectory}/.pixi/bin"
        "${config.home.homeDirectory}/.rye/shims"
    ];
  };

}
