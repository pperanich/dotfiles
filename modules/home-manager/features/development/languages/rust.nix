# Rust development environment
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.home.features.development.languages;
  inherit (config.home) homeDirectory;
  toolchain = pkgs.rust-bin.nightly.latest.default.override {
    extensions = ["rust-src" "rustfmt" "llvm-tools" "cargo"];
    targets = [
      "thumbv6m-none-eabi"
      "thumbv7m-none-eabi"
      "thumbv7em-none-eabi"
      "thumbv7em-none-eabihf"
      "thumbv8m.main-none-eabihf"
      "riscv32imac-unknown-none-elf"
      "aarch64-apple-darwin"
      "aarch64-unknown-linux-gnu"
      "x86_64-apple-darwin"
      "x86_64-unknown-linux-gnu"
      "wasm32-unknown-unknown"
      "wasm32-wasip1"
    ];
  };
in {
  config = lib.mkIf (cfg.enable && cfg.rust.enable) {
    home.packages = with pkgs;
      [
        # Rust toolchain
        toolchain
        rust-analyzer-unwrapped
        cargo-edit
        cargo-watch
        cargo-audit
        cargo-outdated
        cargo-release
        cargo-bloat

        # Build dependencies
        pkg-config
        openssl

        # Debug tools
        lldb
      ]
      ++ lib.optionals stdenv.hostPlatform.isDarwin [
        darwin.libiconv
      ]
      ++ lib.optionals stdenv.hostPlatform.isLinux [
        systemd
      ];

    # Environment setup
    home = {
      sessionVariables = {
        RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
      };
      sessionPath = ["\${CARGO_HOME:-${homeDirectory}/.cargo}/bin"];
    };
  };
}
