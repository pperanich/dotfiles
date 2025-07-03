{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  darwin,
}:
rustPlatform.buildRustPackage
rec {
  pname = "devai";
  version = "main";

  src = fetchFromGitHub {
    owner = "jeremychone";
    repo = "rust-devai";
    rev = version;
    sha256 = "sha256-lX2FPfV3/G6mVBj7iusXbdE65AkNPboPBhRLnVHJbRY=";
  };
  cargoLock = {
    lockFile = ./Cargo.lock;
  };
  postPatch = ''
    ln -s ${./Cargo.lock} Cargo.lock
  '';
  cargoHash = "sha256-jtBw4ahSl88L0iuCXxQgZVm1EcboWRJMNtjxLVTtzts=";

  meta = with lib; {
    description = "Command Agent runner to accelerate production coding.";
    homepage = "https://github.com/jeremychone/rust-devai";
    license = with licenses; [mit];
    mainProgram = "devai";
  };
}
