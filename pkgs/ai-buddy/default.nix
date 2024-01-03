{ lib
, stdenv
, fetchFromGitHub
, rustPlatform
, darwin
}:

rustPlatform.buildRustPackage
rec {
  pname = "ai-buddy";
  version = "E01";

  src = fetchFromGitHub {
    owner = "rust10x";
    repo = "rust-ai-buddy";
    rev = version;
    sha256 = "sha256-Agd3rUCMsHkBh9/v63nDOS9YVgj/dVRiykTsctjojmE=";
  };
  cargoLock = {
    lockFile = ./Cargo.lock;
    # lockFileContents = builtins.readFile ./Cargo.lock;
  };
  postPatch = ''
    ln -s ${./Cargo.lock} Cargo.lock
  '';

  cargoSha256 = "sha256-xyn926h4sO8DbVQ7dw2fbpJEYYOEnS4p/hpAZBkMbx4=";

  buildInputs = lib.optional stdenv.isDarwin [
    darwin.apple_sdk.frameworks.Security
    darwin.apple_sdk.frameworks.SystemConfiguration
  ];

  meta = with lib; {
    description = "Simple on-device AI assistant that leverages AI assistant services";
    homepage = "https://github.com/rust10x/rust-ai-buddy";
    license = with licenses; [ mit ];
    maintainers = with maintainers; [ ];
    mainProgram = "ai-buddy";
  };
}
