_: {
  # NixOS system-level Rust development support
  flake.modules.nixos.rust = {pkgs, ...}: {
    # System debugging tools for Rust development
    environment.systemPackages = with pkgs; [
      lldb
      gdb
      valgrind
      rr # Time-travel debugging
      strace
    ];

    # Enable cross-compilation support
    boot.binfmt.emulatedSystems = [
      "aarch64-linux"
      "armv6l-linux"
      "armv7l-linux"
    ];

    # System-wide environment variables for debugging
    environment.variables = {
      RUST_BACKTRACE = "1";
    };
  };

  # Home Manager user-level Rust development environment
  flake.modules.homeModules.rust = {
    config,
    pkgs,
    ...
  }: let
    inherit (config.home) homeDirectory;
    toolchain = pkgs.rust-bin.nightly.latest.default.override {
      extensions = ["rust-src" "rustfmt" "llvm-tools" "cargo" "rust-analyzer"];
      targets = [
        # Embedded targets
        "thumbv6m-none-eabi"
        "thumbv7m-none-eabi"
        "thumbv7em-none-eabi"
        "thumbv7em-none-eabihf"
        "thumbv8m.main-none-eabihf"
        "riscv32imac-unknown-none-elf"

        # Desktop targets
        "aarch64-apple-darwin"
        "aarch64-unknown-linux-gnu"
        "x86_64-apple-darwin"
        "x86_64-unknown-linux-gnu"

        # WebAssembly targets
        "wasm32-unknown-unknown"
        "wasm32-wasip1"

        # Mobile targets
        "aarch64-apple-ios-sim"
        "aarch64-linux-android"
      ];
    };
  in {
    home.packages = with pkgs;
      [
        # Rust toolchain
        toolchain

        # Cargo extensions and tools
        cargo-edit
        cargo-watch
        cargo-audit
        cargo-outdated
        cargo-release
        cargo-bloat
        cargo-expand
        cargo-flamegraph
        cargo-nextest
        cargo-deny

        # Build dependencies
        pkg-config

        # Debug tools (user-space)
        lldb
      ]
      ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        # macOS-specific packages
        darwin.libiconv
      ]
      ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        # Linux-specific packages
        systemd
      ];

    # Environment setup
    home = {
      sessionVariables = {
        RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
        RUST_BACKTRACE = "1";
      };
      sessionPath = ["\${CARGO_HOME:-${homeDirectory}/.cargo}/bin"];
    };

    # Rust development shell configurations
    programs.zsh.shellAliases = {
      "cargo-outdated" = "cargo outdated --root-deps-only";
      "cargo-tree-dups" = "cargo tree --duplicates";
      "rust-analyzer-restart" = "pkill -f rust-analyzer";
    };
  };

  # Darwin system-level Rust development support
  flake.modules.darwin.rust = {pkgs, ...}: {
    # macOS system packages for Rust development
    environment.systemPackages = with pkgs; [
      lldb
      darwin.libiconv
    ];

    # macOS-specific environment variables for linking
    environment.variables = {
      PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.libiconv}/lib/pkgconfig";
      LIBRARY_PATH = "${pkgs.libiconv}/lib";
      # Fix for OpenSSL linking issues on macOS
      OPENSSL_DIR = "${pkgs.openssl.dev}";
      OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
      OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
    };

    # Homebrew fallbacks for system integration
    homebrew.brews = [
      # Sometimes needed for certain crates that expect system OpenSSL
      "openssl@3"
    ];
  };
}
