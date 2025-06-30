# Shell tools configuration
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.home.features.shell;
in {
  config = lib.mkIf cfg.tools.enable {
    home.packages = with pkgs;
      [
        direnv  # Shell extension that manages your environment
        uutils-coreutils-noprefix  # Cross-platform Rust rewrite of the GNU coreutils
        uutils-findutils  # Rust implementation of findutils
        # starship  # Minimal, blazing fast, and extremely customizable prompt for any shell
        oh-my-posh  # Prompt theme engine for any shell
        sheldon  # Fast and configurable shell plugin manager
        act # Run github workflows locally
        gh # Github CLI
        glab # Gitlab CLI
        # git
        git-lfs
        gitui # Blazing fast terminal-ui for Git written in Rust
        git-filter-repo # Quickly rewrite git repository history
        lazygit # A simple terminal UI for git commands
        stow # Symlink farm manager
        rclone # Command line program to sync files and directories to and from major cloud storage

        atool # Easier packing and unpacking of archives
        bat # Better cat
        eva # A calculator REPL, similar to bc
        bottom # System viewer
        bandwhich # A CLI utility for displaying current network utilization
        # yazi-unwrapped  # Blazing fast terminal file manager written in Rust, based on async I/O

        picocom  # Minimal dumb-terminal emulation program
        curlie # Frontend to curl that adds the ease of use of httpie, without compromising on features and performance
        xh # Friendly and fast tool for sending HTTP requests
        choose # Human-friendly and fast alternative to cut and (sometimes) awk
        httpie # Command line HTTP client whose goal is to make CLI human-friendly
        dust # du + rust = dust. Like du but more intuitive
        duf # Disk Usage/Free Utility
        delta # Syntax-highlighting pager for git
        # eza # Modern, maintained replacement for ls

        ripgrep # Better grep
        fd # Better find
        fzf # Command-line fuzzy finder written in Go
        # ncdu  # TUI disk usage
        xplr # A hackable, minimal, fast TUI file explorer

        httpie # Better curl
        wget # Tool for retrieving files using HTTP, HTTPS, and FTP

        jq # JSON pretty printer and manipulator

        tmux # Terminal multiplexer
        tmux-sessionizer # The fastest way to manage projects as tmux sessions
        zellij # A terminal workspace with batteries included

        nh # NH reimplements some basic nix commands.
        nix-output-monitor # Processes output of Nix commands to show helpful and pretty information
        nvd # Nix/NixOS package version diff tool
        statix # Lints and suggestions for the nix programming language

        micromamba # Reimplementation of the conda package manager
        pixi # Package management made easy
        # rye  # A tool to easily manage python dependencies and environments
        python-launcher # An implementation of the `py` command for Unix-based platforms

        heygpt # A simple command-line interface for ChatGPT API
        shell-gpt # Access ChatGPT from your terminal

        hdf5
        gnused # sed (stream editor) is a non-interactive command-line text editor.
        gnutls # The GNU Transport Layer Security Library
        sshfs # FUSE-based filesystem that allows remote filesystems to be mounted over SSH
        cups # A standards-based printing system for UNIX
        libtool # GNU Libtool, a generic library support script

        xsel # Command-line program for getting and setting the contents of the X selection
        xclip # Tool to access the X clipboard from a console application

        plantuml # Draw UML diagrams using a simple and human readable text description
        graphviz # Graph visualization tools

        nodejs # Event-driven I/O framework for the V8 JavaScript engine
        bun # Incredibly fast JavaScript runtime, bundler, test runner, and package manager
        # deno # A modern runtime for JavaScript and TypeScript.
        tailwindcss # Rapidly build modern websites without ever leaving your HTML.

        qpdf # A C++ library and set of programs that inspect and manipulate the structure of PDF files
        cmake # Cross-platform, open-source build system generator
        gnumake # Tool to control the generation of non-source files from sources
        # clang_multi # C language family frontend for LLVM (wrapper script)
        devenv #
        rbw # Unofficial Bitwarden CLI
        pinentry-curses # GnuPG's interface to passphrase input
        ffmpeg # A complete, cross-platform solution to record, convert and stream audio and video
        tealdeer # A very fast implementation of tldr in Rust
        kubectl # Kubernetes CLI
        update-display # Re-export DISPLAY in tmux shells.
        # ai-buddy  # AI assistant for projects
        # devai  # Command Agent runner to accelerate production coding.
        ghostty # Fast, native, feature-rich terminal emulator pushing modern features
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        lazydocker # A simple terminal UI for both docker and docker-compose
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        reattach-to-user-namespace # A wrapper that provides access to the Mac OS X pasteboard service
        pam-reattach # Reattach to the user's GUI session on macOS during authentication (for Touch ID support in tmux)
        # xquartz  # Version of the X.Org X Window System that runs on macOS
        glibtool # GNU Libtool, a generic library support script. Needed to compile libvterm on Mac
      ];

    home = {
      sessionPath = [
        "${config.home.homeDirectory}/.npm-global/bin"
        "${config.home.homeDirectory}/dotfiles/bin"
        "${config.home.homeDirectory}/.pixi/bin"
        "${config.home.homeDirectory}/.rye/shims"
        "${config.home.homeDirectory}/.cargo/bin"
      ];
    };
  };
}
