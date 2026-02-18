{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
  zeromq,
  openblas,
  darwin,
  gtk3,
  libglvnd,
  libxkbcommon,
  vulkan-loader,
  wayland,
  xorg,
}:
rustPlatform.buildRustPackage rec {
  pname = "runmat";
  version = "0.2.8";

  src = fetchFromGitHub {
    owner = "runmat-org";
    repo = "runmat";
    rev = "v${version}";
    hash = lib.fakeHash;
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";

    # The workspace lock includes optional git dependencies (via tools/runmatfunc).
    # `buildRustPackage` requires explicit hashes for these.
    outputHashes = {
      "codex-apply-patch-0.0.0" = lib.fakeHash;
      "codex-core-0.0.0" = lib.fakeHash;
      "codex-file-search-0.0.0" = lib.fakeHash;
      "codex-mcp-client-0.0.0" = lib.fakeHash;
      "codex-protocol-0.0.0" = lib.fakeHash;
      "core_test_support-0.0.0" = lib.fakeHash;
      "mcp-types-0.0.0" = lib.fakeHash;
    };
  };

  cargoHash = lib.fakeHash;

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    zeromq
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    openssl
    openblas

    # GUI / windowing (winit/eframe), and WGPU (Vulkan/OpenGL).
    gtk3
    libglvnd
    libxkbcommon
    vulkan-loader
    wayland
    xorg.libX11
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr
    xorg.libxcb
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin (
    with darwin.apple_sdk.frameworks;
    [
      Accelerate
      AppKit
      Cocoa
      CoreFoundation
      CoreGraphics
      CoreVideo
      IOKit
      Metal
      QuartzCore
      Security
      SystemConfiguration
    ]
  );

  # Only build the CLI crate (named `runmat`) from the workspace.
  cargoBuildFlags = [
    "-p"
    "runmat"
  ];

  # Upstream has extensive GPU/plot/runtime integration tests; keep builds fast and reliable.
  doCheck = false;

  meta = with lib; {
    description = "High-performance MATLAB/Octave runtime with Jupyter kernel support";
    homepage = "https://runmat.com";
    license = licenses.unfreeRedistributable;
    mainProgram = "runmat";
    platforms = platforms.darwin ++ platforms.linux;
  };
}
