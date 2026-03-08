{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
  zeromq,
  openblas,
  apple-sdk_15,
  darwinMinVersionHook,
  gtk3,
  libglvnd,
  libxkbcommon,
  vulkan-loader,
  wayland,
  libX11,
  libXcursor,
  libXi,
  libXrandr,
  libxcb,
}:
rustPlatform.buildRustPackage rec {
  pname = "runmat";
  version = "0.2.8";

  src = fetchFromGitHub {
    owner = "runmat-org";
    repo = "runmat";
    rev = "v${version}";
    hash = "sha256-Q+0tPTvPNvFJJ5cGm8ejj1vFo9QPzqGUNa8lI7uFQe0=";
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";

    # The workspace lock includes optional git dependencies (via tools/runmatfunc).
    # `buildRustPackage` requires explicit hashes for these.
    outputHashes = {
      "codex-apply-patch-0.0.0" = "sha256-8L2WFm8d+YU8grC3b/+fRXetn57e6VfKRCci+DaD+4E=";
      "codex-core-0.0.0" = "sha256-8L2WFm8d+YU8grC3b/+fRXetn57e6VfKRCci+DaD+4E=";
      "codex-file-search-0.0.0" = "sha256-8L2WFm8d+YU8grC3b/+fRXetn57e6VfKRCci+DaD+4E=";
      "codex-mcp-client-0.0.0" = "sha256-8L2WFm8d+YU8grC3b/+fRXetn57e6VfKRCci+DaD+4E=";
      "codex-protocol-0.0.0" = "sha256-8L2WFm8d+YU8grC3b/+fRXetn57e6VfKRCci+DaD+4E=";
      "core_test_support-0.0.0" = "sha256-8L2WFm8d+YU8grC3b/+fRXetn57e6VfKRCci+DaD+4E=";
      "mcp-types-0.0.0" = "sha256-8L2WFm8d+YU8grC3b/+fRXetn57e6VfKRCci+DaD+4E=";
    };
  };

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
    libX11
    libXcursor
    libXi
    libXrandr
    libxcb
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    apple-sdk_15
    (darwinMinVersionHook "10.15")
  ];

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
