# Rust development environment
_: {
  flake.modules.homeManager.rust =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (config.home) homeDirectory;
      toolchain = pkgs.rust-bin.nightly.latest.default.override {
        extensions = [
          "rust-src"
          "rustfmt"
          "llvm-tools"
          "cargo"
          "rust-analyzer"
        ];
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

          # Web targets
          "wasm32-unknown-unknown"
          "wasm32-wasip1"

          # Mobile targets
          "aarch64-apple-ios-sim"
          "aarch64-linux-android"
        ];
      };
    in
    {
      home.packages =
        with pkgs;
        [
          # Rust toolchain
          toolchain

          # Cargo tools
          cargo-edit
          cargo-watch
          cargo-audit
          cargo-outdated
          cargo-release
          cargo-bloat

          # Build dependencies
          pkg-config

          # Debug tools
          lldb
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
          # macOS-specific packages
          darwin.libiconv
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          # Linux-specific packages
          systemd
        ];

      # Environment setup
      home = {
        sessionVariables = {
          RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
        };
        sessionPath = [ "\${CARGO_HOME:-${homeDirectory}/.cargo}/bin" ];
      };
    };

  # System-level packages for cross-compilation and debugging
  flake.modules.nixos.rust =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        lldb
        gdb
      ];

      # Enable cross-compilation for embedded development
      boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
    };

  # macOS-specific system configuration
  flake.modules.darwin.rust =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        libiconv
      ];

      # Environment variables for linking
      environment.variables = {
        PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
        LIBRARY_PATH = "${pkgs.libiconv}/lib";
      };
    };
}
