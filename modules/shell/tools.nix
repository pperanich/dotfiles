_: {
  flake.modules.homeManager.tools =
    { pkgs, config, ... }:
    {
      home.packages =
        with pkgs;
        [
          # Shell Environment
          direnv # Shell extension that manages your environment
          oh-my-posh # Prompt theme engine for any shell
          sheldon # Fast and configurable shell plugin manager

          # Modern CLI Replacements
          uutils-coreutils-noprefix # Cross-platform Rust rewrite of the GNU coreutils
          uutils-findutils # Rust implementation of findutils
          bat # Better cat
          ripgrep # Better grep
          fd # Better find
          dust # du + rust = dust. Like du but more intuitive
          duf # Disk Usage/Free Utility
          # eza # Modern, maintained replacement for ls

          # Search & Navigation
          fzf # Command-line fuzzy finder written in Go
          xplr # A hackable, minimal, fast TUI file explorer
          choose # Human-friendly and fast alternative to cut and (sometimes) awk
          # yazi-unwrapped  # Blazing fast terminal file manager written in Rust, based on async I/O
          # ncdu  # TUI disk usage

          # Terminal Multiplexers
          tmux # Terminal multiplexer
          tmux-sessionizer # The fastest way to manage projects as tmux sessions
          zellij # A terminal workspace with batteries included

          # Version Control
          my-git # Use "custom" git so we can override with openssl1 if needed.
          git-lfs
          # gitui # Blazing fast terminal-ui for Git written in Rust
          git-filter-repo # Quickly rewrite git repository history
          lazygit # A simple terminal UI for git commands
          delta # Syntax-highlighting pager for git
          gh # Github CLI
          glab # Gitlab CLI
          act # Run github workflows locally

          # Network & HTTP Tools
          curlie # Frontend to curl that adds the ease of use of httpie, without compromising on features and performance
          xh # Friendly and fast tool for sending HTTP requests
          httpie # Better curl
          wget # Tool for retrieving files using HTTP, HTTPS, and FTP
          bandwhich # A CLI utility for displaying current network utilization

          # System Monitoring
          bottom # System viewer
          btop # Monitor of resources

          # File Management & Sync
          atool # Easier packing and unpacking of archives
          stow # Symlink farm manager
          rclone # Command line program to sync files and directories to and from major cloud storage
          sshfs # FUSE-based filesystem that allows remote filesystems to be mounted over SSH

          # Data Processing
          jq # JSON pretty printer and manipulator
          qpdf # A C++ library and set of programs that inspect and manipulate the structure of PDF files
          hdf5 # Data model, library, and file format for storing and managing data

          # Development - Languages & Runtimes
          go # Go Programming language
          nodejs # Event-driven I/O framework for the V8 JavaScript engine
          bun # Incredibly fast JavaScript runtime, bundler, test runner, and package manager
          # deno # A modern runtime for JavaScript and TypeScript.

          # Development - Python/Package Managers
          # micromamba # Reimplementation of the conda package manager
          pixi # Package management made easy
          python-launcher # An implementation of the `py` command for Unix-based platforms

          # julia-bin # High-level performance-oriented dynamical language for technical computing

          # Development - Build Tools & Frameworks
          cmake # Cross-platform, open-source build system generator
          gnumake # Tool to control the generation of non-source files from sources
          tailwindcss # Rapidly build modern websites without ever leaving your HTML.

          # Development - Nix Tools
          nh # NH reimplements some basic nix commands.
          nix-output-monitor # Processes output of Nix commands to show helpful and pretty information
          nvd # Nix/NixOS package version diff tool
          statix # Lints and suggestions for the nix programming language
          devenv

          # DevOps & Infrastructure
          kubectl # Kubernetes CLI

          # AI Assistants
          heygpt # A simple command-line interface for ChatGPT API
          shell-gpt # Access ChatGPT from your terminal

          # Security & Credentials
          rbw # Unofficial Bitwarden CLI
          pinentry-curses # GnuPG's interface to passphrase input

          # Media
          ffmpeg # A complete, cross-platform solution to record, convert and stream audio and video
          spotify-player # Terminal spotify player that has feature parity with the official client

          # Diagrams & Visualization
          plantuml # Draw UML diagrams using a simple and human readable text description
          graphviz # Graph visualization tools

          # Clipboard
          xsel # Command-line program for getting and setting the contents of the X selection
          xclip # Tool to access the X clipboard from a console application

          # Serial & Communication
          picocom # Minimal dumb-terminal emulation program

          # System Utilities
          gnused # sed (stream editor) is a non-interactive command-line text editor.
          gnutls # The GNU Transport Layer Security Library
          cups # A standards-based printing system for UNIX
          eva # A calculator REPL, similar to bc
          libtool # GNU Libtool, a generic library support script
          tealdeer # A very fast implementation of tldr in Rust
          update-display # Re-export DISPLAY in tmux shells.
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
          reattach-to-user-namespace # A wrapper that provides access to the Mac OS X pasteboard service
          pam-reattach # Reattach to the user's GUI session on macOS during authentication (for Touch ID support in tmux)
          # xquartz  # Version of the X.Org X Window System that runs on macOS
          glibtool # GNU Libtool, a generic library support script. Needed to compile libvterm on Mac
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          # ghostty # Fast, native, feature-rich terminal emulator pushing modern features
          lazydocker # A simple terminal UI for both docker and docker-compose
          isd # TUI to interactively work with systemd units
        ];
      home = {
        sessionPath = [
          "${config.home.homeDirectory}/.local/bin"
          "${config.home.homeDirectory}/.npm-global/bin"
          "${config.home.homeDirectory}/dotfiles/bin"
          "${config.home.homeDirectory}/.pixi/bin"
          "${config.home.homeDirectory}/.rye/shims"
          "${config.home.homeDirectory}/.cargo/bin"
          "${config.home.homeDirectory}/.opencode/bin"
          "${config.home.homeDirectory}/go/bin"
        ];
      };
    };
}
