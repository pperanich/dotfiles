{
  config,
  pkgs,
  lib,
  ...
}: let
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
  home.packages = with pkgs;
    [
      # rustup
      toolchain

      pkg-config
      # Extra cargo dependencies
      cargo-bloat
      # For LSP
      # We want the unwrapped version, "rust-analyzer" (wrapped) comes with nixpkgs' toolchain
      rust-analyzer-unwrapped
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      darwin.libiconv
      # darwin.CF
      # darwin.SystemConfiguration
      # darwin.Security
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [systemd];

  home.sessionPath = ["\${CARGO_HOME:-${homeDirectory}/.cargo}/bin"];

  # cwi = pkgs.writeShellScriptBin "cwi" ''
  #   cargo watch -x "install --path ."
  # '';
  # cwe = pkgs.writeShellScriptBin "cwi" ''
  #   cargo watch -q -c -x "run -q --example '$1'"
  # '';
  # cwt = pkgs.writeShellScriptBin "cwi" ''
  #   cargo watch -q -c -x "test -- --nocapture"
  # '';
}
