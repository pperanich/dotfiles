{ config, pkgs, lib, inputs, ... }:
let
  toolchain = pkgs.rust-bin.beta.latest.default.override {
    extensions = [ "rust-src" "rustfmt" "llvm-tools-preview" "cargo" ];
    targets = [ "thumbv7em-none-eabi" "thumbv7em-none-eabihf" "wasm32-unknown-unknown" ];
  };
in
{
  home.packages = with pkgs; [
    toolchain

    openssl
    pkg-config
    # Extra cargo dependencies
    cargo-bloat
    # For LSP
    # We want the unwrapped version, "rust-analyzer" (wrapped) comes with nixpkgs' toolchain
    rust-analyzer-unwrapped
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    darwin.libiconv
    darwin.apple_sdk.frameworks.AppKit
    darwin.apple_sdk.frameworks.SystemConfiguration
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ systemd ];

  home.sessionPath = [ "\${CARGO_HOME:-~/.cargo}/bin" ];
}

