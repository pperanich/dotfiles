{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    git
    git-lfs
    lazygit # A simple terminal UI for git commands
    stow # Symlink farm manager
    rclone # Command line program to sync files and directories to and from major cloud storage
    atool # Easier packing and unpacking of archives
    bat # Better cat
    bottom # System viewer
    bandwhich # A CLI utility for displaying current network utilization
    curlie # Frontend to curl that adds the ease of use of httpie, without compromising on features and performance
    xh # Friendly and fast tool for sending HTTP requests
    choose # Human-friendly and fast alternative to cut and (sometimes) awk
    httpie # Command line HTTP client whose goal is to make CLI human-friendly
    dust # du + rust = dust. Like du but more intuitive
    duf # Disk Usage/Free Utility
    ripgrep # Better grep
    fd # Better find
    fzf # Command-line fuzzy finder written in Go
    httpie # Better curl
    wget # Tool for retrieving files using HTTP, HTTPS, and FTP
    jq # JSON pretty printer and manipulator
    tmux # Terminal multiplexer
    tmux-sessionizer # The fastest way to manage projects as tmux sessions
    nh # NH reimplements some basic nix commands.
    nix-output-monitor # Processes output of Nix commands to show helpful and pretty information
    python-launcher # An implementation of the `py` command for Unix-based platforms
    gnused # sed (stream editor) is a non-interactive command-line text editor.
    gnutls # The GNU Transport Layer Security Library
    sshfs # FUSE-based filesystem that allows remote filesystems to be mounted over SSH
    cups # A standards-based printing system for UNIX
    libtool # GNU Libtool, a generic library support script
    xsel # Command-line program for getting and setting the contents of the X selection
    xclip # Tool to access the X clipboard from a console application
    cmake # Cross-platform, open-source build system generator
    gnumake # Tool to control the generation of non-source files from sources
    gcc # GNU Compiler Collection, version 14.2.1
    pinentry-curses # GnuPG's interface to passphrase input
    ffmpeg # A complete, cross-platform solution to record, convert and stream audio and video
    tealdeer # A very fast implementation of tldr in Rust
    kubectl # Kubernetes CLI
    lazydocker # A simple terminal UI for both docker and docker-compose
  ];
}
